#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_PARENT="${TMPDIR:-/tmp}"
TEMP_ROOT="$(mktemp -d "$TEMP_PARENT/macpad-timeout-tests.XXXXXX")"
RUNNER="$ROOT_DIR/scripts/run-with-timeout.sh"

cleanup() {
  case "$TEMP_ROOT" in
    "$TEMP_PARENT"/macpad-timeout-tests.*)
      rm -rf -- "$TEMP_ROOT"
      ;;
    *)
      echo "Refusing to remove unexpected watchdog-test path: $TEMP_ROOT" >&2
      return 1
      ;;
  esac
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

fail() {
  echo "Timeout watchdog test failed: $1" >&2
  exit 1
}

wait_for_pid_file() {
  local pid_file="$1"
  local description="$2"
  local attempt

  for attempt in {1..50}; do
    [[ -s "$pid_file" ]] && return 0
    /bin/sleep 0.1
  done
  fail "$description did not create its PID evidence file"
}

require_recorded_processes_stopped() {
  local pid_file="$1"
  local description="$2"
  local process_id
  local recorded_count=0

  while IFS= read -r process_id; do
    [[ "$process_id" =~ ^[1-9][0-9]*$ ]] || fail "$description recorded an invalid PID: $process_id"
    recorded_count=$((recorded_count + 1))
    if kill -0 "$process_id" 2>/dev/null; then
      fail "$description left PID $process_id running"
    fi
  done < "$pid_file"

  [[ "$recorded_count" -ge 2 ]] || fail "$description did not record both leader and child PIDs"
}

success_log="$TEMP_ROOT/success.log"
"$RUNNER" 3 "$success_log" "success probe" /bin/echo success
/usr/bin/grep -Fx success "$success_log" >/dev/null || fail "success probe output is missing"

timeout_status=0
"$RUNNER" 1 "$TEMP_ROOT/timeout.log" "simple timeout probe" /bin/sleep 30 || timeout_status=$?
[[ "$timeout_status" -eq 124 ]] || fail "simple timeout returned $timeout_status instead of 124"

interrupt_pid_file="$TEMP_ROOT/interrupt.pids"
interrupt_marker="macpad-interrupt-$RANDOM-$$"
interrupt_status=0
"$RUNNER" \
  30 \
  "$TEMP_ROOT/interrupt.log" \
  "interrupt probe" \
  /bin/sh \
  -c \
  'trap "" TERM; /bin/sleep 30 & child=$!; printf "%s\n%s\n" "$$" "$child" > "$1"; wait' \
  "$interrupt_marker" \
  "$interrupt_pid_file" &
interrupt_runner_pid=$!
wait_for_pid_file "$interrupt_pid_file" "interrupt probe"
kill -TERM "$interrupt_runner_pid"
wait "$interrupt_runner_pid" || interrupt_status=$?
[[ "$interrupt_status" -eq 143 ]] || fail "interrupted runner returned $interrupt_status instead of 143"
require_recorded_processes_stopped "$interrupt_pid_file" "interrupted runner"

leader_pid_file="$TEMP_ROOT/leader.pids"
leader_marker="macpad-leader-$RANDOM-$$"
leader_status=0
"$RUNNER" \
  1 \
  "$TEMP_ROOT/leader.log" \
  "leader timeout probe" \
  /bin/sh \
  -c \
  'trap "exit 0" TERM; /bin/sh -c '\''trap "" TERM; /bin/sleep 30 & child=$!; printf "%s\n%s\n" "$$" "$child" > "$1"; wait'\'' "$1" "$2" & wait' \
  leader \
  "$leader_marker" \
  "$leader_pid_file" || leader_status=$?
[[ "$leader_status" -eq 124 ]] || fail "leader timeout returned $leader_status instead of 124"
require_recorded_processes_stopped "$leader_pid_file" "leader timeout"

echo "Timeout watchdog tests passed."
