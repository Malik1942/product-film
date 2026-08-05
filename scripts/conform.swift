import AVFoundation
// conform.swift — CFR ingest conform. usage: conform <in> <out> [fps=60]
//
// WHY THIS EXISTS: sckrecord (ScreenCaptureKit) emits VARIABLE frame rate — a frame only when
// pixels change. That is correct capture behaviour but it corrupts downstream editing:
// condense's hold mode assumes a frame exists inside its 1/30s chunk (during a VFR gap there is
// none -> non-monotonic/negative-span output), and scaleTimeRange retimes propagate the gaps
// instead of resampling. Conform EVERY take at ingest, before measuring or cutting.
let a = CommandLine.arguments
guard a.count >= 3 else { fputs("usage: conform <in> <out> [fps=60]\n", stderr); exit(2) }
guard FileManager.default.fileExists(atPath: a[1]) else { fputs("error: no such file: \(a[1])\n", stderr); exit(1) }
let fps = a.count > 3 ? Int32(a[3])! : 60
let inURL = URL(fileURLWithPath: a[1]), outURL = URL(fileURLWithPath: a[2])
try? FileManager.default.removeItem(at: outURL)

let asset = AVURLAsset(url: inURL)
guard let src = asset.tracks(withMediaType: .video).first else { fputs("no video track\n", stderr); exit(1) }
let size = src.naturalSize

let comp = AVMutableComposition()
let t = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
try t.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: src, at: .zero)

let vc = AVMutableVideoComposition()
vc.renderSize = size
vc.frameDuration = CMTime(value: 1, timescale: fps)   // forces a frame every 1/fps
let inst = AVMutableVideoCompositionInstruction()
inst.timeRange = CMTimeRange(start: .zero, duration: comp.duration)
let li = AVMutableVideoCompositionLayerInstruction(assetTrack: t)
li.setTransform(src.preferredTransform, at: .zero)
inst.layerInstructions = [li]
vc.instructions = [inst]

let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
ex.outputURL = outURL; ex.outputFileType = .mp4; ex.videoComposition = vc
let sem = DispatchSemaphore(value: 0)
ex.exportAsynchronously { sem.signal() }
sem.wait()
if ex.status == .completed {
    let out = AVURLAsset(url: outURL)
    print(String(format: "OK %@ %.2fs @%dfps CFR", outURL.lastPathComponent, CMTimeGetSeconds(out.duration), fps))
} else {
    print("FAIL \(ex.error?.localizedDescription ?? "?")"); exit(1)
}
