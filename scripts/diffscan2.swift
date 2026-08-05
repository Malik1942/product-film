import AVFoundation
import AppKit
// diffscan2 — aspect-correct frame-difference measurement.
// usage: swift diffscan2.swift <video> [step=0.1] [threshold=1.2]
//
// Reports, per detected change cluster: the time window AND the centroid + bounding box
// of the changed pixels (as 0-1 screen fractions). The centroid is where the UI responded,
// which is the click target you feed to composite2/autoplan as (fx, fy).
//
// Why not diffscan.swift: that one downsamples to a 60x130 PORTRAIT grid tuned for phone
// screens. On 16:9 desktop footage it squashes the frame and misses small control changes
// (a style card selecting, a slider notch moving) entirely.
let args = CommandLine.arguments
guard args.count > 1 else { fputs("usage: swift diffscan2.swift <video> [step=0.1] [threshold=1.2]\n", stderr); exit(2) }
guard FileManager.default.fileExists(atPath: args[1]) else { fputs("error: no such file: \(args[1])\n", stderr); exit(1) }
let step = args.count > 2 ? Double(args[2])! : 0.1
let thresh = args.count > 3 ? Double(args[3])! : 1.2

let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let duration = CMTimeGetSeconds(asset.duration)
let track = asset.tracks(withMediaType: .video).first!
let ns = track.naturalSize
// sample grid preserves the source aspect
let GW = 192, GH = max(1, Int((Double(GW) * ns.height / ns.width).rounded()))
let gen = AVAssetImageGenerator(asset: asset)
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
gen.maximumSize = CGSize(width: GW * 2, height: GH * 2)

func gray(_ image: CGImage) -> [UInt8] {
    var buf = [UInt8](repeating: 0, count: GW * GH)
    let ctx = CGContext(data: &buf, width: GW, height: GH, bitsPerComponent: 8,
                        bytesPerRow: GW, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: GW, height: GH))
    return buf
}

struct Sample { let t: Double; let mean: Double; let cx: Double; let cy: Double
                let x0: Double; let y0: Double; let x1: Double; let y1: Double }
var prev: [UInt8]?
var samples: [Sample] = []
var t = 0.05
while t < duration {
    if let img = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) {
        let cur = gray(img)
        if let p = prev {
            var sum = 0.0, wsum = 0.0, wx = 0.0, wy = 0.0
            var minX = GW, minY = GH, maxX = -1, maxY = -1
            for i in cur.indices {
                let d = Double(abs(Int(cur[i]) - Int(p[i])))
                sum += d
                if d > 18 {   // pixel counts as "changed"
                    let gx = i % GW, gy = i / GW
                    wsum += d; wx += d * Double(gx); wy += d * Double(gy)
                    minX = min(minX, gx); maxX = max(maxX, gx)
                    minY = min(minY, gy); maxY = max(maxY, gy)
                }
            }
            let mean = sum / Double(cur.count)
            if mean > thresh && wsum > 0 {
                // buffer row 0 is the TOP row here, so gy/GH is already the from-top fraction
                // (verified: a style-card click reports its centroid on the QR preview at fy≈0.61,
                // which is where the QR actually sits). fx/fy match composite2's convention.
                let cx = wx / wsum / Double(GW)
                let cy = wy / wsum / Double(GH)
                samples.append(Sample(t: t, mean: mean, cx: cx, cy: cy,
                                      x0: Double(minX)/Double(GW), y0: Double(minY)/Double(GH),
                                      x1: Double(maxX)/Double(GW), y1: Double(maxY)/Double(GH)))
            }
        }
        prev = cur
    }
    t += step
}

// cluster consecutive change samples (gap <= 0.45s)
struct Cluster { var a: Double; var b: Double; var peak: Double; var pcx: Double; var pcy: Double
                 var x0: Double; var y0: Double; var x1: Double; var y1: Double }
var clusters: [Cluster] = []
for s in samples {
    if var last = clusters.last, s.t - last.b <= 0.45 {
        last.b = s.t
        last.x0 = min(last.x0, s.x0); last.y0 = min(last.y0, s.y0)
        last.x1 = max(last.x1, s.x1); last.y1 = max(last.y1, s.y1)
        if s.mean > last.peak { last.peak = s.mean; last.pcx = s.cx; last.pcy = s.cy }
        clusters[clusters.count - 1] = last
    } else {
        clusters.append(Cluster(a: s.t, b: s.t, peak: s.mean, pcx: s.cx, pcy: s.cy,
                                x0: s.x0, y0: s.y0, x1: s.x1, y1: s.y1))
    }
}
print(String(format: "duration %.2fs  grid %dx%d  step %.2f", duration, GW, GH, step))
for c in clusters {
    print(String(format: "change %5.2f - %5.2f  peak %5.1f  centroid fx=%.3f fy=%.3f  box [%.2f,%.2f]-[%.2f,%.2f]",
                 c.a, c.b, c.peak, c.pcx, c.pcy, c.x0, c.y0, c.x1, c.y1))
}
