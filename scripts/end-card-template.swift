import AVFoundation
import AppKit
import CoreText

// Programmatic end card: white-keyed logo mark + credit/CTA line, same motion grammar as title cards.
// usage: swift end-card-template.swift <output.mov> <seconds> <line> <logo.png>
// Brand + style via env, same contract as title-card-template.swift:
//   FONT_FILE=/path.ttf | FONT_NAME=PostScriptName | ACCENTS=RRGGBB,... | W H FPS
//   BG=RRGGBB           background color (default black)
//   LINE_COLOR=RRGGBB   credit/CTA line color (default near-white E6E6E6)
//   LOGO_COLOR=RRGGBB   color the keyed logo is tinted (default white)
//   ENTRANCE=0.7        entrance duration in seconds
//   RISE=-26            entrance travel in px (negative = rise from below; 0 = fade only)
//   LOGO_W=560          logo width in reference-canvas px (scaled with W)
// Defaults are the approved grammar; an explicit user styling direction overrides them.

let args = CommandLine.arguments
guard args.count >= 5, let duration = Double(args[2]) else {
    fputs("usage: swift end-card-template.swift <output.mov> <seconds> <line> <logo.png>\n", stderr)
    exit(2)
}
let output = URL(fileURLWithPath: args[1])
let line = args[3]
let logoURL = URL(fileURLWithPath: args[4])
let env = ProcessInfo.processInfo.environment
let width = Int(env["W"] ?? "2560")!, height = Int(env["H"] ?? "1440")!
let fps: Int32 = Int32(env["FPS"] ?? "60")!
let sx = CGFloat(width) / 2560.0

var displayFontName = env["FONT_NAME"] ?? ""   // empty = SF system font (premium neutral default)
if let fontFile = env["FONT_FILE"] {
    if let provider = CGDataProvider(url: URL(fileURLWithPath: fontFile) as CFURL),
       let gf = CGFont(provider) {
        var err: Unmanaged<CFError>?
        _ = CTFontManagerRegisterGraphicsFont(gf, &err)
        if let ps = gf.postScriptName as String? { displayFontName = ps }
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
let styleKnobs = ["FONT_FILE", "FONT_NAME", "ACCENTS", "BG", "LINE_COLOR", "LOGO_COLOR", "LOGO_W",
                  "ENTRANCE", "RISE", "W", "H", "FPS", "TITLE_COLOR", "SUB_COLOR"]
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
let lineColor = styleColor("LINE_COLOR", NSColor(white: 0.90, alpha: 1))
let logoTint = styleColor("LOGO_COLOR", .white)
let entranceDur = styleNum("ENTRANCE", 0.7)
let risePx = styleNum("RISE", -26)
print("card style: bg=\(env["BG"] ?? "default") line=\(env["LINE_COLOR"] ?? "default") logo=\(env["LOGO_COLOR"] ?? "default") entrance=\(entranceDur)s rise=\(risePx)px accents=\(accents.count) font=\(displayFontName.isEmpty ? "SF (system)" : displayFontName)")

// Recolor the logo white. GOTCHA (cost a broken end card): a logo PNG can report
// hasAlpha:yes yet be black ink on an OPAQUE white background — keying on alpha then
// yields a solid white box. Detect which it is (<5% transparent pixels = opaque) and
// key on inverted luminance instead: black strokes -> opaque white, white paper -> clear.
guard let srcImg = NSImage(contentsOf: logoURL),
      let srcCG = srcImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("cannot read logo \(logoURL.path)\n", stderr); exit(1)
}
let lw = srcCG.width, lh = srcCG.height
var px = [UInt8](repeating: 0, count: lw*lh*4)
let actx = CGContext(data: &px, width: lw, height: lh, bitsPerComponent: 8, bytesPerRow: lw*4,
                     space: CGColorSpaceCreateDeviceRGB(),
                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
actx.draw(srcCG, in: CGRect(x: 0, y: 0, width: lw, height: lh))
var transparentPixels = 0
for i in 0..<(lw*lh) where px[i*4+3] < 200 { transparentPixels += 1 }
let alphaIsMeaningful = Double(transparentPixels) / Double(lw*lh) > 0.05
let tint = logoTint.usingColorSpace(.deviceRGB)!
let tr = Double(tint.redComponent), tg = Double(tint.greenComponent), tb = Double(tint.blueComponent)
for i in 0..<(lw*lh) {
    let a: UInt8
    if alphaIsMeaningful {
        a = px[i*4+3]
    } else {
        let lum = 0.299*Double(px[i*4+0]) + 0.587*Double(px[i*4+1]) + 0.114*Double(px[i*4+2])
        a = UInt8(max(0, min(255, 255 - lum)))
    }
    // premultiplied tint (default white)
    px[i*4+0] = UInt8(Double(a) * tr); px[i*4+1] = UInt8(Double(a) * tg)
    px[i*4+2] = UInt8(Double(a) * tb); px[i*4+3] = a
}
let whiteLogo = actx.makeImage()!

try? FileManager.default.removeItem(at: output)
let writer = try AVAssetWriter(outputURL: output, fileType: .mov)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
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
let lineFont = NSFont(name: displayFontName, size: 54 * sx)
    ?? NSFont.systemFont(ofSize: 54 * sx, weight: .regular)

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

        let seconds = Double(frame)/Double(fps)
        let entrance = smoothstep(seconds/entranceDur)
        let opacity = CGFloat(entrance)
        let rise = CGFloat((1 - entrance) * risePx) * sx
        let H = CGFloat(height), Wc = CGFloat(width)

        let logoW = CGFloat(Double(env["LOGO_W"] ?? "560")!) * sx
        let logoH = logoW * CGFloat(lh)/CGFloat(lw)
        ctx.saveGState()
        ctx.setAlpha(opacity)
        ctx.draw(whiteLogo, in: CGRect(x: (Wc-logoW)/2, y: 0.515*H + rise, width: logoW, height: logoH))
        ctx.restoreGState()

        let g = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = g
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: lineFont, .foregroundColor: lineColor.withAlphaComponent(opacity),
            .paragraphStyle: para, .kern: 3.0 * sx]
        NSAttributedString(string: line, attributes: attrs)
            .draw(in: CGRect(x: 0.086*Wc, y: 0.417*H + rise, width: 0.828*Wc, height: 0.07*H))
        NSGraphicsContext.restoreGraphicsState()

        if !accents.isEmpty {
            let barW = 92 * sx, barH = 7 * sx, gap = 6 * sx
            let rowW = CGFloat(accents.count) * barW + CGFloat(accents.count - 1) * gap
            var x = (Wc - rowW) / 2
            for c in accents {
                ctx.setFillColor(c.withAlphaComponent(opacity).cgColor)
                ctx.fill(CGRect(x: x, y: 0.361*H + rise, width: barW, height: barH))
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
