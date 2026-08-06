import AVFoundation
let asset = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
guard let tr = asset.tracks(withMediaType: .video).first,
      let reader = try? AVAssetReader(asset: asset) else { exit(1) }
let out = AVAssetReaderTrackOutput(track: tr, outputSettings: nil)
reader.add(out); reader.startReading()
var t: [Double] = []
while let sb = out.copyNextSampleBuffer() { t.append(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sb))) }
guard t.count > 4 else { exit(1) }
t.sort()
var g: [Double] = []; for i in 1..<t.count { g.append(t[i]-t[i-1]) }
g.sort()
print(String(format: "%.5f", g[g.count/2]))
