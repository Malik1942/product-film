import AVFoundation
import Foundation

let SR = 48000.0
let FILM = 80.1
let N = Int(FILM * SR)
var mixL = [Float](repeating: 0, count: N)
var mixR = [Float](repeating: 0, count: N)

// automation: wide dynamics (sundown's 15dB range), deep card ducks
let nodes: [(Double, Double)] = [
    (0.0, -60), (1.0, -17), (4.0, -14), (13.9, -13),
    (14.45, -22), (16.7, -22), (17.4, -11),
    (24.9, -11), (25.35, -21), (27.6, -21), (28.3, -8.5),
    (35.5, -8.5), (35.95, -20), (38.2, -20), (38.9, -8),
    (56.0, -8), (56.5, -19), (58.75, -19), (59.4, -4.5),
    (70.5, -4), (71.35, -5), (71.85, -22), (72.85, -22),
    (73.4, -9), (78.3, -10), (80.1, -60)]
func levelDB(_ t: Double) -> Double {
    if t <= nodes[0].0 { return nodes[0].1 }
    for k in 0..<(nodes.count-1) where t >= nodes[k].0 && t <= nodes[k+1].0 {
        let (t0, v0) = nodes[k], (t1, v1) = nodes[k+1]
        let u = (t - t0)/(t1 - t0); let e = u*u*(3-2*u)
        return v0 + (v1 - v0)*e
    }
    return nodes.last!.1
}
func layerEnv(_ t: Double, from: Double, fade: Double = 4.0) -> Double {
    if t < from { return 0 }
    let u = min(1.0, (t - from)/fade); return u*u*(3-2*u)
}

// sundown DNA: ~54 BPM, G major, sub-dominant. 2 bars per chord.
let BPM = 54.0, beat = 60.0/BPM, bar = 4*beat, chordDur = 2*bar
struct Chord { let sub: Double; let tones: [Double] }
let prog = [
    Chord(sub: 49.00, tones: [98.00, 146.83, 196.00, 293.66]),  // G
    Chord(sub: 73.42, tones: [110.00, 146.83, 220.00, 293.66]), // D
    Chord(sub: 82.41, tones: [123.47, 164.81, 246.94, 329.63]), // Em
    Chord(sub: 65.41, tones: [98.00, 130.81, 196.00, 261.63])]  // C
func chordAt(_ t: Double) -> Chord { prog[Int(t/chordDur) % 4] }

var seed: UInt64 = 13579
func rnd() -> Double { seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17; return Double(Int64(bitPattern: seed % 2000000)) / 1000000.0 - 1.0 }

// sparse felt-piano note: long decay, soft attack
func note(at t: Double, freq: Double, amp: Double, decay: Double = 2.6) {
    let a = Int(t*SR), n = Int(min(decay*2.2, 5.0)*SR)
    for k in 0..<n {
        let idx = a + k; if idx < 0 || idx >= N { break }
        let tt = Double(k)/SR
        let env = exp(-tt/decay) * min(1.0, tt/0.020)
        let ph = 2 * .pi * freq * tt
        let v = (sin(ph) + 0.16*sin(2*ph) + 0.05*sin(3*ph)) * env * amp
        mixL[idx] += Float(v); mixR[idx] += Float(v)
    }
}
// deep soft heartbeat (sub only, no click) — sundown's weight
func subPulse(at t: Double, freq: Double, amp: Double) {
    let a = Int(t*SR), n = Int(0.9*SR)
    for k in 0..<n {
        let idx = a + k; if idx < 0 || idx >= N { break }
        let tt = Double(k)/SR
        let env = exp(-tt/0.30) * min(1.0, tt/0.030)
        mixL[idx] += Float(sin(2 * .pi * freq * tt) * env * amp)
        mixR[idx] += Float(sin(2 * .pi * freq * tt) * env * amp)
    }
}

// ---- sustained layers ----
var ph = [Double](repeating: 0, count: 6)
var brown = 0.0
for n in 0..<N {
    let t = Double(n)/SR, dt = 1.0/SR
    let ch = chordAt(t)
    let g = pow(10.0, levelDB(t)/20.0)
    ph[0] += 2 * .pi * ch.sub * dt
    ph[1] += 2 * .pi * ch.tones[0] * dt
    ph[2] += 2 * .pi * (ch.tones[0] + 0.08) * dt
    ph[3] += 2 * .pi * ch.tones[1] * dt
    ph[4] += 2 * .pi * ch.tones[2] * dt
    ph[5] += 2 * .pi * ch.tones[3] * dt
    // sub fundamental — the 73%-low signature
    let sub = (sin(ph[0]) + 0.22*sin(2*ph[0])) * 0.30 * layerEnv(t, from: 0.6, fade: 3)
    // warm pad
    let pad = ((sin(ph[1]) + sin(ph[2]))*0.5 + sin(ph[3])*0.7) * 0.085 * layerEnv(t, from: 3.5, fade: 6)
    // upper voice enters at ocean act
    let upper = sin(ph[4]) * 0.05 * layerEnv(t, from: 27.85, fade: 6)
    // airy top in ask act
    let trem = 0.6 + 0.4 * sin(2 * .pi * 0.07 * t)
    let top = sin(ph[5]) * 0.028 * trem * layerEnv(t, from: 59.0, fade: 6)
    // ocean wash
    brown += 0.05 * (rnd() - brown * 0.05)
    let wash = brown * 0.022 * (0.6 + 0.4*sin(2 * .pi * 0.045 * t))
    let v = Float((sub + pad + upper + top + wash) * g)
    mixL[n] += v * Float(1.0 - 0.05*sin(2 * .pi * 0.035 * t))
    mixR[n] += v * Float(1.0 + 0.05*sin(2 * .pi * 0.035 * t))
}

// ---- sparse melodic events ----
var t = 0.0, barIdx = 0
while t < FILM {
    let ch = chordAt(t)
    let g = pow(10.0, levelDB(t)/20.0)
    // root note each bar, upper voice on bar 2 — breathing, not busy
    note(at: t, freq: ch.tones[1], amp: 0.15 * layerEnv(t, from: 4.0, fade: 5) * g, decay: 2.8)
    if barIdx % 2 == 1 {
        note(at: t + beat*2, freq: ch.tones[2], amp: 0.11 * layerEnv(t, from: 17.0, fade: 5) * g, decay: 2.2)
    }
    if barIdx % 4 == 2 {
        note(at: t + beat, freq: ch.tones[3], amp: 0.07 * layerEnv(t, from: 59.0, fade: 5) * g, decay: 1.8)
    }
    // deep pulse on bar downbeat from capture act
    subPulse(at: t, freq: ch.sub, amp: 0.20 * layerEnv(t, from: 17.0, fade: 4) * g)
    barIdx += 1
    t += bar
}

// ---- SFX ----
func addSubBloom(at t: Double, peakDB: Double, dur: Double = 1.8, f0: Double = 49.0) {
    let a = Int(t*SR), n = Int(dur*SR)
    let amp = pow(10.0, peakDB/20.0)
    for k in 0..<n {
        let idx = a + k; if idx < 0 || idx >= N { continue }
        let u = Double(k)/Double(n)
        let env = pow(sin(.pi * min(1.0, u/0.35) * 0.5), 2.0) * pow(1.0 - u, 1.4)
        let p = 2.0 * .pi * f0 * Double(k)/SR
        let v = Float((sin(p) + 0.3*sin(2*p)) * env * amp)
        mixL[idx] += v; mixR[idx] += v
    }
}
func addSwell(endAt t: Double, dur: Double = 2.2, peakDB: Double = -20) {
    let a = Int((t - dur)*SR), n = Int(dur*SR)
    let amp = pow(10.0, peakDB/20.0)
    var lp = 0.0
    for k in 0..<n {
        let idx = a + k; if idx < 0 || idx >= N { continue }
        let u = Double(k)/Double(n)
        let fc = 120.0 + 900.0 * u * u
        let al = 1.0 - exp(-2.0 * .pi * fc / SR)
        lp += al * (rnd() - lp)
        let v = Float(lp * pow(u, 2.6) * amp)
        mixL[idx] += v * 0.9; mixR[idx] += v * 1.1
    }
}
func addTick(at t: Double, peakDB: Double = -21) {
    let a = Int(t*SR)
    let amp = pow(10.0, peakDB/20.0)
    let n2 = Int(0.08*SR)
    for k in 0..<n2 {
        let idx = a + k; if idx < 0 || idx >= N { continue }
        let u = Double(k)/Double(n2)
        let v = Float((sin(2 * .pi * 560 * Double(k)/SR) * 0.45 + sin(2 * .pi * 140 * Double(k)/SR)) * pow(1-u, 2.0) * amp)
        mixL[idx] += v; mixR[idx] += v
    }
}
for c in [14.45, 25.35, 35.95, 56.5] { addSwell(endAt: c); addSubBloom(at: c + 0.55, peakDB: -13) }
addSubBloom(at: 0.6, peakDB: -14)
addSwell(endAt: 73.4, dur: 1.8, peakDB: -19)
addSubBloom(at: 73.5, peakDB: -11)
for t2 in [17.45, 30.15, 40.0, 61.0] { addTick(at: t2) }

// ---- master ----
var pk: Float = 0, pkM: Float = 0
for n in 0..<N { pk = max(pk, max(abs(mixL[n]), abs(mixR[n]))); pkM = max(pkM, abs(mixL[n]+mixR[n])) }
let target = Float(pow(10.0, -1.5/20.0))
let g2 = min(target/pk, (2*target)/pkM)
for n in 0..<N { mixL[n] *= g2; mixR[n] *= g2 }
print(String(format: "sundown-style score: peak %.2f dB, gain %.2f dB", 20*log10(Double(pk)), 20*log10(Double(g2))))

let outURL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["OUT"] ?? "score.m4a")   // OUT env overrides; default = cwd (durable dir, never /tmp)
try? FileManager.default.removeItem(at: outURL)
func writeM4A() throws {
    let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: SR,
                                   AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 320000]
    let f = try AVAudioFile(forWriting: outURL, settings: settings)
    var pos = 0
    while pos < N {
        let n = min(48000, N - pos)
        let buf = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(n))!
        buf.frameLength = AVAudioFrameCount(n)
        for i in 0..<n { buf.floatChannelData![0][i] = mixL[pos+i]; buf.floatChannelData![1][i] = mixR[pos+i] }
        try f.write(from: buf)
        pos += n
    }
}
try writeM4A()
let chk = AVURLAsset(url: outURL)
print(String(format: "score: %.2fs tracks=%d", CMTimeGetSeconds(chk.duration), chk.tracks(withMediaType: .audio).count))
