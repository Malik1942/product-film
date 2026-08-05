# product-film

**A Claude Code agent skill that turns screen recordings into scored, verified product films.**

Point Claude at raw screen recordings of your product — an iOS app, a website, a desktop app, or a Figma prototype — and this skill gives it the full production pipeline: measuring real interaction times, splicing beats, compositing into a device mockup (mobile) or Screen-Studio-style full-bleed (desktop) with camera moves and click cues, stitching acts with title cards, synthesizing a license-free soundtrack, and auditing the final cut scene-by-scene against the approved script.

Built on AVFoundation only. No ffmpeg, no video editor, no cloud rendering — every stage is a plain Swift script.

| Mobile path | Programmatic cards |
|---|---|
| ![mobile](docs/example-mobile.png) | ![card](docs/example-card.png) |

## Why it exists

Agent-cut product films usually fail the same ways: trims made from *intended* timings instead of measured ones, cuts landing mid-animation, reveals with no visible click, zooms focused on the wrong thing, watermarked stock audio, and cards carrying last project's copy. Every rule in this skill is a codified rejection from real film deliveries — the playbook is the accumulated taste, and the pipeline's verification gates (frame-scan before trimming, full-res card reads, a mandatory gap audit delivered with every render) are what keep quality stable across sessions.

## Requirements

- macOS with Xcode Command Line Tools (`swift` on PATH)
- [Claude Code](https://claude.com/claude-code)
- For iOS Simulator capture: Xcode (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`)

## Install

**curl:**

```bash
curl -fsSL https://raw.githubusercontent.com/Malik1942/product-film/main/install.sh | bash
```

**git:**

```bash
git clone https://github.com/Malik1942/product-film.git ~/.claude/skills/product-film
```

**gh:**

```bash
gh repo clone Malik1942/product-film ~/.claude/skills/product-film
```

Installing to `~/.claude/skills/` makes the skill available in every project; use `<repo>/.claude/skills/product-film` instead to scope it to one repo. Claude Code discovers it automatically — no registration step.

## How to prompt

The skill triggers on any product/promo-video work. Natural prompts:

```text
Make a 60-second promo film for my app. Raw recordings are in ~/Desktop/MyAppTakes.
```

```text
Film my website at example.com into a Screen-Studio-style demo — desktop grammar, arrow cursor.
```

```text
The page turn in scene 2 feels laggy and the zoom focuses on the wrong thing. Fix both.
```

Style direction works at two levels, and the skill knows the difference:

- **Vibe-level** — cascades to everything (edit rhythm, camera energy, cards, score):
  `"Make it calm and premium, like a sundown ambient track."` / `"Playful and energetic."`
- **Scoped** — touches only what you named:
  `"Make the logo gold on the end card."` / `"Slow the title card entrance."`

Two things to expect from the workflow:

1. **It will ask for a script before rendering.** Films are built from a six-block script (vibe, frame, scene list with interaction + payoff + data, words, brand, sound). If your brief is vague, Claude hands you a fill-in template first — that's by design; the approval gate is what prevents expensive wrong-direction renders.
2. **Every delivery includes a gap audit.** Each scene of the actual rendered file is graded against the script (MET / PARTIAL / CONTRADICTED / MISSING / DEVIATES) from extracted frames, with editing gaps fixed before delivery and capture gaps named plainly.

## What's inside

| Path | What |
|---|---|
| `SKILL.md` | Triggers, pipeline order, non-negotiables, symptom→fix table |
| `references/playbook.md` | Stage contracts, script arguments, camera grammar, iron laws |
| `references/writing-the-script.md` | The six-block film-script contract + fill-in template |
| `references/gap-audit.md` | The mandatory per-render audit format |
| `scripts/` | The pipeline: scan, diffscan/diffscan2, condense, composite2, stitch, score ×2, mux, title/end cards |
| `assets/iphone-mockup.png` | Neutral device frame (generated, MIT-licensed) |

Scripts come in two classes: **utilities** run as-is with explicit argv (`swift scripts/mux.swift film.mp4 score.m4a out.mp4`), **templates** (stitch, score) are copied into your project and edited in-file — the clip order and chord tables *are* the interface. No script contains machine-specific or `/tmp` paths.

## Device frames

The bundled frame is a clean generated bezel (safe to redistribute). For a photorealistic device, drop in any bezel image with a transparent screen cutout — e.g. Apple's official product bezels from [Apple Design Resources](https://developer.apple.com/design/resources/) (check Apple's usage terms):

```bash
FRAME_PNG=/path/to/bezel.png SCREEN_RECT=x,y,w,h swift scripts/composite2.swift ...
```

## Companion skill

Capture (simulator staging, take protocol, auto-zoom derivation) lives in a separate `screen-recording` skill in the author's setup. This repo stands alone for editing/compositing/scoring — record takes with whatever you have (`xcrun simctl io recordVideo`, `screencapture -v`), then measure with `diffscan` and cut from measured times.

## License

MIT — see [LICENSE](LICENSE). Brand fonts are never bundled; supply yours per project via `FONT_FILE`.
