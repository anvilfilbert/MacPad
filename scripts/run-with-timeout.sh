#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 4 ]]; then
  echo "Usage: $0 <timeout-seconds> <log-path> <description> <command> [args ...]" >&2
  exit 64
fi

TIMEOUT_SECONDS="$1"
LOG_PATH="$2"
DESCRIPTION="$3"
shift 3

if [[ ! "$TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
  echo "Timeout must be a positive integer; received '$TIMEOUT_SECONDS'." >&2
  exit 64
fi

SUPERVISOR_PID=""

forward_signal() {
  local signal_name="$1"
  if [[ -n "$SUPERVISOR_PID" ]] && kill -0 "$SUPERVISOR_PID" 2>/dev/null; then
    kill -s "$signal_name" "$SUPERVISOR_PID"
  fi
}

trap 'forward_signal HUP' HUP
trap 'forward_signal INT' INT
trap 'forward_signal TERM' TERM

/usr/bin/perl -MPOSIX=:sys_wait_h,setpgid -e '
  use strict;
  use warnings;

  my ($timeout_seconds, $log_path, $description, @command) = @ARGV;
  my $received_signal;
  $SIG{HUP} = sub { $received_signal //= "HUP"; };
  $SIG{INT} = sub { $received_signal //= "INT"; };
  $SIG{TERM} = sub { $received_signal //= "TERM"; };

  my $child = fork();
  die "Could not fork $description: $!\n" unless defined $child;

  if ($child == 0) {
    $SIG{HUP} = "DEFAULT";
    $SIG{INT} = "DEFAULT";
    $SIG{TERM} = "DEFAULT";
    setpgid(0, 0) == 0 or die "Could not create process group for $description: $!\n";
    open(STDOUT, ">", $log_path) or die "Could not open $log_path: $!\n";
    open(STDERR, ">&", \*STDOUT) or die "Could not redirect stderr to $log_path: $!\n";
    exec { $command[0] } @command;
    die "Could not execute $command[0] for $description: $!\n";
  }

  if (setpgid($child, $child) != 0) {
    my $setpgid_error = "$!";
    my $group_ready = 0;
    for (1 .. 10) {
      if (kill(0, -$child) > 0) {
        $group_ready = 1;
        last;
      }
      select(undef, undef, undef, 0.01);
    }
    unless ($group_ready) {
      kill "TERM", $child;
      waitpid($child, 0);
      die "Could not establish the process group for $description: $setpgid_error\n";
    }
  }

  my $leader_reaped = 0;
  my $leader_status = 0;
  my $reap_leader = sub {
    return if $leader_reaped;
    my $waited = waitpid($child, WNOHANG);
    if ($waited == $child) {
      $leader_status = $?;
      $leader_reaped = 1;
      return;
    }
    die "Could not wait for $description: $!\n" if $waited == -1;
  };
  my $group_exists = sub {
    return kill(0, -$child) > 0;
  };
  my $terminate_group = sub {
    kill "TERM", -$child if $group_exists->();
    my $grace_deadline = time() + 5;
    while (time() < $grace_deadline) {
      $reap_leader->();
      return 0 unless $group_exists->();
      select(undef, undef, undef, 0.1);
    }

    kill "KILL", -$child if $group_exists->();
    my $kill_deadline = time() + 5;
    while (time() < $kill_deadline) {
      $reap_leader->();
      return 1 unless $group_exists->();
      select(undef, undef, undef, 0.1);
    }
    die "Could not terminate the complete process group for $description.\n";
  };
  my $exit_with_leader_status = sub {
    if (WIFEXITED($leader_status)) {
      exit WEXITSTATUS($leader_status);
    }
    if (WIFSIGNALED($leader_status)) {
      exit 128 + WTERMSIG($leader_status);
    }
    exit 1;
  };

  my $deadline = time() + $timeout_seconds;
  while (1) {
    $reap_leader->();
    if (defined $received_signal) {
      my %exit_status = (HUP => 129, INT => 130, TERM => 143);
      my $forced = $terminate_group->();
      my $detail = $forced ? " and required forced termination" : "";
      print STDERR "$description was interrupted by SIG$received_signal$detail.\n";
      exit $exit_status{$received_signal};
    }
    if ($leader_reaped) {
      $exit_with_leader_status->();
    }

    if (time() >= $deadline) {
      my $forced = $terminate_group->();
      my $detail = $forced ? " and required forced termination" : "";
      print STDERR "$description timed out after $timeout_seconds seconds$detail.\n";
      exit 124;
    }

    select(undef, undef, undef, 0.1);
  }
' "$TIMEOUT_SECONDS" "$LOG_PATH" "$DESCRIPTION" "$@" &
SUPERVISOR_PID="$!"

SUPERVISOR_STATUS=0
while true; do
  WAIT_STATUS=0
  wait "$SUPERVISOR_PID" || WAIT_STATUS=$?
  if ! kill -0 "$SUPERVISOR_PID" 2>/dev/null; then
    SUPERVISOR_STATUS="$WAIT_STATUS"
    break
  fi
done

trap - HUP INT TERM
exit "$SUPERVISOR_STATUS"
