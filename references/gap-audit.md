# Gap Audit — mandatory after every generation

**Every render gets an audit before it is delivered.** Not "when something feels off" — every time,
including versions that only changed one scene. The audit is a written artifact delivered alongside
the film, not a paragraph in chat that disappears.

Why it is mandatory: frame verification proves a render is technically sound (no black edges, no
broken splices). It says nothing about whether the film **delivered what the script promised**. Those
are different failures, and the second kind survives every technical check. A film shipped six
versions with an act card announcing an export sequence that had never been captured — every version
passed frame verification, because the frames were fine. The missing act was invisible to that lens.

## The rule

For each scene in the approved script, state the promise, state what the delivered file actually
shows, and give a verdict. **Verdicts must be evidence-based** — extract a frame from the delivered
file at the payoff moment and look at it. Never grade from your build plan or your intent; the plan
is what you meant to do, the frame is what you did.

Verdicts, used unqualified:

| Verdict | Meaning |
|---|---|
| **MET** | The promise is on screen and readable |
| **PARTIAL** | The beat exists but its stated payoff isn't legible (cropped, too short, wrong state) |
| **CONTRADICTED** | The film shows the opposite of the promise (script says "Proof reads Scannable"; the frame reads "Checking…") |
| **MISSING** | The beat is absent |
| **DEVIATES** | Present, but different content than scripted (footage truth ≠ script) |
| **CUT/CHANGED BY DIRECTION** | The user asked for it — still recorded, never silently dropped |

Then separate the findings by cause, because it determines who can fix them:
- **Editing gaps** — fixable from footage you already have. Fix these before delivering.
- **Capture gaps** — the interaction was never filmed. Cannot be fixed in the edit. Say so plainly
  and name the shot that would close it.

## Non-negotiables

- **No unqualified language.** "Mostly matches", "close enough", "essentially met" are banned. A
  payoff is legible on screen or it is not.
- **An orphaned promise is a defect, not a stylistic choice.** A title card announcing an act that
  does not exist, a claim in the opening that nothing demonstrates — these get flagged every time
  and normally get removed. Cutting the promise is the correct fix when the footage cannot support
  it; keeping it and hoping is not.
- **Deviations carried on purpose still get written down.** "The take used the Ocean preset, the
  script says Sunset" belongs in the audit even though it is fine, because the next person to touch
  the film should not have to rediscover it.
- **Report the audit to the user with the film.** Findings you do not surface are findings you have
  hidden — including the ones you decided not to act on.

## Structure

```markdown
# <Film> — Gap Audit (vN)
## Audit of vN
| # | Script promise | What the delivered file shows | Verdict |
## The gulfs (ranked)          <- the 2-3 that actually matter, worst first
## Root causes                  <- editing vs capture, per gap
## Resolutions applied in vN+1  <- what you changed and why
## Verification                 <- frames pulled from the NEW file proving the fixes landed
## Remaining gaps               <- unfixed, with the specific shot each one needs
```
