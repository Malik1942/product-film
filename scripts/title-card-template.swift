import AVFoundation
import AppKit
import CoreText

// Programmatic title card — the PREFERRED card path (Figma is the fallback).
// usage: swift title-card-template.swift <output.mov> <seconds> <TITLE> [subtitle]
// Brand + style via env (all from the approved script's Brand/Vibe blocks — never another product's):
//   FONT_FILE=/path.ttf     register + use this font file (brand font)
//   FONT_NAME=PostScriptName use an installed font instead
//   ACCENTS=RRGGBB,RRGGBB   centered accent bars under the text (product palette; default none)
//   BG=RRGGBB               background color (default black)
//   TITLE_COLOR=RRGGBB      title color (default near-white F7F7F7)
//   SUB_COLOR=RRGGBB        subtitle color (default gray ABABAB)
//   ENTRANCE=0.62           entrance duration in seconds (slower = calmer, faster = punchier)
//   RISE=-26                entrance travel in px (negative = rise from below; 0 = fade only)
//   W=2560 H=1440 FPS=60    canvas
// Defaults are the approved grammar (smoothstep entrance 0.62s, rise -26px, deep kern) —
// an explicit user styling direction overrides them. Deeper styling (easing curves, layout,
// per-brand texture) = copy this template into the project and edit; keep texture quieter than the words.

let args = CommandLine.arguments
guard args.count >= 4, let duration = Double(args[2]) else {
    fputs("usage: swift title-card-template.swift <output.mov> <seconds> <TITLE> [subtitle]\n", stderr)
    exit(2)
}
let output = URL(fileURLWithPath: args[1])
let title = args[3]
let subtitle = args.count > 4 ? args[4] : ""
let env = ProcessInfo.processInfo.environment
let width = Int(env["W"] ?? "2560")!, height = Int(env["H"] ?? "1440")!
let fps: Int32 = Int32(env["FPS"] ?? "60")!
let sx = CGFloat(width) / 2560.0   // scale all pt sizes off the reference canvas

var displayFontName = env["FONT_NAME"] ?? ""   // empty = SF system font (premium neutral default)
if let fontFile = env["FONT_FILE"] {
    if let provider = CGDataProvider(url: URL(fileURLWithPath: fontFile) as CFURL),
       let graphicsFont = CGFont(provider) {
        var err: Unmanaged<CFError>?
        _ = CTFontManagerRegisterGraphicsFont(graphicsFont, &err)
        if let ps = graphicsFont.postScriptName as String? { displayFontName = ps }
    } else { fputs("cannot load FONT_FILE \(fontFile)\n", stderr); exit(1) }
}
func hexColor(_ raw: (some StringProtocol)?) -> NSColor? {
    guard let raw else { return nil }
    let s = String(raw)
    guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
    return NSColor(calibratedRed: CGFloat((v >> 16) & 0xFF)/255,
                   green: CGFloat((v >> 8) & 0xFF)/255,
                   blue: CGFloat(v & 0xFF)/255, alpha: 1)
}
// Knob validation: a silent typo (ENTRACE=0.3) would otherwise render as defaults with no error.
// Sibling template's knobs are accepted silently so one exported env can drive both cards.
let styleKnobs = ["FONT_FILE", "FONT_NAME", "ACCENTS", "BG", "TITLE_COLOR", "SUB_COLOR",
                  "ENTRANCE", "RISE", "W", "H", "FPS", "LINE_COLOR", "LOGO_COLOR", "LOGO_W"]
func editDistance(_ a: String, _ b: String) -> Int {
    let A = Array(a), B = Array(b)
    var d = Array(0...B.count)
    for i in 1...A.count {
        var prev = d[0]; d[0] = i
        for j in 1...B.count {
            let t = d[j]
            d[j] = min(d[j] + 1, d[j-1] + 1, prev + (A[i-1] == B[j-1] ? 0 : 1))
            prev = t
        }
    }
    return d[B.count]
}
for key in env.keys where !styleKnobs.contains(key) && key.count >= 4 {
    if let hit = styleKnobs.first(where: { $0.count >= 4 && editDistance(key, $0) <= 1 }) {
        fputs("warning: env \(key) ignored — did you mean \(hit)?\n", stderr)
    }
}
func styleColor(_ key: String, _ fallback: NSColor) -> NSColor {
    guard let raw = env[key] else { return fallback }
    if let c = hexColor(raw) { return c }
    fputs("warning: \(key)=\(raw) is not RRGGBB — using default\n", stderr)
    return fallback
}
func styleNum(_ key: String, _ fallback: Double) -> Double {
    guard let raw = env[key] else { return fallback }
    if let v = Double(raw) { return v }
    fputs("warning: \(key)=\(raw) is not a number — using default\n", stderr)
    return fallback
}
let accentsRaw = (env["ACCENTS"] ?? "").split(separator: ",")
let accents: [NSColor] = accentsRaw.compactMap { hexColor($0) }
if accents.count != accentsRaw.count {
    fputs("warning: ACCENTS has \(accentsRaw.count - accents.count) invalid entries — expected RRGGBB,RRGGBB\n", stderr)
}
let bgColor = styleColor("BG", .black)
let titleColor = styleColor("TITLE_COLOR", NSColor(white: 0.97, alpha: 1))
let subColor = styleColor("SUB_COLOR", NSColor(white: 0.67, alpha: 1))
let entranceDur = styleNum("ENTRANCE", 0.62)
let risePx = styleNum("RISE", -26)
print("card style: bg=\(env["BG"] ?? "default") title=\(env["TITLE_COLOR"] ?? "default") sub=\(env["SUB_COLOR"] ?? "default") entrance=\(entranceDur)s rise=\(risePx)px accents=\(accents.count) font=\(displayFontName.isEmpty ? "SF (system)" : displayFontName)")

try? FileManager.default.removeItem(at: output)
let writer = try AVAssetWriter(outputURL: output, fileType: .mov)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width, AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 18_000_000,
                                      AVVideoExpectedSourceFrameRateKey: fps,
                                      AVVideoMaxKeyFrameIntervalKey: fps]]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
    kCVPixelBufferIOSurfacePropertiesKey as String: [:]])
writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)

func smoothstep(_ v: Double) -> Double { let x = min(1, max(0, v)); return x*x*(3-2*x) }
let totalFrames = Int((duration * Double(fps)).rounded())
let titleFont = NSFont(name: displayFontName, size: (title.count > 18 ? 160 : 196) * sx)
    ?? NSFont.systemFont(ofSize: (title.count > 18 ? 160 : 196) * sx, weight: .semibold)
let subtitleFont = NSFont(name: displayFontName, size: 42 * sx)
    ?? NSFont.systemFont(ofSize: 42 * sx, weight: .regular)

for frame in 0..<totalFrames {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
    autoreleasepool {
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
        guard let buffer = pb else { return }
        CVPixelBufferLockBaseAddress(buffer, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        ctx.setFillColor(bgColor.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let seconds = Double(frame) / Double(fps)
        let entrance = smoothstep(seconds / entranceDur)
        let opacity = CGFloat(entrance)
        let rise = CGFloat((1 - entrance) * risePx) * sx

        let g = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = g
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let H = CGFloat(height), Wc = CGFloat(width)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont, .foregroundColor: titleColor.withAlphaComponent(opacity),
            .paragraphStyle: para, .kern: -3.0 * sx]
        NSAttributedString(string: title, attributes: titleAttrs)
            .draw(in: CGRect(x: 0.055*Wc, y: 0.455*H + rise, width: 0.89*Wc, height: 0.18*H))
        if !subtitle.isEmpty {
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: subtitleFont, .foregroundColor: subColor.withAlphaComponent(opacity),
                .paragraphStyle: para, .kern: 2.5 * sx]
            NSAttributedString(string: subtitle, attributes: subAttrs)
                .draw(in: CGRect(x: 0.086*Wc, y: 0.378*H + rise, width: 0.828*Wc, height: 0.0625*H))
        }
        NSGraphicsContext.restoreGraphicsState()

        if !accents.isEmpty {
            let barW = 92 * sx, barH = 7 * sx, gap = 6 * sx
            let rowW = CGFloat(accents.count) * barW + CGFloat(accents.count - 1) * gap
            var x = (Wc - rowW) / 2
            for c in accents {
                ctx.setFillColor(c.withAlphaComponent(opacity).cgColor)
                ctx.fill(CGRect(x: x, y: 0.342*H + rise, width: barW, height: barH))
                x += barW + gap
            }
        }

        CVPixelBufferUnlockBaseAddress(buffer, [])
        adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: fps))
    }
}
input.markAsFinished()
writer.finishWriting {
    print(writer.status == .completed ? "OK \(output.lastPathComponent)" : "FAIL \(writer.error?.localizedDescription ?? "?")")
    exit(writer.status == .completed ? 0 : 1)
}
RunLoop.main.run()
