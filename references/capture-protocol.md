# Screen-Recording Capture Protocol

Records product footage from a user-provided script/shot list — **native apps (iOS Simulator), websites, or Figma prototypes** — then derives auto-zoom camera plans and cursor navigation from measured interaction times. Compositing tools live beside this file in `scripts/` — this stage produces their inputs.

The script the user provides must pin down, per scene: the start state, the interaction to show, the payoff to read, and the data that must exist (`writing-the-script.md` beside this file has the full six-block template). If it doesn't, get that first.

## 0. Pick the capture surface

| Surface | Drive with | Record with | Composite as |
|---|---|---|---|
| Native iOS app | simctl + simulator taps | `simctl io recordVideo` | device mockup (mobile path) |
| Desktop website / desktop app | CDP against an isolated Chrome instance (`--app` window, own `--user-data-dir`, locked `--remote-debugging-port`) — or your agent's browser automation | `sckrecord` (ScreenCaptureKit) region capture of the inner viewport | `FILL=1` full-bleed (desktop path) |
| Figma prototype | open the `figma.com/proto/...` link in the driven browser; drive hotspots as normal clicks | same `sckrecord` route | phone-shaped proto → device frame or `FRAMELESS=1` card (mobile path); landscape proto → `FILL=1` (desktop path) |

**Drive without moving the OS pointer.** CDP `.click()`/value-sets/key events never move the macOS cursor — that is what makes the synthetic-pointer composite path clean. Park the real pointer OUTSIDE the recorded region before rolling and leave it there. AppleScript / System Events UI scripting dies unpredictably on TCC permission resets (one silent mid-session flip cost a full take) — if you must use it, make the driver FAIL LOUDLY: never pipe its stderr to /dev/null, grep for "execution error"/"turned off", kill the recorder and abort the take on any driver failure, and assert the page state before rolling and after each state-changing click.

**One pointer contract per film.** Decide at roll time — synthetic (recorder hides the cursor, compositor draws the arrow) or real (cursor baked in, composite `CURSOR_STYLE=none`) — and honor it in EVERY take and every recapture. A film with a real OS cursor in one act and a synthetic arrow in another is the same defect class as two pointers in one frame.

**Same stage for every act.** Same browser window, same region, same scale, same parked pointer, same recorder — for the whole film, including recaptures. Re-shooting only the broken act on a different stage is how cursor grammar, resolution, and framing silently split across acts.

**A driver's JS-state assertion proves the automation ran — it proves nothing about what the SCREEN CAPTURE shows.** A real incident: CDP evaluate calls correctly confirmed the target page's DOM state at every step, but the recorded pixels showed a completely different window (the operator's own open work) because that window sat on top of the capture region on screen. Multiple Chrome processes share one bundle ID, so `tell application "Google Chrome" to activate` is ambiguous — it can raise the WRONG instance. Fix: target the specific process by PID (`first process whose unix id is <pid>`) when forcing frontmost, and take a passive `screencapture -R` still of the EXACT capture rect and actually look at it — immediately before every take, not once per session, since another window can re-cover the region between setup and roll. A DOM check and a pixel check are not substitutes for each other.

**A profile directory being "yours" doesn't make it isolated.** Reusing a project's `--user-data-dir` across sessions can carry real saved tabs/state from whoever drove it last (a prior agent, or the user's own browsing) — launching against it can surface that content on screen, including in a recording. Use a genuinely fresh, empty `--user-data-dir` per capture session and verify with a pre-roll still, never assume "isolated" from the flag alone.

**The path fork is decided by form factor:** portrait/phone content → mobile path; landscape/desktop content → desktop path. The desktop path's composite cover-crops the capture to fill the canvas, so **desktop captures MUST match the canvas aspect** (16:9 for 2560×1440): size the browser window so the recorded viewport region is exactly 16:9 (e.g. 2560×1440 or 2048×1152 pixels) and tighten `-R` to the viewport, excluding ALL browser chrome. A tall or odd-aspect capture forces the cover-crop to eat UI at the edges. Verify the region with a single `screencapture -R` still before rolling.

**Website / Figma-proto recording mechanics:**
```bash
# window bounds of the target app/window (points; multiply by backingScaleFactor for pixels)
osascript -e 'tell application "System Events" to get {position, size} of front window of (first process whose frontmost is true)'
# region recording — ScreenCaptureKit recorder (scripts/sckrecord.swift; compile once with swiftc -O)
swiftc -O scripts/sckrecord.swift -o sckrecord
./sckrecord <x> <y> <w> <h> ~/Desktop/<proj>/takeN.mov & echo $! > /tmp/rec.pid   # optional 6th arg: scale (default 2)
# SIGINT to stop — it finalizes the file and prints the frame count
```
- **sckrecord production rules** (each earned by a bad take): it picks the display that *contains* the rect, not `displays.first`; output scale is forced (default **2x** — `SCDisplay.width` often reports logical 1x even on Retina, which would silently halve a 2560-wide canvas to 1280); `showsCursor=false` because the compositor draws the synthetic arrow — with a real-pointer contract, flip it in source and composite `CURSOR_STYLE=none`; overlay/agent windows (IDEs, chat apps, screen-tools) are excluded from the filter, otherwise they composite into the take even when they sit "outside" the rect. Region = the INNER viewport only, no browser chrome — and size the window so the viewport is canvas-aspect (1280×720 pt @2x → 2560×1440); a near-miss like 1280×748 cover-fills, but anything below the crop line is gone forever.
- **NEVER capture film footage with `screencapture -v`.** It is a convenience CLI whose writer stalls for 1–3s at a time under any CPU load, unrelated to what's on screen (measured: 18.5s of dead frames in a 33.5s take at load 8, including 1.2fps through an animation, while the same machine at load 14 captured cleanly via ScreenCaptureKit — 0.23s total dead). `sckrecord` uses SCStream + AVAssetWriter (the OBS/QuickTime path) at min-frame-interval 60fps. Note it emits frames only when pixels change (VFR) — PTS gaps during static holds are normal and harmless; judge health by frame density inside MOTION windows.
- **Pre-roll health check (mandatory for film takes):** `scripts/rollgate.sh <x> <y> <w> <h>` runs the whole gate numerically — WindowServer CPU < 20%, 1-min load < 4, and a 5s wiggle-test capture (cursor warped across the region via `mousebin`, recorded with `SHOWCURSOR=1`) whose median motion frame gap must be ≤ 1/55s. Exit 0 = safe to roll; exit 1 = blocked — report the failing number, do NOT roll. Manually that means: record a 5s test while wiggling/animating something in the region, then verify PTS gaps AND check `uptime` + `ps -Ao pcpu,comm -r | head`. Pass bar: median gap ≈1/60s and **zero gaps >80ms through the motion window**. Judge by frame density INSIDE motion (SCK is VFR — static-hold gaps are normal and harmless). If WindowServer is pegged (running iOS Simulator, multiple Electron apps/browsers), the SCREEN ITSELF paints below 60fps and no recorder can fix it — the page's own animations render choppy live. Close the heavy apps (ask the user) and **re-roll; never "fix it in the edit"** — a capture of a starved WindowServer is a bad take no trim can save.
- Screen Recording permission (System Settings → Privacy) is required — a black/failing capture is the sign the host terminal lacks it.
- **Resolution maths (verify BEFORE rolling):** `screencapture -R` takes POINTS; native pixels = points × `devicePixelRatio`. On a 2x HiDPI display a 1280×720-point viewport captures at exactly 2560×1440 — zero scaling, zero crop. This REQUIRES the display in HiDPI mode; if it drops to 1x (dpr 1) true 2560×1440 capture is impossible. Check `system_profiler SPDisplaysDataType` and the page's `devicePixelRatio` first. Verify the region by injecting a full-viewport solid-colour overlay and locating its largest solid run in a still — the raw bbox alone is inflated by stray same-colour pixels.
- Crop browser chrome either by tightening the region to the viewport or later via composite trim (`cropTop`).
- **The viewport must contain every scripted payoff.** If the script promises a word, pill, or readout ("Scannable"), it has to be inside the recorded rect — a payoff below the fold is a capture gap no edit can close (measured: a 1280×748 window cropped the proof pill out of three consecutive scenes). Before calling the stage ready, dry-run the flow to its END state, take a still, and check that every word the script promises is readable in-frame; resize the window or plan a scroll if not.
- **Decide the pointer question before roll 1 — it's the film-global contract (§0).** Synthetic path: `sckrecord` hides the cursor (`showsCursor=false`), OS pointer parked off-rect, compositor draws the arrow. Real path: flip `showsCursor` in source, and composite with `CURSOR_STYLE=none` so only click rings are added (some sites also draw their own custom cursor — check a frame). Two pointers on screen, or a contract that flips between acts, is an instant reject.
- Figma prototypes: set the proto to "Fit" scaling, wait for the flow's first frame to fully load before rolling, and note that hotspot hints flash on stray clicks — a stray flash contaminates the take (discard, re-roll).

Set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` for all simctl calls (works without full xcode-select).

## 1. Parse the script into a shot list

For each scene extract: start screen, ordered actions (tap/swipe/type + target), required end state, and which moments the viewer must *read* (those get zoom holds). If any scene needs data that doesn't exist in the app (populated lists, images, links, old timestamps), seed it FIRST — through the real UI when possible, sqlite3 store surgery when not.

## 2. Stage the surface (all of it, before the first take)

**Websites:** clean profile state — dismiss cookie/consent banners off-camera, log in beforehand, kill toasts/onboarding tooltips, set viewport to the script's aspect (resize_window), disable animations-reducing OS settings if they fight the footage. **Figma protos:** presentation mode, correct starting frame, "Fit" zoom.

**Simulator:**

```bash
U=<udid>
xcrun simctl boot $U
xcrun simctl spawn $U defaults write .GlobalPreferences AppleLanguages -array "en-US"
xcrun simctl spawn $U defaults write .GlobalPreferences AppleLocale "en_US"
xcrun simctl shutdown $U && xcrun simctl boot $U          # locale needs reboot
xcrun simctl status_bar $U override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl privacy $U grant all <bundle-id>             # KILLS a running app — do before launch
```
Then launch the app once and burn through every one-time surprise OFF-camera: mic/speech permission dialogs, rating prompts, first-run sheets. Only then record.

## 3. Take protocol (per scene)

1. **Dry-run the flow once** without recording: screenshot each screen, note tap targets in points (screenshot px ÷ scale; e.g. 1206-wide capture on a 402pt device → ÷3... use the image's stated multiplier). A cheap dry run beats a garbage take.
2. Navigate to the scene's start state. Relaunching resets tabs/segments — re-verify with a screenshot; don't assume.
3. Roll detached, into a DURABLE directory (never /tmp — it gets wiped):
   ```bash
   nohup xcrun simctl io $U recordVideo --codec h264 --force ~/Desktop/<proj>/takeN.mp4 > /tmp/rec.log 2>&1 &
   echo $! > /tmp/rec.pid
   ```
4. Drive the actions with deliberate pacing (1.5–3s holds where the viewer must read). Text fields: tap to focus, screenshot to confirm the cursor, then type — typing into an unfocused field silently no-ops. Never type HTML entities.
5. Stop with `kill -INT $(cat /tmp/rec.pid)`; wait 2s for finalize; check the file is >0 bytes.
6. **Verify the end frame** with a screenshot before moving on. A take is not done until its last frame is confirmed.

If ANY dialog/toast appears mid-take: stop, discard, dismiss/fix the cause, re-roll. Contaminated takes are never salvaged in the edit.

## 4. Measure the take

Run `scripts/diffscan.swift` (mobile) or **`diffscan2.swift` (desktop — aspect-correct, and it reports the centroid of each change so you get the responding region as fx/fy)** on the take → real screen-change windows. Tap-injection latency through any driving tool is unpredictable (a planned 15s take can run 60s with 13s holds); planned timings are fiction. The transitions plus your action order give each interaction's true time T and target (fx, fy = fraction of screen width/height from top-left).

## 5. Auto-zoom + cursor derivation

Rule (encoded in `scripts/autoplan.py`): for each interaction at time T targeting (fx, fy):

- **Camera (mobile)**: wide (scale 1.02) until T−1.2 → punch to (fx, fy, scale 1.35–1.5) arriving T−0.3 → hold through the response until the next beat → move to next target or return wide. Camera moves ONLY around interactions and readable payoffs; no idle drift.
- **Camera (desktop, `--desktop` → FILL=1)**: wide = exactly 1.0 (the page cover-fills the canvas, edge-flush); punches are deeper (1.5–1.8, up to 2.2 for small controls) and always expand toward the cursor's interaction point; consecutive targets < ~0.35 apart get a constant-zoom follow-pan instead of a wide return (Screen Studio grammar). The composite clamps every move to content bounds — the page fills the canvas in every frame, so corner targets are safe to request.
- **Cursor**: fade in before the first target, eased glide (composite2 `GLIDE`, default 1.05s), tip settling at T−`ARRIVE` (default 0.18), press-dip, ring peaking at T−`RIPPLE` (default 0.0 — AT the response; instant CDP-driven changes must not land before the ring reads as their cause). **The ring must read as the cause of the transition, never after it starts.** Mobile = touch dot; desktop = arrow + click ring (automatic under FILL=1).

```bash
python3 scripts/autoplan.py taps.json             # mobile: device-mockup camera grammar
python3 scripts/autoplan.py taps.json --desktop   # desktop: FILL=1 full-bleed grammar
# taps.json: [{"t": 12.6, "fx": 0.27, "fy": 0.80}, ...]
# → prints the composite2.swift invocation (camera plan string + cursor/tap args)
```
Feed the output to `scripts/composite2.swift` (with the trim you chose from diffscan). For a scene with several clicks, pass them all as `CUES="t fx fy; ..."` — one persistent cursor glides between every target, which is what a real pointer does; a drag is its handle-start cue plus a `click=0` waypoint at the end position.

## 6. Failure modes (each cost a real retake)

| Symptom | Cause |
|---|---|
| Take shows a permission dialog / "Enjoying app?" prompt | Staging skipped; one-time surprises not burned off-camera |
| Typed text never appears | Field wasn't focused (no cursor) — or text was sent to the wrong booted device (pass udid explicitly) |
| Take is 0 bytes | recordVideo finalize needs SIGINT + a sandbox-writable path |
| Take 4× longer than planned | Tap latency — harmless IF you measure; fatal if you trim by plan |
| UI in wrong language | Locale set without reboot, or fresh install re-seeded demo data |
| App on wrong tab/segment after relaunch | Launch state resets — verify with screenshot before rolling |
| Ripple/zoom lands on the wrong screen | Cue timed after the transition started — cues complete BEFORE T |
| Desktop film shows black margins / floating card / UI eaten at edges | Capture wasn't canvas-aspect, or mobile card grammar used on landscape content — 16:9 viewport region + `FILL=1` + `autoplan.py --desktop` |
| A scripted payoff (status pill, label) is never on camera in any frame | Viewport didn't contain it — dry-run still of the END state before rolling; taller window or planned scroll, not an edit fix |
| Take is full-length but nothing happens on screen | Driver died silently (TCC / "Allow JavaScript from Apple Events" flipped off) with stderr discarded — fail-loud drivers: surface driver errors, kill the recorder, abort the take; assert page state pre-roll and post-click |
| Capture comes out at half the expected resolution | Trusted `SCDisplay.width` (logical 1x) — force the output scale (sckrecord's scale arg, default 2) |
| An IDE/chat window ghosts into the footage | Overlay window composited by the capture despite sitting "outside" the rect — exclude those windows in the content filter (sckrecord does) |
| Cursor grammar differs between acts (real pointer in one, arrow in another) | Recaptured one act on a different stage/contract — one pointer contract + same stage (window, region, scale, recorder) for every take AND every recapture |
