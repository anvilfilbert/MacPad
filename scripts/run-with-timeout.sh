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

/usr/bin/perl -MPOSIX=:sys_wait_h,setpgid -e '
  use strict;
  use warnings;

  my ($timeout_seconds, $log_path, $description, @command) = @ARGV;
  my $child = fork();
  die "Could not fork $description: $!\n" unless defined $child;

  if ($child == 0) {
    setpgid(0, 0) == 0 or die "Could not create process group for $description: $!\n";
    open(STDOUT, ">", $log_path) or die "Could not open $log_path: $!\n";
    open(STDERR, ">&", \*STDOUT) or die "Could not redirect stderr to $log_path: $!\n";
    exec { $command[0] } @command;
    die "Could not execute $command[0] for $description: $!\n";
  }

  my $deadline = time() + $timeout_seconds;
  while (1) {
    my $waited = waitpid($child, WNOHANG);
    if ($waited == $child) {
      if (WIFEXITED($?)) {
        exit WEXITSTATUS($?);
      }
      if (WIFSIGNALED($?)) {
        exit 128 + WTERMSIG($?);
      }
      exit 1;
    }
    die "Could not wait for $description: $!\n" if $waited == -1;

    if (time() >= $deadline) {
      kill "TERM", -$child;
      my $grace_deadline = time() + 5;
      while (time() < $grace_deadline) {
        my $grace_waited = waitpid($child, WNOHANG);
        if ($grace_waited == $child) {
          print STDERR "$description timed out after $timeout_seconds seconds.\n";
          exit 124;
        }
        select(undef, undef, undef, 0.1);
      }
      kill "KILL", -$child;
      waitpid($child, 0);
      print STDERR "$description timed out after $timeout_seconds seconds and required forced termination.\n";
      exit 124;
    }

    select(undef, undef, undef, 0.1);
  }
' "$TIMEOUT_SECONDS" "$LOG_PATH" "$DESCRIPTION" "$@"
