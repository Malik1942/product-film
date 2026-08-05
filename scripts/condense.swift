import AVFoundation
// usage: condense <in> <out> "a,b,rate;a,b,rate;..."   (rate optional, default 1)
let args = CommandLine.arguments
guard args.count >= 4 else { fputs("usage: swift condense.swift <in> <out> \"a,b[,rate];a,b[,rate];...\"   (rate<0.5 = hold/freeze mode)\n", stderr); exit(2) }
guard FileManager.default.fileExists(atPath: args[1]) else { fputs("error: no such file: \(args[1])\n", stderr); exit(1) }
let src = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let t = src.tracks(withMediaType: .video)[0]
let comp = AVMutableComposition()
let ct = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
var cursor = CMTime.zero
for seg in args[3].split(separator: ";") {
    let p = seg.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces))! }
    let r = CMTimeRange(start: CMTime(seconds: p[0], preferredTimescale: 600),
                        end: CMTime(seconds: p[1], preferredTimescale: 600))
    let rate = p.count > 2 ? p[2] : 1.0
    if rate < 0.5 {
        // hold: repeat a 2-frame chunk (no retime — export-safe)
        let chunkDur = 1.0/30.0
        let chunk = CMTimeRange(start: CMTime(seconds: p[0], preferredTimescale: 600),
                                duration: CMTime(seconds: chunkDur, preferredTimescale: 600))
        let target = (p[1]-p[0])/rate
        let n = max(1, Int((target/chunkDur).rounded()))
        for _ in 0..<n {
            try ct.insertTimeRange(chunk, of: t, at: cursor)
            cursor = CMTimeAdd(cursor, chunk.duration)
        }
    } else {
        try ct.insertTimeRange(r, of: t, at: cursor)
        let newDur = CMTime(seconds: (p[1]-p[0])/rate, preferredTimescale: 600)
        if rate != 1.0 {
            ct.scaleTimeRange(CMTimeRange(start: cursor, duration: r.duration), toDuration: newDur)
        }
        cursor = CMTimeAdd(cursor, rate == 1.0 ? r.duration : newDur)
    }
}
let out = URL(fileURLWithPath: args[2])
try? FileManager.default.removeItem(at: out)
let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
ex.outputURL = out; ex.outputFileType = .mp4
let s = DispatchSemaphore(value: 0); ex.exportAsynchronously { s.signal() }; s.wait()
print(ex.status == .completed ? "OK \(args[2]) \(String(format: "%.1f", CMTimeGetSeconds(comp.duration)))s" : "FAIL \(ex.error?.localizedDescription ?? "?")")
