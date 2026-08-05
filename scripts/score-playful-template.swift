import AVFoundation
import Foundation

// PLAYFUL / CHILL / ENERGETIC score template — the counterpart to score-template.swift's
// calm sundown bed. Use when the stated vibe is playful, upbeat, toy-like, or "more energetic".
// EDIT: FILM (picture duration), the `nodes` automation (duck under every title card, lift at
// the film's biggest reveal), ARCADE (the moment energy opens up), the tick times (one per
// MEASURED interaction, film-time), and outURL.
// 96 BPM, C major I-V-vi-IV, plucked arpeggios + soft kit. Energy lifts at the Arcade reveal.
let SR = 48000.0
let FILM = 47.70
let N = Int(FILM * SR)
var mixL = [Float](repeating: 0, count: N)
var mixR = [Float](repeating: 0, count: N)

// EXAMPLE automation from a real 47.7s film (card1 20.75-23.15, lift act 23.25-34.65,
// card2 34.75-37.15, final 37.25-41.25, ending 41.70-47.70) — retime for yours
let nodes: [(Double, Double)] = [
    (0.0, -60), (0.8, -17), (2.6, -13), (12.0, -10), (19.9, -9.5),
    (20.5, -21), (23.5, -21), (24.1, -7.0),           // duck under BREAK THE GRID, then LIFT
    (31.9, -5.5), (33.6, -5.5),                        // arcade act peaks at the gradient
    (34.2, -21), (37.5, -21), (38.1, -6.5),            // duck under TAKE IT WITH YOU
    (40.6, -6.5), (41.2, -19), (41.9, -19), (42.5, -9.0),
    (46.2, -10), (47.70, -26)]
func levelDB(_ t: Double) -> Double {
    if t <= nodes[0].0 { return nodes[0].1 }
    for k in 0..<(nodes.count-1) where t >= nodes[k].0 && t <= nodes[k+1].0 {
        let (t0, v0) = nodes[k], (t1, v1) = nodes[k+1]
        let u = (t - t0)/(t1 - t0); let e = u*u*(3-2*u)
        return v0 + (v1 - v0)*e
    }
    return nodes.last!.1
}
func gainAt(_ t: Double) -> Double { pow(10.0, levelDB(t)/20.0) }
func layerEnv(_ t: Double, from: Double, fade: Double = 3.0) -> Double {
    if t < from { return 0 }
    let u = min(1.0, (t - from)/fade); return u*u*(3-2*u)
}

let BPM = 96.0, beat = 60.0/BPM, bar = 4*beat, eighth = beat/2   // bar = 2.5s
struct Chord { let bass: Double; let tones: [Double] }
let prog = [
    Chord(bass: 65.41, tones: [261.63, 329.63, 392.00, 493.88]), // Cmaj9
    Chord(bass: 98.00, tones: [246.94, 293.66, 392.00, 440.00]), // G6
    Chord(bass: 110.00, tones: [261.63, 329.63, 392.00, 523.25]),// Am7
    Chord(bass: 87.31, tones: [261.63, 329.63, 440.00, 523.25])] // Fmaj7
func chordAt(_ t: Double) -> Chord { prog[Int(t/bar) % 4] }

var seed: UInt64 = 24680
func rnd() -> Double { seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
    return Double(Int64(bitPattern: seed % 2000000)) / 1000000.0 - 1.0 }

func add(_ idx: Int, _ l: Double, _ r: Double) {
    if idx < 0 || idx >= N { return }
    mixL[idx] += Float(l); mixR[idx] += Float(r)
}
// plucked note — short decay, triangle-ish body: the playful engine of the track
func pluck(at t: Double, freq: Double, amp: Double, decay: Double = 0.30, pan: Double = 0) {
    let a = Int(t*SR), n = Int(min(decay*3.5, 1.6)*SR)
    for k in 0..<n {
        let tt = Double(k)/SR
        let env = exp(-tt/decay) * min(1.0, tt/0.004)
        let ph = 2 * .pi * freq * tt
        let v = (sin(ph) + 0.30*sin(3*ph) + 0.12*sin(5*ph)) * env * amp
        add(a+k, v*(1-max(0,pan)*0.55), v*(1+min(0,pan)*0.55))
    }
}
func bassNote(at t: Double, freq: Double, amp: Double, decay: Double = 0.55) {
    let a = Int(t*SR), n = Int(1.2*SR)
    for k in 0..<n {
        let tt = Double(k)/SR
        let env = exp(-tt/decay) * min(1.0, tt/0.012)
        let ph = 2 * .pi * freq * tt
        let v = (sin(ph) + 0.25*sin(2*ph)) * env * amp
        add(a+k, v, v)
    }
}
func kick(at t: Double, amp: Double) {
    let a = Int(t*SR), n = Int(0.22*SR)
    for k in 0..<n {
        let tt = Double(k)/SR
        let f = 58.0 - 16.0*min(1.0, tt/0.06)
        let env = exp(-tt/0.075) * min(1.0, tt/0.003)
        let v = sin(2 * .pi * f * tt) * env * amp
        add(a+k, v, v)
    }
}
func shaker(at t: Double, amp: Double) {
    let a = Int(t*SR), n = Int(0.045*SR)
    var hp = 0.0, prev = 0.0
    for k in 0..<n {
        let tt = Double(k)/SR
        let x = rnd()
        hp = 0.82 * (hp + x - prev); prev = x     // crude high-pass -> "tss"
        let env = exp(-tt/0.012)
        let v = hp * env * amp
        add(a+k, v*0.9, v*1.1)
    }
}
func bell(at t: Double, freq: Double, amp: Double) {
    let a = Int(t*SR), n = Int(1.8*SR)
    for k in 0..<n {
        let tt = Double(k)/SR
        let env = exp(-tt/0.75) * min(1.0, tt/0.006)
        let ph = 2 * .pi * freq * tt
        let v = (sin(ph) + 0.5*sin(2.01*ph) + 0.18*sin(3.02*ph)) * env * amp
        add(a+k, v, v)
    }
}

// ---- sustained pad (warmth under the plucks) ----
var ph = [Double](repeating: 0, count: 4)
for n in 0..<N {
    let t = Double(n)/SR, dt = 1.0/SR
    let ch = chordAt(t)
    let g = gainAt(t)
    ph[0] += 2 * .pi * ch.tones[0]/2 * dt
    ph[1] += 2 * .pi * ch.tones[1]/2 * dt
    ph[2] += 2 * .pi * (ch.tones[2]/2 + 0.10) * dt
    ph[3] += 2 * .pi * ch.bass * dt
    let pad = (sin(ph[0]) + sin(ph[1])*0.8 + sin(ph[2])*0.6) * 0.045 * layerEnv(t, from: 1.6, fade: 4)
    let sub = (sin(ph[3]) + 0.18*sin(2*ph[3])) * 0.13 * layerEnv(t, from: 1.0, fade: 3)
    let v = Float((pad + sub) * g)
    mixL[n] += v * Float(1.0 - 0.04*sin(2 * .pi * 0.06 * t))
    mixR[n] += v * Float(1.0 + 0.04*sin(2 * .pi * 0.06 * t))
}

// ---- groove ----
let ARCADE = 24.1   // the reveal: everything opens up here
let pattern = [0, 2, 1, 3, 2, 0, 3, 1]
var t = 0.0, barIdx = 0
while t < FILM {
    let ch = chordAt(t)
    let g = gainAt(t)
    // bass: root on 1 and 3 (the 3 is lighter) — motion, not a drone
    bassNote(at: t, freq: ch.bass, amp: 0.26 * layerEnv(t, from: 1.2, fade: 3) * g)
    bassNote(at: t + 2*beat, freq: ch.bass, amp: 0.15 * layerEnv(t, from: 6.0, fade: 4) * g)
    // soft kit
    kick(at: t, amp: 0.30 * layerEnv(t, from: 2.6, fade: 4) * g)
    kick(at: t + 2*beat, amp: 0.26 * layerEnv(t, from: 2.6, fade: 4) * g)
    for e in 0..<8 {
        let swing = (e % 2 == 1) ? 0.014 : 0.0     // light swing = chill, not mechanical
        let et = t + Double(e)*eighth + swing
        if et >= FILM { break }
        let ge = gainAt(et)
        // arpeggio
        let toneIdx = pattern[(barIdx*8 + e) % pattern.count]
        let arpAmp = 0.085 * layerEnv(et, from: 3.2, fade: 4) * ge
        if arpAmp > 0.0005 {
            pluck(at: et, freq: ch.tones[toneIdx], amp: arpAmp, pan: (e % 2 == 0) ? 0.5 : -0.5)
        }
        // shaker: offbeats first, all eighths once the Arcade act lands
        let dense = layerEnv(et, from: ARCADE, fade: 2.5)
        let hatAmp = (e % 2 == 1 ? 0.020 : 0.010 * dense) * layerEnv(et, from: 8.0, fade: 5) * ge
        if hatAmp > 0.0003 { shaker(at: et, amp: hatAmp) }
        // arcade octave sparkle
        if dense > 0.05 && e % 4 == 2 {
            pluck(at: et, freq: ch.tones[toneIdx] * 2, amp: 0.038 * dense * ge, decay: 0.20, pan: -0.3)
        }
    }
    // bell motif from the Arcade reveal — the "playful" voice
    let bg = layerEnv(t, from: ARCADE, fade: 2.0) * g
    if bg > 0.01 {
        bell(at: t + beat, freq: ch.tones[3], amp: 0.075 * bg)
        if barIdx % 2 == 1 { bell(at: t + 3*beat, freq: ch.tones[2], amp: 0.055 * bg) }
    }
    barIdx += 1
    t += bar
}

// ---- SFX ----
func addSwell(endAt t: Double, dur: Double = 1.8, peakDB: Double = -20) {
    let a = Int((t - dur)*SR), n = Int(dur*SR)
    let amp = pow(10.0, peakDB/20.0)
    var lp = 0.0
    for k in 0..<n {
        let u = Double(k)/Double(n)
        let fc = 150.0 + 1400.0 * u * u
        let al = 1.0 - exp(-2.0 * .pi * fc / SR)
        lp += al * (rnd() - lp)
        let v = lp * pow(u, 2.4) * amp
        add(a+k, v*0.9, v*1.1)
    }
}
func addBloom(at t: Double, peakDB: Double, dur: Double = 1.5, f0: Double = 65.41) {
    let a = Int(t*SR), n = Int(dur*SR)
    let amp = pow(10.0, peakDB/20.0)
    for k in 0..<n {
        let u = Double(k)/Double(n)
        let env = pow(sin(.pi * min(1.0, u/0.3) * 0.5), 2.0) * pow(1.0 - u, 1.5)
        let p = 2.0 * .pi * f0 * Double(k)/SR
        let v = (sin(p) + 0.32*sin(2*p)) * env * amp
        add(a+k, v, v)
    }
}
// bright playful click — a toy, not a UI beep
func addTick(at t: Double, peakDB: Double = -23) {
    let a = Int(t*SR)
    let amp = pow(10.0, peakDB/20.0)
    let n2 = Int(0.07*SR)
    for k in 0..<n2 {
        let tt = Double(k)/SR, u = Double(k)/Double(n2)
        let v = (sin(2 * .pi * 1046.5 * tt) * 0.5 + sin(2 * .pi * 523.25 * tt) * 0.7) * pow(1-u, 2.4) * amp
        add(a+k, v, v)
    }
}
for c in [20.80, 34.80] { addSwell(endAt: c); addBloom(at: c + 0.5, peakDB: -13) }
addBloom(at: 0.7, peakDB: -15)
// the Arcade reveal — the film's biggest moment
addSwell(endAt: 24.30, dur: 1.5, peakDB: -17)
addBloom(at: 24.30, peakDB: -11, dur: 2.0)
addSwell(endAt: 41.75, dur: 1.4, peakDB: -20)
addBloom(at: 41.85, peakDB: -13)
// one tick per measured interaction (film time)
for t2 in [3.15, 4.50, 5.85, 10.10, 12.35, 15.30, 17.85, 28.05, 29.40, 31.95] { addTick(at: t2) }
addBloom(at: 10.30, peakDB: -16)   // the logo lands
addBloom(at: 31.95, peakDB: -13)   // the gradient

// ---- master ----
var pk: Float = 0, pkM: Float = 0
for n in 0..<N { pk = max(pk, max(abs(mixL[n]), abs(mixR[n]))); pkM = max(pkM, abs(mixL[n]+mixR[n])) }
let target = Float(pow(10.0, -1.5/20.0))
let g2 = min(target/pk, (2*target)/pkM)
for n in 0..<N { mixL[n] *= g2; mixR[n] *= g2 }
print(String(format: "playful score: peak %.2f dB, gain %.2f dB", 20*log10(Double(pk)), 20*log10(Double(g2))))

let outURL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["OUT"] ?? "score.m4a")   // OUT env overrides; default = cwd (durable dir, never /tmp)
try? FileManager.default.removeItem(at: outURL)
let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: SR,
                               AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 320000]
// must close (deallocate) the writer before probing, or the file reads back as 0 tracks
func writeM4A() throws {
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
