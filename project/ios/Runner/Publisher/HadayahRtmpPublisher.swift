#if IOS_PHONE_PUBLISHING
import AVFoundation
import Flutter
import HaishinKit
import Logboard
import RTMPHaishinKit
import UIKit

@MainActor
final class HadayahRtmpPublisher: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var startTask: Task<Void, Never>?
  private var attempt = 0
  private var observers: [NSObjectProtocol] = []
  private lazy var pipeline = PublisherPipeline { [weak self] event in
    await self?.send(event)
  }

  nonisolated static func register(with registrar: FlutterPluginRegistrar) {
    MainActor.assumeIsolated {
      // SDK diagnostics can include the ingest URL. Discard only these SDK loggers;
      // fixed bridge errors still reach Flutter and compiler warnings are untouched.
      LBLogger.with(kHaishinKitIdentifier).appender = NullAppender.shared
      LBLogger.with(kRTMPHaishinKitIdentifier).appender = NullAppender.shared
      let plugin = HadayahRtmpPublisher()
      registrar.addMethodCallDelegate(plugin, channel: FlutterMethodChannel(
        name: "streamer_app/rtmp_publisher", binaryMessenger: registrar.messenger()))
      FlutterEventChannel(name: "streamer_app/rtmp_publisher/events",
        binaryMessenger: registrar.messenger()).setStreamHandler(plugin)
      registrar.register(PublisherPreviewFactory(pipeline: plugin.pipeline),
        withId: "streamer_app/rtmp_camera_preview")
      plugin.observeLifecycle()
    }
  }

  nonisolated func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    MainActor.assumeIsolated { handleOnMain(call, result: result) }
  }

  private func handleOnMain(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "isSupported" { result(true); return }
    let args = call.arguments as? [String: Any] ?? [:]
    if call.method == "startStream" {
      guard let url = args["url"] as? String, let generation = args["generation"] as? Int,
        args["front"] as? Bool != true else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "live.ios_publisher_unavailable", details: nil))
        return
      }
      startTask?.cancel()
      attempt += 1
      let ticket = attempt
      let muted = args["muted"] as? Bool ?? false
      let audioOnly = args["audioOnly"] as? Bool ?? false
      // Android contract: acknowledge the attempt now; only a native live event
      // confirms publishing. In particular, Dart's retry watchdog starts on ACK.
      result(nil)
      startTask = Task {
        do {
          try await pipeline.start(url: url, muted: muted, audioOnly: audioOnly, generation: generation)
        } catch {
          guard !Task.isCancelled, ticket == attempt else { return }
          await pipeline.pauseForRecovery()
          guard !Task.isCancelled, ticket == attempt else { return }
          send(PublisherEvent(name: "disconnected", generation: generation))
        }
      }
      return
    }
    if call.method == "stopStream" || call.method == "dispose" {
      attempt += 1
      startTask?.cancel(); startTask = nil
    }
    Task {
      do {
        switch call.method {
        case "prepare":
          guard let width = args["width"] as? Int, let height = args["height"] as? Int,
            let bitrate = args["videoBitrate"] as? Int else { throw PublisherPipeline.Failure.invalidArguments }
          try await pipeline.prepare(width: width, height: height, bitrate: bitrate,
            audioOnly: args["audioOnly"] as? Bool ?? false,
            title: Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Hadayah Live")
        case "setMuted": await pipeline.setMuted(args["muted"] as? Bool ?? false)
        case "setAudioOnly": try await pipeline.setAudioOnly(args["audioOnly"] as? Bool ?? false)
        case "setOrientation": await pipeline.orientation(args["orientation"] as? Int ?? 0)
        case "stopStream":
          if args["retry"] as? Bool == true { await pipeline.pauseForRecovery() }
          else { await pipeline.stop() }
        case "dispose": await pipeline.dispose()
        default: result(FlutterMethodNotImplemented); return
        }
        result(nil)
      } catch is CancellationError {
        result(FlutterError(code: "CANCELLED", message: "live.ios_publisher_unavailable", details: nil))
      } catch PublisherPipeline.Failure.permission {
        result(FlutterError(code: "PERMISSION_DENIED", message: "live.ios_publisher_unavailable", details: nil))
      } catch {
        // Never include call.arguments, the URL, stream name, or an SDK description.
        result(FlutterError(code: "PUBLISHER_FAILED", message: "live.ios_publisher_unavailable", details: nil))
      }
    }
  }

  private func send(_ event: PublisherEvent) {
    var payload: [String: Any] = ["type": event.name, "generation": event.generation]
    if let value = event.value { payload["value"] = value }
    if let mode = event.audioOnly { payload["audioOnly"] = mode }
    eventSink?(payload)
  }

  nonisolated func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    MainActor.assumeIsolated { eventSink = events; return nil }
  }
  nonisolated func onCancel(withArguments arguments: Any?) -> FlutterError? {
    MainActor.assumeIsolated {
      eventSink = nil
      attempt += 1
      startTask?.cancel(); startTask = nil
      Task { await pipeline.stop() }
      return nil
    }
  }

  private func observeLifecycle() {
    let center = NotificationCenter.default
    observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
      object: nil, queue: .main) { [weak self] _ in
        Task { @MainActor in await self?.pipeline.background() }
      })
    observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification,
      object: nil, queue: .main) { [weak self] _ in
        Task { @MainActor in await self?.pipeline.becameActive() }
      })
    observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(), queue: .main) { [weak self] notification in
        guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
          type == AVAudioSession.InterruptionType.began.rawValue else { return }
        Task { @MainActor in await self?.pipeline.interruption() }
      })
  }

  deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
}

@MainActor
private final class PublisherPreviewFactory: NSObject, FlutterPlatformViewFactory {
  let pipeline: PublisherPipeline
  init(pipeline: PublisherPipeline) { self.pipeline = pipeline }
  nonisolated func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    MainActor.assumeIsolated { PublisherPreview(frame: frame, pipeline: pipeline) }
  }
}

@MainActor
private final class PublisherPreview: NSObject, FlutterPlatformView {
  private let container: PublisherPreviewContainer
  init(frame: CGRect, pipeline: PublisherPipeline) {
    container = PublisherPreviewContainer(frame: frame, pipeline: pipeline)
    super.init()
  }
  nonisolated func view() -> UIView { MainActor.assumeIsolated { container } }
}

@MainActor
private final class PublisherPreviewContainer: UIView {
  private let preview = MTHKView(frame: .zero)
  private let pipeline: PublisherPipeline
  private var orientation: UIInterfaceOrientation?
  init(frame: CGRect, pipeline: PublisherPipeline) {
    self.pipeline = pipeline
    super.init(frame: frame)
    preview.videoGravity = .resizeAspect
    addSubview(preview)
    Task { await pipeline.attachPreview(preview) }
  }
  required init?(coder: NSCoder) { fatalError("Programmatic publisher preview only") }
  override func layoutSubviews() {
    super.layoutSubviews()
    preview.frame = bounds
    guard let current = window?.windowScene?.interfaceOrientation, current != orientation else { return }
    orientation = current
    let degrees: Int
    switch current {
    case .landscapeLeft: degrees = 270
    case .landscapeRight: degrees = 90
    case .portraitUpsideDown: degrees = 180
    default: degrees = 0
    }
    Task { await pipeline.orientation(degrees) }
  }
  deinit {
    let pipeline = self.pipeline; let preview = self.preview
    Task { await pipeline.detachPreview(preview) }
  }
}
#endif
