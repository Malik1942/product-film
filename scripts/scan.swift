import AVFoundation
import AppKit
let args = CommandLine.arguments
guard args.count >= 3 else { fputs("usage: swift scan.swift <in.mp4> <out.png> [step-seconds=0.8]\n", stderr); exit(2) }
guard FileManager.default.fileExists(atPath: args[1]) else { fputs("error: no such file: \(args[1])\n", stderr); exit(1) }
let a = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let dur = CMTimeGetSeconds(a.duration)
print(String(format: "duration %.1fs", dur))
let gen = AVAssetImageGenerator(asset: a)
gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
gen.maximumSize = CGSize(width: 150, height: 330)
var imgs: [(Double, NSImage)] = []
var t = 0.4
let step = args.count > 3 ? Double(args[3])! : 0.8
while t < dur {
    if let cg = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) {
        imgs.append((t, NSImage(cgImage: cg, size: NSSize(width: 150, height: 330))))
    }
    t += step
}
let tw = 150, th = 360, cols = 13
let rows = (imgs.count + cols - 1)/cols
let sheet = NSImage(size: NSSize(width: tw*cols, height: th*rows))
sheet.lockFocus()
NSColor.black.setFill(); NSRect(x:0,y:0,width:tw*cols,height:th*rows).fill()
let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.white, .font: NSFont.boldSystemFont(ofSize: 13)]
for (i, p) in imgs.enumerated() {
    let r = i/cols, c = i%cols
    let y = th*(rows-1-r)
    p.1.draw(in: NSRect(x: c*tw, y: y+26, width: 150, height: 330))
    NSString(string: String(format: "%.1f", p.0)).draw(at: NSPoint(x: CGFloat(c*tw)+4, y: CGFloat(y)+2), withAttributes: attrs)
}
sheet.unlockFocus()
let rep = NSBitmapImageRep(data: sheet.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("ok \(imgs.count)")
