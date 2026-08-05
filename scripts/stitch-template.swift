import AVFoundation
import AppKit
// TEMPLATE: copy into the project, then edit `clips` + `trans` for the film's scene order.
// F = fade-up-from-black, Z = zoom-through, B = breath (fade out, black rest, fade up)
// Clip paths resolve against CLIPS_DIR (env; default = current directory).
let env = ProcessInfo.processInfo.environment
let P = (env["CLIPS_DIR"] ?? FileManager.default.currentDirectoryPath) + "/"
let clips = [P + "opening.mp4", P + "onboarding.mp4",
             P + "card-fastcapture.mp4", P + "actionbutton.mp4",
             P + "card-oceangathers.mp4", P + "currents.mp4",
             P + "card-driftsback.mp4", P + "resurface.mp4", P + "library.mp4",
             P + "card-ask.mp4", P + "ask.mp4", P + "endcard.mp4"]
struct Trans { let kind: String; let dur: Double }
let trans: [Trans] = [Trans(kind: "F", dur: 0.45),   // opening -> onboarding
                      Trans(kind: "B", dur: 0.1),    // onboarding -> CARD fast capture
                      Trans(kind: "B", dur: 0.1),    // card -> action button
                      Trans(kind: "B", dur: 0.1),    // action button -> CARD ocean gathers
                      Trans(kind: "B", dur: 0.1),    // card -> currents
                      Trans(kind: "B", dur: 0.1),    // currents -> CARD it drifts back
                      Trans(kind: "B", dur: 0.1),    // card -> resurface
                      Trans(kind: "Z", dur: 0.55),   // resurface -> library
                      Trans(kind: "B", dur: 0.1),    // library -> CARD ask
                      Trans(kind: "B", dur: 0.1),    // card -> ask
                      Trans(kind: "B", dur: 1.0)]    // ask -> end card: final breath
let FADE = 0.5
let W: CGFloat = 2560, H: CGFloat = 1440
func base(_ ns: CGSize) -> CGAffineTransform { CGAffineTransform(scaleX: W/ns.width, y: H/ns.height) }
func zoomed(_ s: CGFloat, _ b: CGAffineTransform) -> CGAffineTransform {
    b.concatenating(CGAffineTransform(translationX: W*(1-s)/2, y: H*(1-s)/2).scaledBy(x: s, y: s))
}
func sOut(_ u: Double) -> CGFloat { CGFloat(1.0 + 2.4 * pow(u, 2.4)) }
func sIn(_ u: Double) -> CGFloat { CGFloat(1.0 + 1.6 * pow(1.0 - u, 2.0)) }
func oOut(_ u: Double) -> Float { u <= 0.5 ? 1 : (u >= 0.8 ? 0 : Float(1 - (u - 0.5)/0.3)) }
func oIn(_ u: Double) -> Float { u <= 0.2 ? 0 : (u >= 0.5 ? 1 : Float((u - 0.2)/0.3)) }

let comp = AVMutableComposition()
let tA = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
let tB = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
var cursor = CMTime.zero
var segs: [(track: AVMutableCompositionTrack, start: Double, end: Double, base: CGAffineTransform)] = []
for (i, path) in clips.enumerated() {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let src = asset.tracks(withMediaType: .video).first else { print("MISSING \(path)"); continue }
    let dst = i % 2 == 0 ? tA : tB
    try dst.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: src, at: cursor)
    segs.append((dst, CMTimeGetSeconds(cursor), CMTimeGetSeconds(cursor) + CMTimeGetSeconds(asset.duration), base(src.naturalSize)))
    if i < trans.count {
        let tk = trans[i]
        if tk.kind == "B" {
            cursor = CMTimeAdd(cursor, CMTimeAdd(asset.duration, CMTime(seconds: tk.dur, preferredTimescale: 600)))
        } else {
            cursor = CMTimeAdd(cursor, CMTimeSubtract(asset.duration, CMTime(seconds: tk.dur, preferredTimescale: 600)))
        }
    }
}
func tr(_ a: Double, _ b: Double) -> CMTimeRange {
    CMTimeRange(start: CMTime(seconds: a, preferredTimescale: 600), end: CMTime(seconds: b, preferredTimescale: 600))
}
var instructions: [AVMutableVideoCompositionInstruction] = []
var t0 = 0.0
for i in 0..<segs.count {
    let seg = segs[i]
    let hasNext = i + 1 < segs.count
    let tk = hasNext ? trans[i] : Trans(kind: "-", dur: 0)
    let nextStart = hasNext ? segs[i+1].start : seg.end
    if tk.kind == "B" {
        // solo until fade-out start
        let fadeStart = seg.end - FADE
        if fadeStart > t0 {
            let inst = AVMutableVideoCompositionInstruction()
            inst.timeRange = tr(t0, fadeStart)
            let li = AVMutableVideoCompositionLayerInstruction(assetTrack: seg.track)
            li.setTransform(seg.base, at: inst.timeRange.start)
            li.setOpacity(1, at: inst.timeRange.start)
            inst.layerInstructions = [li]
            instructions.append(inst)
        }
        // fade out
        let f = AVMutableVideoCompositionInstruction()
        f.timeRange = tr(fadeStart, seg.end)
        let lo = AVMutableVideoCompositionLayerInstruction(assetTrack: seg.track)
        lo.setTransform(seg.base, at: f.timeRange.start)
        lo.setOpacityRamp(fromStartOpacity: 1, toEndOpacity: 0, timeRange: f.timeRange)
        f.layerInstructions = [lo]
        instructions.append(f)
        // black rest
        let b = AVMutableVideoCompositionInstruction()
        b.timeRange = tr(seg.end, nextStart)
        b.backgroundColor = NSColor.black.cgColor
        b.layerInstructions = []
        instructions.append(b)
        // incoming fade-up handled as its own head instruction
        let g = AVMutableVideoCompositionInstruction()
        g.timeRange = tr(nextStart, nextStart + FADE)
        let liIn = AVMutableVideoCompositionLayerInstruction(assetTrack: segs[i+1].track)
        liIn.setTransform(segs[i+1].base, at: g.timeRange.start)
        liIn.setOpacityRamp(fromStartOpacity: 0, toEndOpacity: 1, timeRange: g.timeRange)
        g.layerInstructions = [liIn]
        instructions.append(g)
        t0 = nextStart + FADE
    } else if tk.kind == "F" {
        if nextStart > t0 {
            let inst = AVMutableVideoCompositionInstruction()
            inst.timeRange = tr(t0, nextStart)
            let li = AVMutableVideoCompositionLayerInstruction(assetTrack: seg.track)
            li.setTransform(seg.base, at: inst.timeRange.start)
            li.setOpacity(1, at: inst.timeRange.start)
            inst.layerInstructions = [li]
            instructions.append(inst)
        }
        let inst = AVMutableVideoCompositionInstruction()
        inst.timeRange = tr(nextStart, seg.end)
        let liIn = AVMutableVideoCompositionLayerInstruction(assetTrack: segs[i+1].track)
        liIn.setTransform(segs[i+1].base, at: inst.timeRange.start)
        liIn.setOpacityRamp(fromStartOpacity: 0, toEndOpacity: 1, timeRange: inst.timeRange)
        let liOut = AVMutableVideoCompositionLayerInstruction(assetTrack: seg.track)
        liOut.setTransform(seg.base, at: inst.timeRange.start)
        inst.layerInstructions = [liIn, liOut]
        instructions.append(inst)
        t0 = seg.end
    } else if tk.kind == "Z" {
        if nextStart > t0 {
            let inst = AVMutableVideoCompositionInstruction()
            inst.timeRange = tr(t0, nextStart)
            let li = AVMutableVideoCompositionLayerInstruction(assetTrack: seg.track)
            li.setTransform(seg.base, at: inst.timeRange.start)
            li.setOpacity(1, at: inst.timeRange.start)
            inst.layerInstructions = [li]
            instructions.append(inst)
        }
        let oS = nextStart, oE = seg.end
        let cuts = [0.0, 0.25, 0.45, 0.6, 0.8, 1.0]
        for k in 0..<5 {
            let u0 = cuts[k], u1 = cuts[k+1]
            let inst = AVMutableVideoCompositionInstruction()
            inst.timeRange = tr(oS + (oE-oS)*u0, oS + (oE-oS)*u1)
            let liIn = AVMutableVideoCompositionLayerInstruction(assetTrack: segs[i+1].track)
            liIn.setTransformRamp(fromStart: zoomed(sIn(u0), segs[i+1].base), toEnd: zoomed(sIn(u1), segs[i+1].base), timeRange: inst.timeRange)
            liIn.setOpacityRamp(fromStartOpacity: oIn(u0), toEndOpacity: oIn(u1), timeRange: inst.timeRange)
            let liOut = AVMutableVideoCompositionLayerInstruction(assetTrack: seg.track)
            liOut.setTransformRamp(fromStart: zoomed(sOut(u0), seg.base), toEnd: zoomed(sOut(u1), seg.base), timeRange: inst.timeRange)
            liOut.setOpacityRamp(fromStartOpacity: oOut(u0), toEndOpacity: oOut(u1), timeRange: inst.timeRange)
            inst.layerInstructions = [liIn, liOut]
            instructions.append(inst)
        }
        t0 = oE
    } else {
        // final clip
        let inst = AVMutableVideoCompositionInstruction()
        inst.timeRange = tr(t0, seg.end)
        let li = AVMutableVideoCompositionLayerInstruction(assetTrack: seg.track)
        li.setTransform(seg.base, at: inst.timeRange.start)
        li.setOpacity(1, at: inst.timeRange.start)
        inst.layerInstructions = [li]
        instructions.append(inst)
        t0 = seg.end
    }
}
if let last = instructions.last {
    last.timeRange = CMTimeRange(start: last.timeRange.start, end: comp.duration)
}
let vc = AVMutableVideoComposition()
vc.renderSize = CGSize(width: W, height: H)
vc.frameDuration = CMTime(value: 1, timescale: 60)
vc.instructions = instructions
let out = URL(fileURLWithPath: env["OUT"] ?? "film.mp4")   // OUT env overrides; default = cwd
try? FileManager.default.removeItem(at: out)
let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPreset3840x2160)!
ex.outputURL = out; ex.outputFileType = .mp4; ex.videoComposition = vc
let sem = DispatchSemaphore(value: 0); ex.exportAsynchronously { sem.signal() }; sem.wait()
print(ex.status == .completed ? "OK \(String(format: "%.1f", CMTimeGetSeconds(comp.duration)))s" : "FAIL \(ex.error?.localizedDescription ?? "?")")
