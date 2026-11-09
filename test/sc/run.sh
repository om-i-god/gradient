#!/bin/sh
# usage: test/sc/run.sh [extra.scd]
# compiles lib/Engine_Gradient.sc against a stub CroneEngine, boots a local
# server, fires every command (or runs extra.scd with ~eng set), renders a
# wav and prints its levels. killed after 300s if sclang hangs.
#
# the stub lives as CroneStub.stub so it can never be compiled on a norns
# (a second CroneEngine class there = "DUPLICATE ENGINES"); it's copied to a
# temp class dir as .sc only for this run.
EXTRA=""
[ -n "$1" ] && EXTRA="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
cd "$(dirname "$0")"
SCLANG=/Applications/SuperCollider.app/Contents/MacOS/sclang
OUT="${TMPDIR:-/tmp}/gradient_test.wav"
LIB="${TMPDIR:-/tmp}/gradient_sclib"
rm -rf "$LIB"; mkdir -p "$LIB"
cp CroneStub.stub "$LIB/CroneStub.sc"
cat > "$LIB/lang.yaml" <<YAML
includePaths:
  - $LIB
  - $(cd ../../lib && pwd)
excludePaths: []
postInlineWarnings: false
YAML
# scsynth servers that were already running (another session's): never ours
BEFORE=" $(pgrep -f 'SuperCollider.app/Contents/Resources/../Resources/scsynth' | tr '\n' ' ')"
perl -e 'alarm 300; exec @ARGV' "$SCLANG" -l "$LIB/lang.yaml" run.scd "$OUT" $EXTRA 2>&1 \
  | grep -E "ERROR|WARNING|FAILURE|ENGINE|SMOKE|LEVEL|PAD|CPU|SEG|poll |Message|RECEIVER|not understood|nil|CHECK|exception|Exception|error|late" \
  | grep -v "^Exception in World_OpenUDP"
# belt and braces: never leave our own test server behind (only the ones started here)
for p in $(pgrep -f "SuperCollider.app/Contents/Resources/../Resources/scsynth"); do
  case "$BEFORE" in *" $p "*) ;; *) kill "$p" 2>/dev/null ;; esac
done
exit 0
