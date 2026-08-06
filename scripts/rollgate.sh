#!/bin/zsh
# rollgate.sh — NUMERIC PRE-ROLL GATE. Rolling is BLOCKED unless all three pass.
#   1. WindowServer CPU < 20%
#   2. load average (1m) < 4
#   3. 5s test capture: median frame gap in MOTION <= 1/55s (0.01818s)
# usage: rollgate.sh <x> <y> <w> <h>   (same region you will record)
# exit 0 = all pass (SAFE TO ROLL), exit 1 = blocked (report the failing number, do NOT roll)
set -e
DIR="${0:A:h}"
SCRATCH="${TMPDIR:-/tmp}/rollgate.$$"
mkdir -p "$SCRATCH"
X=${1:?x}; Y=${2:?y}; W=${3:?w}; H=${4:?h}
FAIL=0

WS=$(ps -Ao pcpu,comm -r | awk '/WindowServer/ {print $1; exit}')
[ -z "$WS" ] && WS=0
LOAD=$(sysctl -n vm.loadavg | awk '{print $2}')

echo "── pre-roll gate ──"
if awk -v v="$WS" 'BEGIN{exit !(v < 20)}'; then echo "  PASS  WindowServer CPU ${WS}%  (< 20)"; else echo "  FAIL  WindowServer CPU ${WS}%  (needs < 20)"; FAIL=1; fi
if awk -v v="$LOAD" 'BEGIN{exit !(v < 4)}'; then echo "  PASS  load average ${LOAD}  (< 4)"; else echo "  FAIL  load average ${LOAD}  (needs < 4)"; FAIL=1; fi

# 3: 5s test capture while the cursor moves (motion, so VFR emits frames continuously)
REC="$DIR/sckrecord"; MOUSE="$DIR/mousebin"
if [ ! -x "$REC" ]; then echo "  SKIP  no compiled sckrecord at $REC (build: swiftc -O sckrecord.swift -o sckrecord)"; FAIL=1;
else
  # SHOWCURSOR=1: production takes hide the OS pointer, but the gate's wiggle
  # must register as pixel change or VFR emits nothing and the gate false-fails.
  SHOWCURSOR=1 "$REC" $X $Y $W $H "$SCRATCH/gate.mov" > "$SCRATCH/rec.log" 2>&1 &
  RPID=$!
  sleep 1
  for i in $(seq 1 60); do
    PX=$(( X + W/4 + (W/2) * (i % 20) / 20 )); PY=$(( Y + H/2 ))
    [ -x "$MOUSE" ] && "$MOUSE" $PX $PY
    sleep 0.055
  done
  kill -INT $RPID 2>/dev/null || true
  sleep 2.5
  MED=$("$DIR/gatestats" "$SCRATCH/gate.mov" 2>/dev/null || echo "")
  if [ -z "$MED" ]; then echo "  FAIL  test capture produced no readable frames"; FAIL=1
  else
    if awk -v v="$MED" 'BEGIN{exit !(v <= 0.018182)}'; then echo "  PASS  median motion frame gap ${MED}s  (<= 1/55 = 0.01818)"
    else echo "  FAIL  median motion frame gap ${MED}s  (needs <= 1/55 = 0.01818)"; FAIL=1; fi
  fi
fi
rm -rf "$SCRATCH"
echo "───────────────────"
if [ $FAIL -eq 0 ]; then echo "GATE: PASS — safe to roll"; exit 0
else echo "GATE: BLOCKED — do not roll; report the failing number and wait"; exit 1; fi
