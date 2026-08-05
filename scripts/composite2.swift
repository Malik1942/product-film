import AVFoundation
import AppKit
// usage: composite2 <in> <out> <trimStart> <trimDur> "<t fx fy scale rot; ...>" [rate] [cropTop] [pressT]
let a = CommandLine.arguments
guard a.count >= 6 else {
    fputs("usage: swift composite2.swift <in> <out> <trimStart> <trimDur> \"<t fx fy scale rot; ...>\" [rate] [cropTop] [pressT] [tapT tapFx tapFy] [curT0 curT1 curFx0 curFy0]\n       env: FILL=1 | FRAMELESS=1 | FRAME_PNG/SCREEN_RECT | CROP=l,t,r,b | CURSOR_STYLE=arrow|dot|none | CUES=\"t fx fy [click]; ...\"\n", stderr)
    exit(2)
}
guard FileManager.default.fileExists(atPath: a[1]) else { fputs("error: no such file: \(a[1])\n", stderr); exit(1) }
let inURL = URL(fileURLWithPath: a[1]), outURL = URL(fileURLWithPath: a[2])
let trimStart = Double(a[3])!, trimDur = Double(a[4])!
struct KF { let t: Double; let fx: Double; let fy: Double; let k: Double; let rot: Double }
let plan: [KF] = a[5].split(separator: ";").map {
    let p = $0.split(separator: " ").compactMap { Double($0) }
    return KF(t: p[0], fx: p[1], fy: p[2], k: p[3], rot: p[4])
}
let rate = a.count > 6 ? Double(a[6])! : 1.0
let cropTop = a.count > 7 ? Double(a[7])! : 0.0
let pressT = a.count > 8 ? Double(a[8])! : -1.0
let tapT = a.count > 9 ? Double(a[9])! : -1.0
let tapFx = a.count > 10 ? Double(a[10])! : 0.5
let tapFy = a.count > 11 ? Double(a[11])! : 0.5
let curT0 = a.count > 12 ? Double(a[12])! : -1.0
let curT1 = a.count > 13 ? Double(a[13])! : -1.0
let curFx0 = a.count > 14 ? Double(a[14])! : 0.5
let curFy0 = a.count > 15 ? Double(a[15])! : 0.5
try? FileManager.default.removeItem(at: outURL)

let asset = AVURLAsset(url: inURL)
let vTrack = asset.tracks(withMediaType: .video)[0]
let srcDur = CMTimeGetSeconds(asset.duration)
let start = trimStart < 0 ? max(0, srcDur + trimStart) : trimStart
let dur = min(trimDur, srcDur - start)
let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                        duration: CMTime(seconds: dur, preferredTimescale: 600))
let comp = AVMutableComposition()
let cTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
try cTrack.insertTimeRange(range, of: vTrack, at: .zero)
let outDur = dur / rate
if rate != 1.0 {
    cTrack.scaleTimeRange(CMTimeRange(start: .zero, duration: range.duration),
                          toDuration: CMTime(seconds: outDur, preferredTimescale: 600))
}

let W: CGFloat = 2560, H: CGFloat = 1440
// Surface config via env:
//   FRAMELESS=1            -> no device frame; footage in a rounded card (websites, Figma prototypes)
//   FILL=1                 -> DESKTOP mode: content cover-fills the canvas at every zoom level;
//                             camera pans clamp to content bounds (no black ever visible); rot forced 0
//   FRAME_PNG=/path.png    -> device frame image (default: the skill's assets/iphone-mockup.png)
//   SCREEN_RECT=x,y,w,h    -> transparent screen cutout inside the frame image
//   CONTENT_H=px           -> displayed content height on canvas (default 1200 framed, 86% frameless)
//   CROP=l,t,r,b           -> trim junk pixels off the SOURCE before anything else (source px):
//                             scrollbars, a window edge, a stray strip of desktop caught by the
//                             capture region. On the desktop path these would otherwise be
//                             cover-filled across the canvas as a black bar. Fill/aspect math
//                             uses the cropped size, so the clean region still fills the frame.
//   CURSOR_STYLE=arrow|dot|none -> synthetic cursor shape (default: arrow in FILL mode, dot otherwise).
//                             USE none WHEN THE CAPTURE ALREADY SHOWS A POINTER (screencapture -v
//                             records the real cursor, and some sites draw their own): a second
//                             synthetic pointer next to the real one is an instant reject. With
//                             none, CUES still place click rings on the real pointer's position.
//   CURSOR_PX=px           -> cursor size (default 64 arrow, 52 dot)
let env = ProcessInfo.processInfo.environment
let fill = env["FILL"] == "1"
let frameless = env["FRAMELESS"] == "1" || fill
// Default frame ships with the skill (assets/iphone-mockup.png, resolved beside this script)
let skillDir = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath()
    .deletingLastPathComponent().deletingLastPathComponent()
let mockPath = env["FRAME_PNG"] ?? skillDir.appendingPathComponent("assets/iphone-mockup.png").path
var mockCG: CGImage? = nil
var mw: CGFloat = 0, mh: CGFloat = 0
var screen = CGRect.zero
let srcSize = vTrack.naturalSize
// CROP=l,t,r,b in source pixels — everything downstream sees only the clean region
let cropPx = (env["CROP"] ?? "").split(separator: ",").compactMap { Double($0) }
let cL = cropPx.count == 4 ? CGFloat(cropPx[0]) : 0, cT = cropPx.count == 4 ? CGFloat(cropPx[1]) : 0
let cR = cropPx.count == 4 ? CGFloat(cropPx[2]) : 0, cB = cropPx.count == 4 ? CGFloat(cropPx[3]) : 0
let effW = srcSize.width - cL - cR, effH = srcSize.height - cT - cB
if frameless {
    mw = effW; mh = effH
    screen = CGRect(x: 0, y: 0, width: mw, height: mh)
} else {
    let mock = NSImage(contentsOfFile: mockPath)!
    mockCG = mock.cgImage(forProposedRect: nil, context: nil, hints: nil)
    mw = CGFloat(mockCG!.width); mh = CGFloat(mockCG!.height)
    if let r = env["SCREEN_RECT"] {
        let p = r.split(separator: ",").compactMap { Double($0) }
        screen = CGRect(x: p[0], y: p[1], width: p[2], height: p[3])
    } else {
        screen = CGRect(x: 60, y: 58, width: 999, height: 2173)
    }
}
var devH: CGFloat = CGFloat(Double(env["CONTENT_H"] ?? "") ?? (frameless ? 0 : 1200))
if fill {
    // cover the canvas exactly at scale 1.0 — zoomed out means edge-flush, never letterboxed
    devH = mh * max(W / mw, H / mh)
} else if frameless && devH == 0 {
    // fit within 88% width x 86% height, preserving source aspect
    devH = min(H * 0.86, W * 0.88 * (mh/mw))
}
let s = devH / mh, devW = mw * s

let parent = CALayer()
parent.frame = CGRect(x: 0, y: 0, width: W, height: H)
parent.backgroundColor = NSColor.black.cgColor
let device = CALayer()
device.bounds = CGRect(x: 0, y: 0, width: devW, height: devH)
device.position = CGPoint(x: W/2, y: H/2)
device.shadowColor = NSColor.white.cgColor
device.shadowOpacity = fill ? 0 : 0.13; device.shadowRadius = 80; device.shadowOffset = .zero

// screen container inset inside the bezel opening with matching corner radius (edge-bleed fix)
let screenBox = CALayer()
let inset: CGFloat = frameless ? 0 : 5
screenBox.frame = CGRect(x: screen.minX*s + inset, y: (mh - screen.maxY)*s + inset,
                         width: screen.width*s - inset*2, height: screen.height*s - inset*2)
screenBox.cornerRadius = fill ? 0 : (frameless ? 24 : 150 * s)
screenBox.masksToBounds = true
let videoLayer = CALayer()
if cropPx.count == 4 {
    // oversize the video so the cropped-away edges fall outside screenBox's mask
    let fl = cL/srcSize.width, fr = cR/srcSize.width
    let ft = cT/srcSize.height, fb = cB/srcSize.height
    let vw = screenBox.bounds.width / (1 - fl - fr)
    let vh = screenBox.bounds.height / (1 - ft - fb)
    videoLayer.frame = CGRect(x: -fl*vw, y: -fb*vh, width: vw, height: vh)
} else {
    // video oversized inside box: compensate inset + hide top strip (cropTop) below the island area
    let vh = screenBox.bounds.height / (1 - CGFloat(cropTop)) + inset*2
    let vw = screenBox.bounds.width + inset*2
    videoLayer.frame = CGRect(x: -inset, y: screenBox.bounds.height + inset - vh, width: vw, height: vh)
}
screenBox.addSublayer(videoLayer)
device.addSublayer(screenBox)
if let fcg = mockCG {
    let frameLayer = CALayer()
    frameLayer.frame = CGRect(x: 0, y: 0, width: devW, height: devH)
    frameLayer.contents = fcg
    device.addSublayer(frameLayer)
}
if pressT >= 0 {
    let glow = CALayer()
    let gh = devH * 0.055
    glow.frame = CGRect(x: -6, y: devH * 0.80 - gh/2, width: 22, height: gh)
    glow.cornerRadius = 8
    glow.backgroundColor = NSColor.white.cgColor
    glow.opacity = 0
    glow.shadowColor = NSColor.white.cgColor
    glow.shadowOpacity = 1; glow.shadowRadius = 34; glow.shadowOffset = .zero
    device.addSublayer(glow)
    let op = CAKeyframeAnimation(keyPath: "opacity")
    op.values = [0, 0, 1.0, 0.5, 0]
    op.keyTimes = [0, NSNumber(value: pressT/outDur), NSNumber(value: (pressT+0.12)/outDur), NSNumber(value: (pressT+0.3)/outDur), NSNumber(value: min(1.0, (pressT+0.55)/outDur))]
    op.duration = outDur; op.beginTime = AVCoreAnimationBeginTimeAtZero
    op.isRemovedOnCompletion = false; op.fillMode = .forwards
    glow.add(op, forKey: "pulse")
    let nudge = CAKeyframeAnimation(keyPath: "transform.translation.x")
    nudge.values = [0, 0, 8, 0]
    nudge.keyTimes = [0, NSNumber(value: pressT/outDur), NSNumber(value: (pressT+0.1)/outDur), NSNumber(value: (pressT+0.28)/outDur)]
    nudge.duration = outDur; nudge.beginTime = AVCoreAnimationBeginTimeAtZero
    nudge.isRemovedOnCompletion = false; nudge.fillMode = .forwards
    device.add(nudge, forKey: "nudge")
}
let cursorStyle = env["CURSOR_STYLE"] ?? (fill ? "arrow" : "dot")
// CUES="t fx fy [click]; ..." — multi-interaction scenes (t = measured UI-RESPONSE time).
// One persistent cursor glides between every target (a real pointer never teleports),
// press-dipping and rippling before each response. Overrides the single-cue positional args.
// click=0 makes it a silent waypoint (no ring, no dip) — use it for the END of a drag:
// cue the handle's start position with click=1, then its end position with click=0.
struct Cue { let t: Double; let fx: Double; let fy: Double; let click: Bool }
let cues: [Cue] = (env["CUES"] ?? "").split(separator: ";").compactMap {
    let p = $0.split(separator: " ").compactMap { Double($0) }
    return p.count >= 3 ? Cue(t: p[0], fx: p[1], fy: p[2], click: p.count > 3 ? p[3] != 0 : true) : nil
}.sorted { $0.t < $1.t }
let glideDur = Double(env["GLIDE"] ?? "") ?? 1.15
func makeCursorLayer() -> CALayer {
    if cursorStyle == "arrow" {
        // macOS-style pointer: black fill, white outline — readable on light and dark UI.
        // Path tip sits at the layer's top-left; anchorPoint pins position (and press-dip) to the tip.
        let cs = CGFloat(Double(env["CURSOR_PX"] ?? "") ?? 64)
        let shape = CAShapeLayer()
        let u = cs / 20.0   // unit scale for a 20pt-tall reference arrow
        let pts: [(CGFloat, CGFloat)] = [(0,0), (0,16.5), (4.4,12.8), (7.1,18.9), (9.6,17.8), (7.0,11.9), (12.4,11.9)]
        let path = CGMutablePath()
        // layer coords are y-up; tip (0,0 in pointer space) maps to (0, cs)
        path.move(to: CGPoint(x: 0, y: cs))
        for p in pts.dropFirst() { path.addLine(to: CGPoint(x: p.0 * u, y: cs - p.1 * u)) }
        path.closeSubpath()
        shape.path = path
        shape.fillColor = NSColor.black.cgColor
        shape.strokeColor = NSColor.white.cgColor
        shape.lineWidth = max(2, cs * 0.055)
        shape.lineJoin = .round
        shape.bounds = CGRect(x: 0, y: 0, width: cs * 0.7, height: cs)
        shape.anchorPoint = CGPoint(x: 0, y: 1)
        shape.shadowColor = NSColor.black.cgColor
        shape.shadowOpacity = 0.35; shape.shadowRadius = 6; shape.shadowOffset = CGSize(width: 0, height: -2)
        return shape
    } else {
        let dot = CALayer()
        let cr: CGFloat = CGFloat(Double(env["CURSOR_PX"] ?? "") ?? 52) / 2
        dot.bounds = CGRect(x: 0, y: 0, width: cr*2, height: cr*2)
        dot.cornerRadius = cr
        dot.backgroundColor = NSColor.white.withAlphaComponent(0.75).cgColor
        dot.borderColor = NSColor.white.cgColor
        dot.borderWidth = 2
        dot.shadowColor = NSColor.white.cgColor
        dot.shadowOpacity = 0.8; dot.shadowRadius = 16; dot.shadowOffset = .zero
        return dot
    }
}
func addRipple(at fx: Double, _ fy: Double, t: Double) {
    let ripple = CALayer()
    let r: CGFloat = 46
    let bw = screenBox.bounds.width, bh = screenBox.bounds.height
    ripple.frame = CGRect(x: CGFloat(fx)*bw - r, y: bh*(1-CGFloat(fy)) - r, width: r*2, height: r*2)
    ripple.cornerRadius = r
    if cursorStyle == "arrow" {
        // Screen-Studio-style click ring: dark translucent disc + white ring, reads on any page color
        ripple.backgroundColor = NSColor.black.withAlphaComponent(0.22).cgColor
        ripple.borderColor = NSColor.white.cgColor
        ripple.borderWidth = 3
    } else {
        ripple.backgroundColor = NSColor.white.withAlphaComponent(0.55).cgColor
        ripple.borderColor = NSColor.white.cgColor
        ripple.borderWidth = 2
    }
    ripple.opacity = 0
    screenBox.addSublayer(ripple)
    let keys: [NSNumber] = [0, NSNumber(value: max(0, t)/outDur), NSNumber(value: min(1.0, (t+0.1)/outDur)), NSNumber(value: min(1.0, (t+0.5)/outDur))]
    let ro = CAKeyframeAnimation(keyPath: "opacity")
    ro.values = [0, 0, 0.85, 0]; ro.keyTimes = keys
    ro.duration = outDur; ro.beginTime = AVCoreAnimationBeginTimeAtZero
    ro.isRemovedOnCompletion = false; ro.fillMode = .forwards
    ripple.add(ro, forKey: "o")
    let rs = CAKeyframeAnimation(keyPath: "transform.scale")
    rs.values = [0.4, 0.4, 0.7, 1.5]; rs.keyTimes = keys
    rs.duration = outDur; rs.beginTime = AVCoreAnimationBeginTimeAtZero
    rs.isRemovedOnCompletion = false; rs.fillMode = .forwards
    ripple.add(rs, forKey: "s")
}
if !cues.isEmpty && cursorStyle == "none" {
    for c in cues where c.click { addRipple(at: c.fx, c.fy, t: c.t - 0.15) }
} else if !cues.isEmpty {
    let bw = screenBox.bounds.width, bh = screenBox.bounds.height
    func pt(_ fx: Double, _ fy: Double) -> NSPoint { NSPoint(x: CGFloat(fx)*bw, y: bh*(1-CGFloat(fy))) }
    let fromParts = (env["CURSOR_FROM"] ?? "").split(separator: ",").compactMap { Double($0) }
    let from = fromParts.count == 2 ? (fromParts[0], fromParts[1]) : (0.5, 0.85)
    let fadeIn = max(0, Double(env["CURSOR_IN"] ?? "") ?? (cues[0].t - 0.25 - glideDur - 0.2))
    let cur = makeCursorLayer()
    cur.opacity = 0
    cur.position = pt(from.0, from.1)
    screenBox.addSublayer(cur)
    // position path: hold at entry, then eased glide into each target, arriving 0.25s before its response
    var pTimes: [Double] = [0, fadeIn], pVals: [NSPoint] = [pt(from.0, from.1), pt(from.0, from.1)], pEase: [Bool] = [false, false]
    var prevT = fadeIn
    for c in cues {
        let arrive = c.t - 0.25
        let depart = max(prevT, arrive - glideDur)
        if depart > prevT + 0.01 { pTimes.append(depart); pVals.append(pVals.last!); pEase.append(false) }
        if arrive > (pTimes.last ?? 0) + 0.01 {
            pTimes.append(arrive); pVals.append(pt(c.fx, c.fy)); pEase.append(true)
            prevT = arrive
        }
        if c.click { addRipple(at: c.fx, c.fy, t: c.t - 0.15) }
    }
    if outDur > prevT + 0.01 { pTimes.append(outDur); pVals.append(pVals.last!); pEase.append(false) }
    let glide = CAKeyframeAnimation(keyPath: "position")
    glide.values = pVals.map { NSValue(point: $0) }
    glide.keyTimes = pTimes.map { NSNumber(value: min(1.0, $0/outDur)) }
    glide.timingFunctions = (1..<pVals.count).map {
        pEase[$0] ? CAMediaTimingFunction(controlPoints: 0.4, 0, 0.15, 1) : CAMediaTimingFunction(name: .linear)
    }
    glide.duration = outDur; glide.beginTime = AVCoreAnimationBeginTimeAtZero
    glide.isRemovedOnCompletion = false; glide.fillMode = .forwards
    cur.add(glide, forKey: "p")
    let op = CAKeyframeAnimation(keyPath: "opacity")
    op.values = [0, 0, 0.95, 0.95]
    op.keyTimes = [0, NSNumber(value: fadeIn/outDur), NSNumber(value: min(1.0, (fadeIn+0.3)/outDur)), 1.0]
    op.duration = outDur; op.beginTime = AVCoreAnimationBeginTimeAtZero
    op.isRemovedOnCompletion = false; op.fillMode = .forwards
    cur.add(op, forKey: "o")
    // press dip at every cue (anchored at the arrow's tip, so the point stays put)
    var sTimes: [Double] = [0], sVals: [Double] = [1]
    for c in cues where c.click {
        for (dt, v) in [(-0.25, 1.0), (-0.12, 0.78), (0.02, 1.0)] where c.t + dt > (sTimes.last ?? 0) + 0.005 {
            sTimes.append(c.t + dt); sVals.append(v)
        }
    }
    let press = CAKeyframeAnimation(keyPath: "transform.scale")
    press.values = sVals
    press.keyTimes = sTimes.map { NSNumber(value: min(1.0, max(0, $0)/outDur)) }
    press.duration = outDur; press.beginTime = AVCoreAnimationBeginTimeAtZero
    press.isRemovedOnCompletion = false; press.fillMode = .forwards
    cur.add(press, forKey: "s")
}
if cues.isEmpty && curT0 >= 0 {
    let bw = screenBox.bounds.width, bh = screenBox.bounds.height
    let cur = makeCursorLayer()
    cur.opacity = 0
    cur.position = CGPoint(x: CGFloat(curFx0)*bw, y: bh*(1-CGFloat(curFy0)))
    screenBox.addSublayer(cur)
    let fadeIn = CAKeyframeAnimation(keyPath: "opacity")
    fadeIn.values = [0, 0, 0.9, 0.9, 0.9, 0]
    fadeIn.keyTimes = [0, NSNumber(value: curT0/outDur), NSNumber(value: (curT0+0.25)/outDur),
                       NSNumber(value: (curT1+0.3)/outDur), NSNumber(value: (curT1+0.45)/outDur), NSNumber(value: min(1.0, (curT1+0.6)/outDur))]
    fadeIn.duration = outDur; fadeIn.beginTime = AVCoreAnimationBeginTimeAtZero
    fadeIn.isRemovedOnCompletion = false; fadeIn.fillMode = .forwards
    cur.add(fadeIn, forKey: "o")
    let glide = CAKeyframeAnimation(keyPath: "position")
    glide.values = [NSValue(point: NSPoint(x: CGFloat(curFx0)*bw, y: bh*(1-CGFloat(curFy0)))),
                    NSValue(point: NSPoint(x: CGFloat(curFx0)*bw, y: bh*(1-CGFloat(curFy0)))),
                    NSValue(point: NSPoint(x: CGFloat(tapFx)*bw, y: bh*(1-CGFloat(tapFy))))]
    glide.keyTimes = [0, NSNumber(value: curT0/outDur), NSNumber(value: curT1/outDur)]
    glide.timingFunctions = [CAMediaTimingFunction(name: .linear), CAMediaTimingFunction(controlPoints: 0.4, 0, 0.15, 1)]
    glide.duration = outDur; glide.beginTime = AVCoreAnimationBeginTimeAtZero
    glide.isRemovedOnCompletion = false; glide.fillMode = .forwards
    cur.add(glide, forKey: "p")
    let press = CAKeyframeAnimation(keyPath: "transform.scale")
    press.values = [1, 1, 0.72, 1]
    press.keyTimes = [0, NSNumber(value: (curT1+0.05)/outDur), NSNumber(value: (curT1+0.18)/outDur), NSNumber(value: (curT1+0.34)/outDur)]
    press.duration = outDur; press.beginTime = AVCoreAnimationBeginTimeAtZero
    press.isRemovedOnCompletion = false; press.fillMode = .forwards
    cur.add(press, forKey: "s")
}
if cues.isEmpty && tapT >= 0 {
    addRipple(at: tapFx, tapFy, t: tapT)
}
parent.addSublayer(device)

let ease = CAMediaTimingFunction(controlPoints: 0.35, 0, 0.12, 1)
func anim(_ kp: String, _ vals: [Any], _ times: [NSNumber]) {
    let an = CAKeyframeAnimation(keyPath: kp)
    an.values = vals; an.keyTimes = times
    an.timingFunctions = Array(repeating: ease, count: max(0, vals.count - 1))
    an.duration = outDur; an.beginTime = AVCoreAnimationBeginTimeAtZero
    an.isRemovedOnCompletion = false; an.fillMode = .forwards
    device.add(an, forKey: kp)
}
let times = plan.map { NSNumber(value: min(1.0, $0.t / outDur)) }
// FILL mode: scale never drops below cover (1.0), rotation is disallowed (would expose corners),
// and every position keyframe is clamped so the content edge can never enter the canvas.
// Clamped keyframe endpoints keep the whole interpolated path inside bounds (the box is convex).
anim("transform.scale", plan.map { fill ? max(1.0, $0.k) : $0.k }, times)
anim("transform.rotation.z", plan.map { (fill ? 0 : $0.rot) * .pi / 180 }, times)
anim("position", plan.map { kf -> NSValue in
    let k = CGFloat(fill ? max(1.0, kf.k) : kf.k)
    let px = (kf.fx - 0.5) * devW, py = (0.5 - kf.fy) * devH
    var x = W/2 - k * px, y = H/2 - k * py
    if fill {
        let hw = k * devW / 2, hh = k * devH / 2
        x = min(hw, max(W - hw, x))
        y = min(hh, max(H - hh, y))
    }
    return NSValue(point: NSPoint(x: x, y: y))
}, times)

let vc = AVMutableVideoComposition()
vc.renderSize = CGSize(width: W, height: H)
vc.frameDuration = CMTime(value: 1, timescale: 60)
vc.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)
let inst = AVMutableVideoCompositionInstruction()
inst.timeRange = CMTimeRange(start: .zero, duration: comp.duration)
let li = AVMutableVideoCompositionLayerInstruction(assetTrack: cTrack)
let ns = vTrack.naturalSize
li.setTransform(CGAffineTransform(scaleX: W/ns.width, y: H/ns.height), at: .zero)
inst.layerInstructions = [li]
vc.instructions = [inst]
let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPreset3840x2160)!
ex.outputURL = outURL; ex.outputFileType = .mp4; ex.videoComposition = vc
let sem = DispatchSemaphore(value: 0)
ex.exportAsynchronously { sem.signal() }
sem.wait()
print(ex.status == .completed ? "OK \(outURL.lastPathComponent) \(String(format: "%.1f", outDur))s" : "FAIL \(ex.error?.localizedDescription ?? "?")")
