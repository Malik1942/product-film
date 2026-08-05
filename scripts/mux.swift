import AVFoundation
// usage: swift mux.swift <video.mp4> <audio.m4a> <out.mp4>   — passthrough mux, never re-encodes picture
let args = CommandLine.arguments
guard args.count >= 4 else { fputs("usage: swift mux.swift <video> <audio> <out>\n", stderr); exit(2) }
for p in args[1...2] where !FileManager.default.fileExists(atPath: p) { fputs("error: no such file: \(p)\n", stderr); exit(1) }
let vURL = URL(fileURLWithPath: args[1])
let aURL = URL(fileURLWithPath: args[2])
let outURL = URL(fileURLWithPath: args[3])
try? FileManager.default.removeItem(at: outURL)
let vA = AVURLAsset(url: vURL), aA = AVURLAsset(url: aURL)
let comp = AVMutableComposition()
let vT = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
try vT.insertTimeRange(CMTimeRange(start: .zero, duration: vA.duration), of: vA.tracks(withMediaType: .video)[0], at: .zero)
let aT = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
try aT.insertTimeRange(CMTimeRange(start: .zero, duration: min(aA.duration, vA.duration)), of: aA.tracks(withMediaType: .audio)[0], at: .zero)
let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetPassthrough)!
ex.outputURL = outURL; ex.outputFileType = .mp4
let s = DispatchSemaphore(value: 0); ex.exportAsynchronously { s.signal() }; s.wait()
print(ex.status == .completed ? "OK muxed" : "FAIL \(ex.error?.localizedDescription ?? "?")")
let f = AVURLAsset(url: outURL)
print(String(format: "final: %.2fs video=%d audio=%d", CMTimeGetSeconds(f.duration), f.tracks(withMediaType: .video).count, f.tracks(withMediaType: .audio).count))
exit(ex.status == .completed ? 0 : 1)
