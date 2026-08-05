# product-film

An AVFoundation-based product-film pipeline for Claude Code — turns screen recordings of any product (iOS app, website, desktop app, Figma prototype) into a scored, verified promo film. No ffmpeg, no video editor: every stage is a plain Swift script driven from the terminal.

Version 1.0.0.

## Requirements

- macOS with Xcode Command Line Tools (`swift` on PATH). For simulator work set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- The companion **screen-recording** skill for the capture stage (staging, take protocol, and `scripts/autoplan.py` for camera-plan derivation; autoplan needs `python3`).
- Optional: the Figma MCP server, only for the Figma fallback card path.

## Installation

Copy this directory to `~/.claude/skills/product-film/` (personal, all projects) or `<repo>/.claude/skills/product-film/` (project-scoped). Nothing else to install — the iPhone mockup ships in `assets/` and every script resolves it relative to itself.

## Quick start

1. **Script first.** Write the six-block film script (`references/writing-the-script.md` has the template): vibe, frame, scene list with interaction+payoff+data, words, brand, sound. Get it approved before rendering anything.
2. **Capture** takes with the screen-recording skill, into a durable project directory.
3. From that directory, run the pipeline (contracts in `references/playbook.md`):

```bash
SKILL=~/.claude/skills/product-film/scripts
swift $SKILL/scan.swift take1.mp4 sheet.png            # eyeball the take
swift $SKILL/diffscan.swift take1.mp4                  # measure real interaction times (diffscan2 for desktop)
swift $SKILL/condense.swift take1.mp4 scene1.mp4 "12.7,15.2;25.7,28.2,1.5"
swift $SKILL/composite2.swift scene1.mp4 scene1-comp.mp4 0 8 "0 .5 .5 1.02 0; 3 .27 .8 1.4 0"
FONT_FILE=Brand.ttf ACCENTS=FFEE51,0EA5E9 swift $SKILL/title-card-template.swift card1.mov 2.4 "FAST CAPTURE"
cp $SKILL/stitch-template.swift .                      # template: edit clips + transitions in-file
swift stitch-template.swift                            # -> film.mp4
cp $SKILL/score-template.swift .                       # template: edit chords/BPM/automation in-file
swift score-template.swift                             # -> score.m4a
swift $SKILL/mux.swift film.mp4 score.m4a "Film v1.mp4"
```

4. **Verify frames and run the gap audit** (`references/gap-audit.md`) — both are mandatory; deliver the audit with the film.

## Layout

- `SKILL.md` — triggers, pipeline order, non-negotiables, symptom table
- `references/playbook.md` — stage contracts, script arguments, iron laws, camera grammar
- `references/writing-the-script.md` — the six-block script contract + template
- `references/gap-audit.md` — the mandatory per-render audit format
- `scripts/` — utilities (argv-driven, run as-is) and templates (copy per project, edit in-file)
- `assets/iphone-mockup.png` — default device frame for the mobile path (`FRAME_PNG`/`SCREEN_RECT` env to substitute any other)

## Asset note

The bundled iPhone mockup is a device-bezel image of unverified origin, used here as a personal working asset. It is trivially replaceable (`FRAME_PNG=/path.png SCREEN_RECT=x,y,w,h`); verify redistribution rights or substitute your own bezel render before publishing this skill beyond personal use. No fonts are bundled — brand fonts are supplied per project via `FONT_FILE`.
