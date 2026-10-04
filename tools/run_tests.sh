#!/usr/bin/env bash
# Runs script compilation checks and unit tests headlessly.
#   GODOT=/path/to/godot tools/run_tests.sh [test-file-filter]
# Optional: SMOKE=1 also runs the end-to-end milestone smoke test.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
status=0

run() {
	echo "== $1"
	shift
	"$GODOT" --headless --path . "$@" >"$LOG" 2>&1
	local code=$?
	grep -v -E "ALSA|alsa|audio_driver|All audio drivers|servers/audio|Parameter \"m\" is null|mesh_storage.h" "$LOG"
	if grep -q "SCRIPT ERROR" "$LOG"; then
		echo "!! SCRIPT ERROR reported"
		code=1
	fi
	[ $code -ne 0 ] && status=1
	return 0
}

"$GODOT" --headless --path . --import >/dev/null 2>&1
run "Script check" -s res://tools/check_scripts.gd -- --bw-no-boot
run "Unit tests" -s res://tests/run_tests.gd -- --bw-no-boot "${1:-}"
if [ "${SMOKE:-0}" = "1" ]; then
	run "Smoke: create" -s res://tests/smoke/milestone_smoke.gd -- --phase=create
	run "Smoke: verify" -s res://tests/smoke/milestone_smoke.gd -- --phase=verify
	run "Missing mod: place" -s res://tests/smoke/missing_mod_smoke.gd -- --phase=place
	run "Missing mod: open without mod" -s res://tests/smoke/missing_mod_smoke.gd -- --phase=missing
	run "Missing mod: restore" -s res://tests/smoke/missing_mod_smoke.gd -- --phase=restore
fi
rm -f "$LOG"
[ $status -eq 0 ] && echo "ALL GREEN" || echo "FAILURES"
exit $status
