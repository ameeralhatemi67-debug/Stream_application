#!/usr/bin/env bash
# Proof that the two older designs did not change.
#
# Captures the 38 screen pictures of gold & black and Hedayah on a clean copy
# of master and on this branch AT THE SAME TIME (lesson and map screens show
# countdowns, so the two runs must share the clock), then compares them
# pixel by pixel.
#
# usage: brief/tools/skin_proof.sh <master worktree> <output folder>
#   <master worktree>  a checkout of master that has
#                      project/test/skin_regression_capture_test.dart copied
#                      into it and `flutter pub get` already run.
#   <output folder>    gets before/, after/, diff/ and result.txt
set -u
here="$(cd "$(dirname "$0")/../.." && pwd)"
master="$1"
out="$2"
mkdir -p "$out/before" "$out/after" "$out/diff"

run() { # <project folder> <capture folder> <log>
  (cd "$1" && SKIN_REGRESSION_DIR="$2" flutter test test/skin_regression_capture_test.dart >"$3" 2>&1)
}

run "$master/project" "$out/before" "$out/before.log" &
a=$!
run "$here/project" "$out/after" "$out/after.log" &
b=$!
wait $a; ra=$?
wait $b; rb=$?
echo "capture on master: exit $ra; capture on the branch: exit $rb"
python "$here/brief/tools/compare_skin_captures.py" "$out/before" "$out/after" --diff "$out/diff" | tee "$out/result.txt" | tail -12
