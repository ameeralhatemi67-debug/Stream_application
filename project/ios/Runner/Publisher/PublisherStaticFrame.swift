#if IOS_PHONE_PUBLISHING
import CoreGraphics
import CoreMedia
import CoreText
import CoreVideo
import Foundation
import VideoToolbox

// Encode once while foregrounded. Background audio uses copies of this IDR;
// it must not invoke Metal or a hardware video encoder in the background.
enum PublisherStaticFrame {
  enum Failure: Error { case allocation, compression }

  private final class Output {
    let lock = NSLock()
    private var sample: CMSampleBuffer?
    func set(_ value: CMSampleBuffer) { lock.lock(); defer { lock.unlock() }; sample = value }
    func get() -> CMSampleBuffer? { lock.lock(); defer { lock.unlock() }; return sample }
  }

  static func make(width: Int, height: Int, title: String) throws -> CMSampleBuffer {
    var pixel: CVPixelBuffer?
    let attributes: [CFString: Any] = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
    ]
    guard CVPixelBufferCreate(kCFAllocatorDefault, width, height,
      kCVPixelFormatType_32ARGB, attributes as CFDictionary, &pixel) == kCVReturnSuccess,
      let pixel else { throw Failure.allocation }
    CVPixelBufferLockBaseAddress(pixel, [])
    defer { CVPixelBufferUnlockBaseAddress(pixel, []) }
    guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixel),
      width: width, height: height, bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(pixel),
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { throw Failure.allocation }
    // AppTheme.media, shared with the launch screen.
    context.setFillColor(red: 36 / 255, green: 53 / 255, blue: 54 / 255, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
    let text = NSAttributedString(string: title, attributes: [
      NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName(
        "Helvetica" as CFString, CGFloat(height) / 12, nil),
      NSAttributedString.Key(kCTForegroundColorAttributeName as String):
        CGColor(gray: 1, alpha: 1),
    ])
    let line = CTLineCreateWithAttributedString(text as CFAttributedString)
    let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
    context.textPosition = CGPoint(x: (CGFloat(width) - textWidth) / 2,
                                   y: CGFloat(height) / 2)
    CTLineDraw(line, context)

    let output = Output()
    var session: VTCompressionSession?
    let status = VTCompressionSessionCreate(allocator: kCFAllocatorDefault,
      width: Int32(width), height: Int32(height), codecType: kCMVideoCodecType_H264,
      encoderSpecification: nil, imageBufferAttributes: nil, compressedDataAllocator: nil,
      outputCallback: { refcon, _, status, _, sample in
        guard status == noErr, let refcon, let sample else { return }
        Unmanaged<Output>.fromOpaque(refcon).takeUnretainedValue().set(sample)
      }, refcon: Unmanaged.passUnretained(output).toOpaque(), compressionSessionOut: &session)
    guard status == noErr, let session else { throw Failure.compression }
    defer { VTCompressionSessionInvalidate(session) }
    for (key, value) in [
      (kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel as CFTypeRef),
      (kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse as CFTypeRef),
      (kVTCompressionPropertyKey_RealTime, kCFBooleanTrue as CFTypeRef),
    ] {
      guard VTSessionSetProperty(session, key: key, value: value) == noErr else {
        throw Failure.compression
      }
    }
    guard VTCompressionSessionPrepareToEncodeFrames(session) == noErr,
      VTCompressionSessionEncodeFrame(session, imageBuffer: pixel,
        presentationTimeStamp: .zero, duration: CMTime(value: 1, timescale: 1),
        frameProperties: [kVTEncodeFrameOptionKey_ForceKeyFrame: true] as CFDictionary,
        sourceFrameRefcon: nil, infoFlagsOut: nil) == noErr,
      VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid) == noErr,
      let sample = output.get() else { throw Failure.compression }
    return sample
  }

  static func atHostTime(_ sample: CMSampleBuffer) throws -> CMSampleBuffer {
    var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 1),
      presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()), decodeTimeStamp: .invalid)
    var copy: CMSampleBuffer?
    guard CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault,
      sampleBuffer: sample, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
      sampleBufferOut: &copy) == noErr, let copy else { throw Failure.compression }
    return copy
  }
}
#endif
