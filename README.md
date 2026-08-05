# product-film

**An agent skill that turns screen recordings into scored, verified product films.** It's a plain `SKILL.md` skill plus Swift scripts with nothing agent-specific inside, so it runs on any agent that reads the format — Codex, Cursor and Claude Code today.

Point your coding agent at raw screen recordings of your product — an iOS app, a website, a desktop app, or a Figma prototype — and this skill gives it the full production pipeline: measuring real interaction times, splicing beats, compositing into a device mockup (mobile) or Screen-Studio-style full-bleed (desktop) with camera moves and click cues, stitching acts with title cards, synthesizing a license-free soundtrack, and auditing the final cut scene-by-scene against the approved script.

Built on AVFoundation only. No ffmpeg, no video editor, no cloud rendering — every stage is a plain Swift script.

| Mobile path — from the Oryne launch film | Brand-font title card — same film |
|---|---|
| ![mobile](docs/example-mobile.png) | ![card](docs/example-card.png) |

![desktop](docs/example-desktop.png)
*Desktop path — frame from the [Inkwork](https://malikzhang.com/inkwork) film: a real website shot full-bleed Screen-Studio style, arrow cursor with click rings, zooms clamped so the page fills every frame. The same grammar covers desktop apps and landscape Figma prototypes.*

Every frame above is unretouched output of this pipeline, taken from two shipped films.

## Why it exists

Agent-cut product films usually fail the same ways: trims made from *intended* timings instead of measured ones, cuts landing mid-animation, reveals with no visible click, zooms focused on the wrong thing, watermarked stock audio, and cards carrying last project's copy. Every rule in this skill is a codified rejection from real film deliveries — the playbook is the accumulated taste, and the pipeline's verification gates (frame-scan before trimming, full-res card reads, a mandatory gap audit delivered with every render) are what keep quality stable across sessions.

## Requirements

- macOS with Xcode Command Line Tools (`swift` on PATH)
- Any agent that reads `SKILL.md` skills — e.g. [Codex](https://developers.openai.com/codex), [Cursor](https://cursor.com), [Claude Code](https://claude.com/claude-code)
- For iOS Simulator capture: Xcode (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`)

## Install

**curl** — installs for every supported agent (one real copy, the rest symlinked to it):

```bash
curl -fsSL https://raw.githubusercontent.com/Malik1942/product-film/main/install.sh | bash
```

Narrow it to the agents you use, or scope it to a single repo:

```bash
./install.sh --codex --cursor
```

```bash
./install.sh --project
```

**git / gh** — clone straight into a directory your agent reads. `.agents/skills/` is the shared cross-agent convention, so it's the widest default:

```bash
git clone https://github.com/Malik1942/product-film.git ~/.agents/skills/product-film
```

| Skills directory | Read by |
|---|---|
| `~/.agents/skills/` | Codex, Cursor |
| `~/.claude/skills/` | Claude Code, Cursor |
| `~/.cursor/skills/` | Cursor |
| `~/.codex/skills/` | Cursor, older Codex builds |

Swap `~/` for `<repo>/` to scope the skill to one repo and commit it with the project; the personal directories make it available everywhere. Any of these can be a symlink to a single checkout, which is what `install.sh` sets up — one copy to update, every agent current. No registration step anywhere: agents discover `SKILL.md` on their own.

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

If your agent supports explicit invocation you can also name it directly — `$product-film` in Codex, `/product-film` in Cursor and Claude Code.

Style direction works at two levels, and the skill knows the difference:

- **Vibe-level** — cascades to everything (edit rhythm, camera energy, cards, score):
  `"Make it calm and premium, like a sundown ambient track."` / `"Playful and energetic."`
- **Scoped** — touches only what you named:
  `"Make the logo gold on the end card."` / `"Slow the title card entrance."`

Two things to expect from the workflow:

1. **It will ask for a script before rendering.** Films are built from a six-block script (vibe, frame, scene list with interaction + payoff + data, words, brand, sound). If your brief is vague, the agent hands you a fill-in template first — that's by design; the approval gate is what prevents expensive wrong-direction renders.
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

Scripts come in two classes: **utilities** run as-is with explicit argv (`swift scripts/mux.swift film.mp4 score.m4a out.mp4`), **templates** (stitch, score) are copied into your project and edited in-file — the clip order and chord tables *are* the interface. No script contains machine-specific or `/tmp` paths, and nothing in the pipeline depends on which agent is driving it — you can run every stage by hand.

## Device frames

The bundled frame is a clean generated bezel (safe to redistribute). For a photorealistic device, drop in any bezel image with a transparent screen cutout — e.g. Apple's official product bezels from [Apple Design Resources](https://developer.apple.com/design/resources/) (check Apple's usage terms):

```bash
FRAME_PNG=/path/to/bezel.png SCREEN_RECT=x,y,w,h swift scripts/composite2.swift ...
```

## Companion skill

Capture (simulator staging, take protocol, auto-zoom derivation via `autoplan.py`) lives in the companion **[screen-recording](https://github.com/Malik1942/screen-recording)** skill — install both for the full recordings-to-scored-film pipeline:

```bash
curl -fsSL https://raw.githubusercontent.com/Malik1942/screen-recording/main/install.sh | bash
```

This repo also stands alone for editing/compositing/scoring — record takes with whatever you have (`xcrun simctl io recordVideo`, `screencapture -v`), then measure with `diffscan` and cut from measured times.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) — mechanics changes are normal PRs; taste-law changes go through the ratification gate described there.

## License

MIT — see [LICENSE](LICENSE). Brand fonts are never bundled; supply yours per project via `FONT_FILE`.

---

Built by [Malik Zhang](https://malikzhang.com).
