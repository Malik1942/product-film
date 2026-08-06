import AVFoundation
import ScreenCaptureKit
import CoreMedia
import CoreGraphics

// sckrecord — ScreenCaptureKit region recorder (the tool screencapture -v should have been).
// Picks the display that CONTAINS the rect (global top-left points) and forces the
// output scale explicitly (default 2x for a HiDPI film canvas) — SCDisplay.width often
// reports logical 1x, so trusting it silently halves the capture resolution.
// showsCursor=false: the compositor supplies the synthetic pointer (product-film's
// CURSOR_STYLE=arrow). SHOWCURSOR=1 env bakes the OS pointer in — for a real-pointer
// contract (composite CURSOR_STYLE=none) or rollgate.sh's wiggle test, whose motion
// must register as pixels.
// Excludes overlay/agent windows (IDEs, chat apps) that would composite into the take.
// usage: sckrecord <x> <y> <w> <h> <out.mov> [scale=2]
// Stop with SIGINT; finalizes the file and prints the frame count.

let args = CommandLine.arguments
guard args.count >= 6, let rx = Double(args[1]), let ry = Double(args[2]),
      let rw = Double(args[3]), let rh = Double(args[4]) else {
    fputs("usage: sckrecord <x> <y> <w> <h> <out.mov> [scale=2]\n", stderr); exit(2)
}
let outURL = URL(fileURLWithPath: args[5])
try? FileManager.default.removeItem(at: outURL)

let sem = DispatchSemaphore(value: 0)
var streamRef: SCStream?
var writerRef: AVAssetWriter?
var inputRef: AVAssetWriterInput?
var adaptorRef: AVAssetWriterInputPixelBufferAdaptor?
var sessionStarted = false
var frameCount = 0

final class Output: NSObject, SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sb.isValid else { return }
        guard let atts = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let statusRaw = atts.first?[.status] as? Int,
              statusRaw == SCFrameStatus.complete.rawValue,
              let pb = CMSampleBufferGetImageBuffer(sb) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sb)
        guard let writer = writerRef, let input = inputRef, let adaptor = adaptorRef else { return }
        if !sessionStarted {
            writer.startSession(atSourceTime: pts)
            sessionStarted = true
        }
        if input.isReadyForMoreMediaData {
            adaptor.append(pb, withPresentationTime: pts)
            frameCount += 1
        }
    }
}
let outputHandler = Output()

signal(SIGINT, SIG_IGN)
let sigSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigSrc.setEventHandler {
    Task {
        try? await streamRef?.stopCapture()
        inputRef?.markAsFinished()
        await writerRef?.finishWriting()
        print("DONE frames=\(frameCount)")
        exit(0)
    }
}
sigSrc.resume()

Task {
    do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        let global = CGRect(x: rx, y: ry, width: rw, height: rh)
        let display = content.displays.first { $0.frame.intersects(global.insetBy(dx: 4, dy: 4)) }
            ?? content.displays.first { $0.displayID == CGMainDisplayID() }
            ?? content.displays.first
        guard let display else { fputs("no display\n", stderr); exit(1) }
        let local = global.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
        // SCDisplay.width is often logical pts (scale=1) even on Retina. Film canvas is 2x.
        let scale = args.count > 6 ? Double(args[6])! : 2.0
        let outW = Int((rw * scale).rounded())
        let outH = Int((rh * scale).rounded())

        let skipHints = ["cursor", "todesktop", "claude", "chatgpt", "wispr", "wechat", "resolve"]
        let excluded = content.windows.filter { win in
            let blob = ((win.owningApplication?.applicationName ?? "") + " "
                + (win.owningApplication?.bundleIdentifier ?? "")).lowercased()
            return skipHints.contains(where: { blob.contains($0) })
        }
        let filter = SCContentFilter(display: display, excludingWindows: excluded)
        let cfg = SCStreamConfiguration()
        cfg.sourceRect = local
        cfg.width = outW
        cfg.height = outH
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        cfg.queueDepth = 8
        cfg.showsCursor = ProcessInfo.processInfo.environment["SHOWCURSOR"] == "1"
        cfg.pixelFormat = kCVPixelFormatType_32BGRA

        let writer = try AVAssetWriter(outputURL: outURL, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: outW, AVVideoHeightKey: outH,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 40_000_000,
                AVVideoExpectedSourceFrameRateKey: 60,
                AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        writer.startWriting()
        writerRef = writer; inputRef = input; adaptorRef = adaptor

        let stream = SCStream(filter: filter, configuration: cfg, delegate: nil)
        try stream.addStreamOutput(outputHandler, type: .screen, sampleHandlerQueue: DispatchQueue(label: "cap", qos: .userInteractive))
        streamRef = stream
        try await stream.startCapture()
        print("RECORDING display=\(display.displayID) local=\(Int(local.minX)),\(Int(local.minY)) \(Int(rw))x\(Int(rh))pt scale=\(String(format: "%.2f", scale)) -> \(outW)x\(outH) excludeWins=\(excluded.count) \(outURL.path)")
    } catch {
        fputs("start error: \(error)\n", stderr); exit(1)
    }
}
RunLoop.main.run()
