#if IOS_PHONE_PUBLISHING
import AVFoundation
import CoreMedia
import Foundation
import HaishinKit
import RTMPHaishinKit
import UIKit
import VideoToolbox

struct PublisherEvent: Sendable {
  let name: String
  let generation: Int
  var value: Double? = nil
  var audioOnly: Bool? = nil
}

// Observe actual outgoing bytes. RTMPStream.info is receive-side, not upload bitrate.
private struct PublisherNetworkObserver: StreamBitRateStrategy {
  let mamimumVideoBitRate: Int // HaishinKit 2.2.5 protocol spelling.
  let mamimumAudioBitRate = 128_000
  let epoch: Int
  let pipeline: PublisherPipeline
  func adjustBitrate(_ event: NetworkMonitorEvent, stream: some StreamConvertible) async {
    switch event {
    case .status(let report), .publishInsufficientBWOccured(let report):
      await pipeline.networkBytes(report.currentBytesOutPerSecond, epoch: epoch)
    case .reset: break
    }
  }
}

actor PublisherPipeline: MediaMixerOutput {
  enum Failure: Error { case permission, unavailable, invalidArguments, notPrepared, background }
  let videoTrackId: UInt8? = UInt8.max
  let audioTrackId: UInt8? = UInt8.max
  private let mixer = MediaMixer()
  private let emit: @Sendable (PublisherEvent) async -> Void
  private var connection: RTMPConnection?
  private var stream: RTMPStream?
  private var subscriptions: [Task<Void, Never>] = []
  private var staticTask: Task<Void, Never>?
  private var watchdog: Task<Void, Never>?
  private var frame: CMSampleBuffer?
  private weak var preview: MTHKView?
  private var width = 1280
  private var height = 720
  private var videoBitrate = 2_000_000
  private var prepared = false
  private var capturing = false
  private var audioOnly = false
  private var muted = false
  private var foreground = true
  private var publishing = false
  private var generation = 0
  private var epoch = 0
  private var lastUpload = Date()
  private var lastMeter = Date.distantPast
  private var previousSession: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)?

  init(emit: @escaping @Sendable (PublisherEvent) async -> Void) { self.emit = emit }

  func prepare(width: Int, height: Int, bitrate: Int, audioOnly: Bool, title: String) async throws {
    guard [(640, 360), (1280, 720), (1920, 1080)].contains(where: {
      $0.0 == width && $0.1 == height
    }), (200_000...8_000_000).contains(bitrate) else { throw Failure.invalidArguments }
    let token = epoch + 1
    await stop()
    try check(token)
    prepared = false
    self.width = width; self.height = height; videoBitrate = bitrate
    self.audioOnly = audioOnly
    foreground = await MainActor.run { UIApplication.shared.applicationState != .background }
    guard foreground else { throw Failure.background }
    // Both video and audio-only prepare the IDR before any possible background transition.
    frame = try PublisherStaticFrame.make(width: width, height: height, title: title)
    do {
      try await capture(epoch: token)
      try check(token)
      prepared = true
    } catch {
      if token == epoch { await stop() }
      throw error
    }
  }

  private func check(_ token: Int) throws {
    guard token == epoch, !Task.isCancelled else { throw CancellationError() }
  }

  private func permission(_ type: AVMediaType) async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: type) {
    case .authorized: return true
    case .notDetermined: return await AVCaptureDevice.requestAccess(for: type)
    default: return false
    }
  }

  private func capture(epoch token: Int) async throws {
    guard await permission(.audio) else { throw Failure.permission }
    try check(token)
    if !audioOnly {
      guard foreground, await permission(.video) else { throw Failure.permission }
      try check(token)
    }
    let session = AVAudioSession.sharedInstance()
    if previousSession == nil { previousSession = (session.category, session.mode, session.categoryOptions) }
    try session.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetooth])
    try session.setPreferredSampleRate(44_100)
    try session.setActive(true)
    await mixer.setSessionPreset(width >= 1920 ? .hd1920x1080 : (width >= 1280 ? .hd1280x720 : .vga640x480))
    try check(token)
    try await mixer.setFrameRate(30)
    guard let microphone = AVCaptureDevice.default(for: .audio) else { throw Failure.unavailable }
    try await mixer.attachAudio(microphone)
    try check(token)
    await mixer.setAudioMixerSettings(AudioMixerSettings(sampleRate: 44_100, channels: 2, isMuted: muted))
    if !audioOnly {
      guard foreground else { throw Failure.background }
      guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
        throw Failure.unavailable
      }
      try await mixer.attachVideo(camera)
    }
    try check(token)
    await mixer.addOutput(self)
    try check(token)
    if let preview, foreground, !audioOnly { await mixer.addOutput(preview) }
    try check(token)
    await mixer.startRunning()
    try check(token)
    capturing = true
  }

  func start(url: String, muted: Bool, audioOnly: Bool, generation: Int) async throws {
    guard prepared else { throw Failure.notPrepared }
    guard var endpoint = URLComponents(string: url),
      ["rtmp", "rtmps"].contains(endpoint.scheme?.lowercased() ?? ""),
      endpoint.host != nil, endpoint.user == nil, endpoint.password == nil,
      endpoint.fragment == nil else { throw Failure.invalidArguments }
    let pieces = endpoint.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: true)
    guard pieces.count >= 2, let last = pieces.last else { throw Failure.invalidArguments }
    let name = String(last).removingPercentEncoding ?? String(last)
    endpoint.percentEncodedPath = "/" + pieces.dropLast().joined(separator: "/")
    guard let address = endpoint.string else { throw Failure.invalidArguments }
    let token = epoch + 1
    await closeTransport()
    try check(token)
    self.generation = generation
    self.muted = muted
    try await setAudioOnly(audioOnly || !foreground)
    try check(token)
    if !capturing { try await capture(epoch: token) }
    try check(token)
    await setMuted(muted)
    try check(token)
    let connection = RTMPConnection()
    let stream = RTMPStream(connection: connection)
    self.connection = connection; self.stream = stream
    try await stream.setAudioSettings(AudioCodecSettings(bitRate: 128_000, sampleRate: 44_100))
    try await stream.setVideoSettings(VideoCodecSettings(videoSize: CGSize(width: CGFloat(width), height: CGFloat(height)),
      bitRate: videoBitrate, profileLevel: kVTProfileLevel_H264_Baseline_AutoLevel as String,
      maxKeyFrameIntervalDuration: 2, expectedFrameRate: 30))
    await stream.setBitRateStrategy(PublisherNetworkObserver(mamimumVideoBitRate: videoBitrate,
      epoch: token, pipeline: self))
    try check(token)
    // Install each single-consumer status stream before connect/publish.
    let connectionStatuses = await connection.status
    let streamStatuses = await stream.status
    try check(token)
    subscriptions = [Task { [weak self] in
      for await status in connectionStatuses {
        guard !Task.isCancelled else { return }
        if status.level == "error" || ["NetConnection.Connect.Closed", "NetConnection.Connect.IdleTimeOut",
          "NetConnection.Connect.NetworkChange", "NetConnection.Connect.AppShutdown"].contains(status.code) {
          await self?.dropped(epoch: token)
          return
        }
      }
    }, Task { [weak self] in
      for await status in streamStatuses {
        guard !Task.isCancelled else { return }
        if status.level == "error" || ["NetStream.Unpublish.Success", "NetStream.Play.Stop"].contains(status.code) {
          await self?.dropped(epoch: token)
          return
        }
      }
    }]
    do {
      _ = try await connection.connect(address)
      try check(token)
      _ = try await stream.publish(name)
      try check(token)
      publishing = true
      lastUpload = Date()
      if self.audioOnly != audioOnly {
        await emit(PublisherEvent(name: "audioOnlyChanged", generation: generation, audioOnly: self.audioOnly))
      }
      await emit(PublisherEvent(name: "live", generation: generation))
      try check(token)
      if self.audioOnly { startStaticFrames(epoch: token) }
      watchdog = Task { [weak self] in
        while !Task.isCancelled {
          do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
          await self?.checkUpload(epoch: token)
        }
      }
    } catch {
      if token == epoch { await pauseForRecovery() }
      throw error // The bridge converts this to a fixed message; never log the URL/SDK error.
    }
  }

  func networkBytes(_ bytes: Int, epoch token: Int) async {
    guard token == epoch, publishing else { return }
    if bytes > 0 { lastUpload = Date() }
    await emit(PublisherEvent(name: "bitrate", generation: generation, value: Double(max(0, bytes)) * 8))
  }

  private func checkUpload(epoch token: Int) async {
    guard token == epoch, publishing, Date().timeIntervalSince(lastUpload) >= 8 else { return }
    await dropped(epoch: token)
  }

  private func dropped(epoch token: Int) async {
    guard token == epoch, connection != nil else { return }
    let oldGeneration = generation
    await pauseForRecovery()
    await emit(PublisherEvent(name: "disconnected", generation: oldGeneration))
  }

  private func closeTransport() async {
    epoch += 1
    publishing = false
    staticTask?.cancel(); staticTask = nil
    watchdog?.cancel(); watchdog = nil
    subscriptions.forEach { $0.cancel() }; subscriptions.removeAll()
    let oldStream = stream; let oldConnection = connection
    stream = nil; connection = nil
    try? await oldStream?.close()
    try? await oldConnection?.close()
  }

  // The active microphone keeps a bounded background retry episode eligible to
  // run. Dart's user-stop/revocation/exhaustion paths call the full stop instead.
  func pauseForRecovery() async {
    if capturing { await closeTransport() } else { await stop() }
  }

  func stop() async {
    let token = epoch + 1
    await closeTransport()
    guard token == epoch else { return }
    capturing = false
    await mixer.removeOutput(self)
    guard token == epoch else { return }
    if let preview { await mixer.removeOutput(preview) }
    guard token == epoch else { return }
    await mixer.stopRunning()
    guard token == epoch else { return }
    try? await mixer.attachVideo(nil)
    guard token == epoch else { return }
    try? await mixer.attachAudio(nil)
    guard token == epoch else { return }
    if let previousSession {
      let session = AVAudioSession.sharedInstance()
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      try? session.setCategory(previousSession.0, mode: previousSession.1, options: previousSession.2)
      self.previousSession = nil
    }
  }

  func dispose() async { await stop(); prepared = false; frame = nil; preview = nil }

  func setMuted(_ value: Bool) async {
    muted = value
    await mixer.setAudioMixerSettings(AudioMixerSettings(sampleRate: 44_100, channels: 2, isMuted: value))
  }

  func setAudioOnly(_ value: Bool) async throws {
    guard value || foreground else { throw Failure.background }
    let token = epoch
    if value {
      audioOnly = true // Reject late camera samples before detaching.
      try await mixer.attachVideo(nil)
      if let preview { await mixer.removeOutput(preview) }
      try check(token)
      if publishing { startStaticFrames(epoch: token) }
    } else if audioOnly {
      guard await permission(.video) else { throw Failure.permission }
      try check(token)
      guard foreground, let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
        for: .video, position: .back) else { throw Failure.unavailable }
      try await mixer.attachVideo(camera)
      try check(token)
      staticTask?.cancel(); staticTask = nil
      audioOnly = false
      if let preview { await mixer.addOutput(preview) }
    }
  }

  func background() async {
    foreground = false
    guard capturing else { return }
    let token = epoch
    do {
      try await setAudioOnly(true)
      await emit(PublisherEvent(name: "audioOnlyChanged", generation: generation, audioOnly: true))
    } catch { if token == epoch { await dropped(epoch: token) } }
  }

  func becameActive() { foreground = true } // User explicitly re-enables the camera.
  func interruption() async { await dropped(epoch: epoch) }

  func attachPreview(_ view: MTHKView) async {
    if let preview { await mixer.removeOutput(preview) }
    preview = view
    if capturing, foreground, !audioOnly { await mixer.addOutput(view) }
  }

  func detachPreview(_ view: MTHKView) async {
    await mixer.removeOutput(view)
    if preview === view { preview = nil }
  }

  func orientation(_ degrees: Int) async {
    let orientation: AVCaptureVideoOrientation
    switch degrees {
    case 90: orientation = .landscapeRight
    case 180: orientation = .portraitUpsideDown
    case 270: orientation = .landscapeLeft
    default: orientation = .portrait
    }
    await mixer.setVideoOrientation(orientation)
  }

  private func startStaticFrames(epoch token: Int) {
    staticTask?.cancel()
    staticTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.sendStaticFrame(epoch: token)
        do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
      }
    }
  }

  private func sendStaticFrame(epoch token: Int) async {
    guard token == epoch, publishing, audioOnly, let frame, let stream else { return }
    do { await stream.append(try PublisherStaticFrame.atHostTime(frame)) }
    catch { await dropped(epoch: token) }
  }

  func selectTrack(_ id: UInt8?, mediaType: CMFormatDescription.MediaType) async {}
  nonisolated func mixer(_ mixer: MediaMixer, didOutput sample: CMSampleBuffer) {
    Task { await video(sample) }
  }
  nonisolated func mixer(_ mixer: MediaMixer, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime) {
    Task { await audio(buffer, when: when) }
  }
  private func video(_ sample: CMSampleBuffer) async {
    guard publishing, !audioOnly, foreground, let stream else { return }
    await stream.append(sample)
  }
  private func audio(_ buffer: AVAudioPCMBuffer, when: AVAudioTime) async {
    guard publishing, let stream else { return }
    await stream.append(buffer, when: when)
    guard Date().timeIntervalSince(lastMeter) >= 0.1 else { return }
    lastMeter = Date()
    var sum = 0.0
    let frames = Int(buffer.frameLength)
    let channels = Int(buffer.format.channelCount)
    let stride = buffer.format.isInterleaved ? channels : 1
    if let samples = buffer.int16ChannelData?.pointee {
      for index in 0..<frames { let value = Double(samples[index * stride]) / 32768; sum += value * value }
    } else if let samples = buffer.floatChannelData?.pointee {
      for index in 0..<frames { let value = Double(samples[index * stride]); sum += value * value }
    }
    let rms = muted || frames == 0 ? 0 : min(1, sqrt(sum / Double(frames)))
    await emit(PublisherEvent(name: "audioLevel", generation: generation, value: rms))
  }
}
#endif
