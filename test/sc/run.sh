#!/bin/sh
# usage: test/sc/run.sh [extra.scd]
# compiles lib/Engine_Gradient.sc against a stub CroneEngine, boots a local
# server, fires every command (or runs extra.scd with ~eng set), renders a
# wav and prints its levels. killed after 120s if sclang hangs.
EXTRA=""
[ -n "$1" ] && EXTRA="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
cd "$(dirname "$0")"
SCLANG=/Applications/SuperCollider.app/Contents/MacOS/sclang
OUT="${TMPDIR:-/tmp}/gradient_test.wav"
perl -e 'alarm 120; exec @ARGV' "$SCLANG" -l lang.yaml run.scd "$OUT" $EXTRA 2>&1 \
  | grep -E "ERROR|WARNING|FAILURE|ENGINE|SMOKE|LEVELS|SEG|poll |Message|RECEIVER|not understood|nil|CHECK|exception|Exception|error|late" \
  | grep -v "^Exception in World_OpenUDP"
# belt and braces: never leave a test server behind
pkill -f "SuperCollider.app/Contents/Resources/../Resources/scsynth" 2>/dev/null
exit 0
