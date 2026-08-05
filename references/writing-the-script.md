# Writing the Film Script — what the user must articulate

The pipeline can only film what the script pins down. Before any capture, get (or help the user write) a script covering the six blocks below, then hold the **approval gate**: no renders until the user signs off on the written script. When the user's request is missing a block, ask for that block specifically — don't guess taste.

**If the brief does not state the film's vibe, ask before the first render.** Vibe is not a detail you can infer from the product: the same app supports a calm/premium cut and a playful/energetic one, and it decides tempo, cut rhythm, camera energy, card tone, and the entire score. Getting it wrong means rebuilding the score and often the edit. Ask it as a short concrete question — offer two or three named directions with a reference each ("calm and premium, like a sundown ambient bed" vs "playful and energetic, plucky and moving") rather than asking "what vibe do you want?".

## The six blocks

### 0. Vibe & energy
- **Feeling in 2–4 words**: calm/premium, playful/chill, punchy/technical, warm/human.
- **Reference**: a track, a film, or another product video whose feel it should share.
- **Energy curve**: steady throughout, or building to one reveal? Name the moment that should feel biggest.
- **Avoid-list**: what would make it wrong ("not depressing", "not corporate", "not childish").

### 1. Frame
- **Product & surface**: native app (which simulator/device), website (URL, viewport), or Figma prototype (proto link, flow start).
- **Form factor → presentation path** (decided here, once): portrait/phone content → **mobile path** (device mockup, touch cursor); landscape/desktop content → **desktop path** (full-bleed — the page fills the canvas at every zoom, arrow cursor, Screen-Studio-style zooms toward the cursor). A desktop page in a floating card is a pre-rejected grammar.
- **Audience & placement**: App Store preview / landing page / social — sets aspect, length ceiling, and how loud the branding is.
- **Canvas + length target**: e.g. 2560×1440 landscape, 60–90s. State both.

### 2. Scene list (the core — one row per scene)
For each scene demand these fields; a scene missing any of them will come back for rework:

| Field | Why it exists |
|---|---|
| Feature name / one-sentence idea | A scene proves ONE thing |
| Start state | Which screen, what's already on it |
| The interaction to show | The click/scroll/type the viewer must SEE — the click is the demo |
| The payoff to read | What appears, and which detail proves the feature (a timestamp, a count, a list) |
| Data requirements | What must exist in the product first — a "gathering" needs 3+ real items; empty states and placeholder text kill scenes |
| ~seconds | Rough is fine; readable beats get ≥2s |

### 3. Words
Opening tagline, act/section title-card texts, end-card line and CTA. Written by the user or explicitly delegated ("you draft, I approve").

### 4. Brand
Font (exact family for cards), light/dark, presentation per the Frame block's path (mobile: which device frame / frameless card; desktop: always full-bleed), logo/icon assets, App Store badge asset if used. Card styling (background/text colors, entrance speed and travel) derives from Vibe + Brand and maps directly onto the card templates' style env knobs. Vibe-level styling stated here or as later critique cascades to cards, edit, camera, animation AND score together; a request scoped to one surface or element stays on that surface (flag the consistency question, don't auto-restyle the rest).

### 5. Sound
Mood reference (a track name or "like X's videos"), tempo feel (calm/driving), and whether licensed music exists — otherwise the score is synthesized and the user should say what to avoid (e.g. "not depressing", "not art-installation ambient").

## Template (give this to the user to fill)

```
FILM: <name>   SURFACE: <app/web/figma-proto + where>   PLACEMENT: <where it runs>
CANVAS: <WxH>  TARGET LENGTH: <s>
VIBE: <2-4 words> — like <reference>; biggest moment: <which beat>; avoid: <list>

OPENING: <tagline text / "brand lockup only" / skip>
SCENES:
1. <feature> — idea: <one sentence>
   start: <screen/state>  interaction: <what the viewer watches happen>
   payoff: <what appears + the readable proof>  data needed: <content that must exist>  ~<s>
2. ...
TITLE CARDS: <between which scenes, exact words>
END CARD: <text + CTA + badge?>
BRAND: font <name>, <dark/light>, path <mobile: device mockup or frameless card / desktop: full-bleed>
SOUND: <reference + mood + avoid-list>
```

## Worked example (compressed from a real film)

```
FILM: Oryne promo  SURFACE: iOS app, iPhone 17 Pro sim  PLACEMENT: landing page
CANVAS: 2560x1440  TARGET LENGTH: ~80s
VIBE: calm, premium, unhurried — like "Out of Flux – sundown"; biggest moment: the Ask payoff; avoid: busy percussion, depressing drones
OPENING: "CATCH INSPIRATION BEFORE IT DRIFTS"
SCENES:
1. Fast Capture — idea: one press catches a thought anywhere
   start: home screen  interaction: Action Button press (visible cue) -> capture sheet
   payoff: live waveform + real transcription appearing  data: none  ~8s
2. The Ocean gathers — idea: related thoughts cluster on their own
   start: Ocean field  interaction: cursor taps a cluster orb
   payoff: sheet reading "8 thoughts drift here" + 4 titles visible  data: 8 real fragments in one current  ~8s
TITLE CARDS: before 1 "FAST CAPTURE", before 2 "THE OCEAN GATHERS"
END CARD: "NOW ON THE APP STORE" + badge
BRAND: Bitcount Grid Single, dark, iPhone mockup frame
SOUND: like "Out of Flux – sundown": ~54BPM, sub-heavy, calm; avoid: ads/watermarked files, "depressing", busy percussion
```

## Red flags in a submitted script (push back before filming)
- No stated vibe → ask, with two or three named directions. Never pick one silently and score to it.
- "Show the app" with no per-scene interactions → ask for the click per scene.
- Payoffs with no readable proof ("it organizes things") → ask what exact text/number the camera should hold on.
- Scenes requiring data nobody seeded → schedule seeding before takes.
- More than one idea per scene → split it.
- No length target or placement → durations and pacing can't be chosen.
