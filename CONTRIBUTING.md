# Contributing

Issues and PRs are welcome. This skill has one unusual property worth understanding before you open one: **its rules are codified taste rulings from real film deliveries**, so different kinds of changes are held to different bars.

## Two kinds of change

**Mechanics — normal PRs.** Bug fixes, portability, graceful failures, doc drift, new script parameters. Bar: the cleanroom test still passes (run the full pipeline from an empty directory using only this repo), and the invariant holds — no machine-specific, project-specific, or `/tmp` paths in any script.

**Taste laws — the ratification gate.** The iron laws, camera grammar, transition ladder, and pacing rules exist because a specific version of a real film was rejected. Changing one needs the same class of evidence: a concrete case where the current rule produced a worse film, and a generalized replacement that transfers to any product. Per the skill's own evolution protocol, encode the *generalized lesson*, never a project-local preference — "my project wanted cross-dissolves" is script-level direction, not a new default.

## Script contract (hold the line)

- **Utilities** (scan, diffscan×2, condense, composite2, mux, card templates): every required input via explicit argv; optional behavior via env; usage line + clean error on bad input.
- **Templates** (stitch, score×2): the creative contract lives in-file by design; env vars (`CLIPS_DIR`, `OUT`) are only for portable path resolution. Please don't "fix" them into CLI tools.
- **Agent-agnostic.** `SKILL.md` and `references/` are read by whichever agent is driving — so keep them free of agent names, invocation syntax and vendor skills-directory paths: write `<your-skills-dir>/…`, never a vendor-specific one. No agent is this repo's default, and none should read as the primary. Agent-specific detail belongs in the README's directory table and `install.sh`, nowhere else. Every pipeline stage must stay runnable by hand from a shell.

## Verifying your change

```bash
mkdir ~/Desktop/cleanroom && cd ~/Desktop/cleanroom   # any empty durable dir — not /tmp (iron law 11)
# render a card, composite it, stitch, score, mux — the README quick start is the test script
```

A change is done when the pipeline runs from that empty directory and an extracted frame of the final file shows what you expect. Frame verification over assertions — that rule applies to contributors too.
