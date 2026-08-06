---
name: product-film
version: 1.0.0
description: Use when making or editing a product/promo video from screen recordings of any product — a phone app, a website, a desktop app, or a Figma prototype — capturing takes, trimming/splicing scenes, compositing with camera moves and click cues (device mockup for mobile, full-bleed Screen-Studio-style for desktop), stitching scenes with transitions and title cards, adding a soundtrack, or when a cut feels laggy, ghosty, unclear, "PPT-like", or shows black margins/floating-card framing on desktop content. Also for App Store end cards and verifying edits frame-by-frame. This is the premium tier — not the tool for a quick internal release reel.
---

# product-film

AVFoundation-based film pipeline that runs **end-to-end: from raw screen recordings to the final scored, verified MP4** — capture the takes yourself if none exist (stage 2), then measure, cut, composite, stitch, score, mux, verify and audit, all from this skill's scripts alone (no ffmpeg, no editors, no external services). Battle-tested across 23 versions of the Oryne promo and 7 of the Inkwork film; the taste rules encode rejections from those real deliveries — treat them as law, not suggestions.

**This skill learns — but sort what it learns into three tiers.** (1) *Project-local style direction* (this film's vibe, palette, a one-off override) lives in the film's script and project memory — it NEVER mutates the skill. (2) A *stable user preference* is persisted only when clearly recurring or explicitly stated ("from now on…"). (3) A *globally reusable production law* — a craft ruling that transfers to any product — is encoded into these files (law, mistake row, or refined rule) before the next film; an unwritten rejection will be repeated. When an override contradicts a default, encode the GENERALIZED lesson, never the literal choice: a user insisting on cross-dissolves teaches "explicit project styling overrides transition defaults," not "cross-dissolves are the new default."

**Read `references/playbook.md` before running anything** — stage contracts, script arguments, iron laws. Scripts live in `scripts/` (plain `swift file.swift args`; macOS tools that process ANY mp4/mov — the product being filmed can be an app, a website, or a Figma prototype). Reusable utilities take required inputs as explicit argv; the stitch/score templates are copied per project with their creative contract edited in-file (env vars only for path resolution, cwd defaults). No script hardcodes machine-, project-, or /tmp paths.

**If the user's brief is vague, start from `references/writing-the-script.md`** — the six things a film script must articulate (vibe, frame, scene list with interaction+payoff+data, words, brand, sound) plus a fill-in template. No renders before the written script is approved.

**If the brief doesn't say what the film should FEEL like, ask before the first render** — offer two or three named directions with references (e.g. "calm and premium, sundown-style" vs "playful and energetic, plucky and moving"). Vibe drives tempo, cut rhythm, camera energy, card tone and the entire score; guessing it means rebuilding the score and usually the edit.

## Pipeline (order is fixed)

| # | Stage | Tool |
|---|---|---|
| 1 | Script/plot doc → **user approval gate** | markdown in the project's durable directory |
| 2 | Capture takes (app / web / Figma proto) | `sckrecord` (ScreenCaptureKit — the only approved desktop/web recorder, never `screencapture -v`); simulator: `xcrun simctl io recordVideo`. Protocol: `references/capture-protocol.md` |
| 2b | **Conform VFR → CFR at ingest** (mandatory for screen-recorder sources) | conform.swift |
| 3 | **Measure** (mandatory) | scan.swift · diffscan.swift (mobile) / diffscan2.swift (desktop) |
| 4 | Splice beats | condense.swift (hold-mode for freezes) |
| 5 | Composite + camera + click cues (mobile OR desktop path) | composite2.swift |
| 6 | Stitch scenes/cards/breaths | stitch-template.swift · cards via title-card-template.swift / end-card-template.swift (Swift preferred; Figma fallback) |
| 7 | Score (synthesized, license-free) | score-template.swift (calm) / score-playful-template.swift (energetic) |
| 8 | Mux (video passthrough) | mux.swift |
| 9 | **Verify frames** | frame strips |
| 10 | **Gap audit vs the script → deliver both** | `references/gap-audit.md` |

## Non-negotiables

- Frame-scan every take before trimming — input latency makes planned timings fiction.
- **Two presentation paths, chosen by form factor** (playbook: "Two presentation paths"). Portrait/phone content → mobile path: device mockup (or FRAMELESS card), touch-dot cursor. Landscape/desktop content (websites, desktop apps, landscape protos) → desktop path: `FILL=1` full-bleed — the page fills the canvas at every zoom level, zooms expand toward the cursor's interaction point, pans clamp to content bounds, arrow cursor + click ring, `autoplan.py --desktop` (in `scripts/`, derives the camera plan from measured tap times). Never put a desktop page in the floating card.
- Never cut onto an animation's first moving frame; splice whole transitions.
- Every feature reveal is preceded by a visible click cue (cursor → press → ripple).
- Transitions: zoom-through within acts, black breaths + brand-font title cards between acts. Cross-dissolves and side-pushes are pre-rejected.
- **Cards are generated programmatically — Swift preferred (`title-card-template.swift`, `end-card-template.swift`), Figma as fallback** — always in the FILMED product's brand font and palette (script's Brand block), never a previous project's.
- Camera moves only to show something; no idle drift/tilt.
- **User styling direction CASCADES — scoped by how it was given.** VIBE-level direction ("bouncier", "lighter", "calmer", "more premium") applies to every surface it plausibly touches — cards (type, color, motion), the edit (cut rhythm, hold lengths), visuals (camera energy, punch depth), animation (entrances, transition timing) and the score; restyling one surface to a vibe note and leaving the others is a defect. A SCOPED request naming a specific surface or element ("make the logo gold", "slow this card's entrance") applies to that surface ONLY — at most flag the consistency question ("logo is now gold — want the accents to follow?"), never auto-restyle the rest; a scoped edit that triggers an uninvited re-score or re-cut is the same defect pointing the other way. The taste laws in this skill are DEFAULTS encoding past rulings; the user's explicit direction overrides them for the current film. Engineering gates — measure before trimming, whole-animation splices, frame verification, gap audit, no watermarked audio — are not style and never bend.
- Sound: synthesized to the stated vibe, never a default. Two proven recipes in `scripts/`: calm/premium (`score-template.swift` — 54BPM, G major, sub-heavy) and playful/energetic (`score-playful-template.swift` — 96BPM, C major I-V-vi-IV, plucked arpeggios + soft kit, energy lifting at the reveal). Both duck deeply under title cards. Downloaded stock MP3s are ad-watermarked previews — never ship.
- **Audit every generation against the script and deliver the audit with the film** (`references/gap-audit.md`). Frame verification proves the render is sound; it says nothing about whether the film delivered what was promised. Grade each scene MET / PARTIAL / CONTRADICTED / MISSING / DEVIATES from an extracted frame, never from your build plan; split findings into editing gaps (fix now) vs capture gaps (say so plainly). No hedging words. **An act card announcing a beat that doesn't exist is a defect — cut the promise.**
- Verify every render by extracted frames before sending — and **read each title/end card at full resolution against the script's exact words** (contact-sheet type is too small to read, so wrong copy passes every other check). Applies especially to cards inherited from a previous version or another agent, and to their colors/font: they must be the filmed product's brand, not the last project's.

## Common mistakes

| Symptom | Cause → fix |
|---|---|
| "Laggy" page turn | Splice landed mid-animation → one unbroken segment through the turn |
| Scene shows 2 pages of 4 | Trimmed by intended timing → diffscan for real transitions |
| Ghost/exposure during transition | Dissolve grammar → use Z zoom-through |
| Export "Operation Stopped" | Instruction tiling gap → snap last instruction to comp.duration |
| Freeze-frame export FAIL | scaleTimeRange slow-down → condense hold mode (rate<0.5) |
| Dim first seconds of a recovered clip | Baked dissolve from source film → use raw take |
| Text stacks overlap in Figma cards | Cloned text keeps fixed box → textAutoResize HEIGHT |
| Black margin slides into frame while zoomed on a desktop page | Card/fit grammar on landscape content → desktop path (`FILL=1`, clamped pans) |
| Card corner or shadow visible inside a punched desktop shot | Same → `FILL=1` full-bleed, no card |
| Cursor/click invisible on a light desktop page | Touch-dot cursor on desktop content → arrow cursor + dark-disc/white-ring click (`CURSOR_STYLE=arrow`) |
| Two cursors on screen | Capture already contained a pointer → `CURSOR_STYLE=none` (rings only) |
| Black bar down one edge of a desktop shot at every zoom | Capture caught scrollbar/window chrome → measure the strip and `CROP=l,t,r,b` |
| diffscan reports almost no transitions on desktop footage | Portrait-grid tool on 16:9 → `diffscan2.swift` |
| Scene shows the wrong app state entirely | Trusted a filename → extract a frame from every source before cutting (playbook law 11b) |
| Card copy belongs to a different product | Card reused across projects, never read at full res → diff every card against the script's Words block (law 13) |
| Zoomed desktop shot crops UI mid-element while black shows opposite | Unclamped point-targeted punch → FILL clamp + frame the region (control + payoff) |
| "The zoom focuses on the wrong thing" | Punches centred between control and payoff → two-beat rule with local/remote payoff split (playbook) |
| Camera films the cursor while the product changes elsewhere | Remote instant payoff + "hold through the click" → two-subject frame, or be ON the payoff at the click |
| "Too fast, can't see what changed / the outcome" | No outcome hold → ≥2s readable hold at final state; extend into the take's static tail or condense-hold |
| A theme/mode switch lands but the trigger is never seen | Camera sat wide through the click → punch to the trigger, pull out on the change |
| A scene holds on something that didn't visibly change | Assumed payoff → pull a frame at the payoff moment and confirm what's readable |
| Portrait asset in a landscape film padded with glow/blur fill | Aspect mismatch patched in the edit → rebuild the card natively at the canvas size |
| End-card logo renders as a solid white box | Logo PNG is ink on OPAQUE white despite reporting hasAlpha → key on inverted luminance (end-card-template does this automatically) |
| Splice output has non-monotonic/negative timestamps, or a retime keeps the capture's stalls | VFR source edited directly — ScreenCaptureKit emits frames only on change, so a hold chunk can contain zero frames. `conform.swift` the take to CFR 60 at ingest, before measuring or cutting |
| Rendered score probes as 0.00s / 0 tracks | AVAudioFile writer still in scope → wrap writing in a func so it closes before probing |
| "Laggy" / "stutters" on a cut a splice-check didn't catch | Pixel-diff consecutive frames across the complaint window before assuming it's an edit mistake. Identical frames for 1s+ = a real capture-time stall (legacy `screencapture -v` footage choking on a heavy repaint — the tool is banned for new takes; re-shoot with `sckrecord` when possible, trim + retime only when the take can't be redone). Genuine motion every frame = something else (check splice boundaries per the laggy-page-turn row) |
| "Still laggy" after a stall fix, or lag with no single obvious freeze | Don't stop at the one freeze you found — measure the WHOLE take's frame timing (`AVAssetReader` sample PTS gaps: count, median, gaps>0.1s, total dead time) before re-editing. One clean fix reads as solved if you only checked its own window; a systemically low/uneven capture fps needs a re-shoot under better conditions or an honest scope call, not another round of trims — excising many scattered stalls trades stutter for a fragment-built scene, a materially different edit than approved |
| Low fps whenever the page animates, on every take | Two layered causes, diagnose in order: (1) `screencapture -v` itself — its writer stalls 1–3s under any load; capture with `scripts/sckrecord` (ScreenCaptureKit) instead, never screencapture. (2) If SCK captures are still thin during motion windows, the SCREEN is painting below 60fps — check `ps -Ao pcpu,comm -r`: a pegged WindowServer (iOS Simulator running, multiple Electron apps) starves the page's own rendering; no recorder fixes that — close the heavy apps and re-roll. Distinguish via frame DENSITY inside motion windows, not overall avg (SCK is VFR: static-hold gaps are normal) |
| A camera framing "isn't focused" but the position math checks out | Before assuming a compositor bug, print the actual computed device position/verify with a static (non-animated) isolation render — if the coordinates are right, the bug is usually the FRAMING CHOICE (zoom too shallow for a wide element, cropping its own edges) not the math. Re-aim tighter on where the actual subject (e.g. typed text) appears, not the whole containing row |
| A native browser/OS dialog (translate prompt, permission sheet) baked into the only footage of an action | Root-caused as capture, not edit, the moment its visible window overlaps the action you need — no trim can dodge overlapping footage. Disable at the source before re-shooting (e.g. Chrome: `chrome.settingsPrivate.setPref('translate.enabled', false)`, verify with `getPref`) rather than hoping it won't recur |
| Click ring lands on the preview/readout while the product was clicked elsewhere | CUES targets taken from diffscan2 change-centroids (where pixels REDREW) → measure fx/fy from the control's own geometry on a still (grid overlay or DOM box); centroids feed camera framing only |
| Cursor appears to click one more thing after the last scripted interaction | Interpolation continued past the final cue, overshooting onto a neighbor control → last cue HOLDS until clip end; silent `click=0` waypoints only for drag ends and instant slider jumps |
| A script adopted from another agent/project/branch ships a visibly wrong render (flipped, offset, mispositioned) | Verified by compile + diff instead of by render — these scripts encode coordinate-space assumptions invisible in source (a y-down path in a y-up layer tree shipped an upside-down cursor). Render one clip through the changed path, extract the frame, LOOK at it, before committing (playbook law 15) |
| Two versions "render identically" when they shouldn't | The repo was checked out on the other branch — the comparison diffed one version against itself. Confirm the inputs actually differ (`git rev-parse`, `shasum` the binaries) and pull files by ref (`git show <ref>:<path>`), not from the working tree (law 15b) |
| "Camera isn't following the cursor" / feels static while the cursor moves | A multi-cue hold's plan used the SAME fx/fy at both bounding keyframes (one wide-enough-to-contain-both frame held frozen across the whole span) while CUES glides the cursor continuously between them → add a keyframe AT each cue's arrival time that nudges the center toward that cue's own target, same scale (playbook: "follow-pan means a keyframe at each cue"). Verify by extracting a frame at each cue time and confirming the crop differs — don't trust that the plan "looks like" a pan |
| A camera "punch" barely moves the frame despite a real scale increase in the plan | FILL's edge clamp pulled the requested off-center `fx`/`fy` back toward the content's actual bounds — a modest scale increase near an edge target can clamp to nearly the same crop as wide. Isolate the clip OUTSIDE the stitch and scan start-to-end to confirm the crop actually changes between keyframes; don't trust the plan numbers alone. Fix with a stronger scale and/or an `fx`/`fy` further from the clamped edge |
| A capture recorded the wrong window/app content despite the driver reporting correct DOM state | CDP/JS assertions prove the automation ran, not what the screen capture shows — another window can sit on top of the capture region. Take a passive `screencapture -R` still of the exact rect and look at it immediately before EVERY take (not once per session); force the intended Chrome process frontmost by PID, not the ambiguous `tell application "Google Chrome" to activate` (unresolvable with multiple Chrome processes sharing one bundle ID) |
| Real OS cursor in one act, synthetic arrow in another | Recapture broke the film's pointer contract → one contract per film, chosen before roll 1; after ANY recapture, extract a click frame from EVERY scene (same arrow, same ring, same size), not just the act you re-shot |
