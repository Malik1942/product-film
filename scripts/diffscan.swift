import AVFoundation
import AppKit
// usage: swift diffscan.swift <video> [step=0.4] [threshold=6]
// MOBILE measurement tool — samples a fixed 60x130 portrait grid. For 16:9 desktop
// footage use diffscan2.swift (aspect-correct, more sensitive, reports change centroids).
let args = CommandLine.arguments
guard args.count >= 2 else { fputs("usage: swift diffscan.swift <video> [step=0.4] [threshold=6]\n", stderr); exit(2) }
guard FileManager.default.fileExists(atPath: args[1]) else { fputs("error: no such file: \(args[1])\n", stderr); exit(1) }
let a = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let step = args.count > 2 ? Double(args[2])! : 0.4
let threshold = args.count > 3 ? Double(args[3])! : 6.0
let dur = CMTimeGetSeconds(a.duration)
let gen = AVAssetImageGenerator(asset: a)
gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
gen.maximumSize = CGSize(width: 60, height: 130)
func gray(_ cg: CGImage) -> [UInt8] {
    let w = 60, h = 130
    var buf = [UInt8](repeating: 0, count: w*h)
    let cs = CGColorSpaceCreateDeviceGray()
    let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w, space: cs, bitmapInfo: 0)!
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    return buf
}
var prev: [UInt8]? = nil
var t = 0.2
var events: [(Double, Double)] = []
while t < dur {
    if let cg = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) {
        let g = gray(cg)
        if let p = prev {
            var s = 0
            for i in 0..<g.count { s += abs(Int(g[i]) - Int(p[i])) }
            let mean = Double(s) / Double(g.count)
            if mean > threshold { events.append((t, mean)) }
        }
        prev = g
    }
    t += step
}
// cluster consecutive events
var clusters: [(Double, Double)] = []
for e in events {
    if let last = clusters.last, e.0 - last.1 < 1.0 {
        clusters[clusters.count-1].1 = e.0
    } else { clusters.append((e.0, e.0)) }
}
for c in clusters { print(String(format: "transition %.1f - %.1f", c.0, c.1)) }
