#!/usr/bin/env python3
"""autoplan.py — derive an auto-zoom camera plan + cursor cues from measured taps.

Usage: autoplan.py taps.json [--desktop]

Input: a JSON file of interactions in OUTPUT-clip time (after your trim):
    [{"t": 2.7, "fx": 0.27, "fy": 0.80}, ...]
Optional keys per tap: "zoom" (default 1.4 mobile / 1.6 desktop), "holdUntil" (default t+1.8).
Optional top-level wrapper: {"dur": 8.0, "taps": [...]} to set clip duration.

--desktop (FILL=1 grammar): wide is exactly 1.0 (cover — the page fills the canvas),
zoom defaults are deeper (desktop UI text is small), and consecutive taps closer than
0.35 in fraction space get a constant-zoom follow-pan (Screen Studio style) instead of
returning wide between them. composite2 clamps every move to content bounds, so plans
may target corners freely.

Output: the composite2.swift camera-plan string and cursor/tap arguments
(product-film skill, scripts/composite2.swift). One cursor chain is emitted
for the FIRST tap (composite2 supports one cursor pass); extra taps get
camera+ripple guidance printed for a second pass if needed.
"""
import json, sys, math

def main():
    desktop = "--desktop" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if not args:
        sys.exit('usage: autoplan.py taps.json [--desktop]\n  taps.json: [{"t": 2.7, "fx": 0.27, "fy": 0.80}, ...] or {"dur": 8.0, "taps": [...]}')
    try:
        raw = json.load(open(args[0]))
    except FileNotFoundError:
        sys.exit(f"error: no such file: {args[0]}")
    except json.JSONDecodeError as e:
        sys.exit(f"error: {args[0]} is not valid JSON: {e}")
    taps = raw["taps"] if isinstance(raw, dict) else raw
    if not taps or not all(k in tap for tap in taps for k in ("t", "fx", "fy")):
        sys.exit('error: each tap needs "t", "fx", "fy" (fractions of screen from top-left)')
    dur = (raw.get("dur") if isinstance(raw, dict) else None) or (taps[-1].get("holdUntil", taps[-1]["t"] + 1.8) + 0.5)
    wide = 1.0 if desktop else 1.02
    default_zoom = 1.6 if desktop else 1.4
    keys = []
    prev_end = 0.0
    for i, tap in enumerate(taps):
        t, fx, fy = tap["t"], tap["fx"], tap["fy"]
        zoom = tap.get("zoom", default_zoom)
        hold = tap.get("holdUntil", t + 1.8)
        follow = False
        if desktop and i > 0:
            pfx, pfy = taps[i-1]["fx"], taps[i-1]["fy"]
            follow = math.hypot(fx - pfx, fy - pfy) < 0.35
        if follow:
            # constant-zoom follow-pan: glide from the previous hold straight to this target
            keys.append((round(t - 0.3, 2), fx, fy, zoom, 0))
        else:
            wide_until = max(prev_end, t - 1.2)
            if i == 0 and wide_until > 0.05:
                keys.append((0.0, 0.5, 0.5, wide, 0))
            keys.append((round(wide_until, 2), 0.5 if i == 0 else keys[-1][1], 0.5 if i == 0 else keys[-1][2],
                         wide if i == 0 else keys[-1][3], 0))
            keys.append((round(t - 0.3, 2), fx, fy, zoom, 0))
        keys.append((round(hold, 2), fx, fy, zoom + 0.02, 0))
        prev_end = hold
    if prev_end < dur - 0.3:
        end_scale = 1.0 if desktop else max(1.1, keys[-1][3] - 0.25)
        keys.append((round(dur, 2), keys[-1][1], keys[-1][2], end_scale, 0))
    # dedupe/monotonic
    seen, plan = set(), []
    for k in keys:
        if k[0] in seen:
            continue
        seen.add(k[0]); plan.append(k)
    plan.sort(key=lambda k: k[0])
    plan_str = "; ".join(f"{k[0]:g} {k[1]:g} {k[2]:g} {k[3]:g} {k[4]:g}" for k in plan)

    first = taps[0]
    t0 = first["t"]
    cur = (round(max(0.1, t0 - 1.4), 2), round(t0 - 0.25, 2), 0.5, min(0.9, first["fy"] + 0.25))
    tap_args = (round(t0 - 0.15, 2), first["fx"], first["fy"])

    print("# camera plan:")
    print(f'"{plan_str}"')
    env = "FILL=1 " if desktop else ""
    print(f"\n# composite2 args (rate=1, cropTop=0, no pressT){' — prefix env: ' + env if env else ''}:")
    print(f'{env}... "{plan_str}" 1.0 0.0 -1 {tap_args[0]} {tap_args[1]} {tap_args[2]} {cur[0]} {cur[1]} {cur[2]} {cur[3]}')
    if len(taps) > 1:
        print("\n# additional taps (ripple-only; run a second pass or place manually):")
        for tap in taps[1:]:
            print(f'#   tapT={round(tap["t"]-0.15,2)} fx={tap["fx"]} fy={tap["fy"]}')

if __name__ == "__main__":
    main()
