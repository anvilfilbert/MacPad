#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

if git grep -I -l -E \
  '(/Users/[^/[:space:]]+|/home/[^/[:space:]]+|github_pat_[A-Za-z0-9_]+|gh[opusr]_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|(^|[^0-9])(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3})([^0-9]|$))' \
  -- . \
  ':(exclude)scripts/verify-public-repo.sh' \
  ':(exclude)scripts/package-release.sh'; then
  echo "Potential private path, credential, private key, or private IP found in tracked files." >&2
  exit 1
fi

# The owner-approved customer support address is public product metadata.
EMAIL_PATTERN='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
email_grep_status=0
email_matches="$(git grep -I -h -o -E "$EMAIL_PATTERN" \
  -- . \
  ':(exclude)scripts/verify-public-repo.sh' \
  ':(exclude)scripts/package-release.sh' 2>&1)" || email_grep_status=$?

case "$email_grep_status" in
  0)
    ;;
  1)
    email_matches=""
    ;;
  *)
    echo "Public repository email scan failed with status $email_grep_status: $email_matches" >&2
    exit "$email_grep_status"
    ;;
esac

if [[ -n "$email_matches" ]]; then
  unexpected_email_status=0
  printf '%s\n' "$email_matches" \
    | /usr/bin/grep -Fxv 'support@macpad.net' >/dev/null || unexpected_email_status=$?
  case "$unexpected_email_status" in
    0)
      echo "Potential unapproved email address found in tracked files." >&2
      exit 1
      ;;
    1)
      ;;
    *)
      echo "Approved support-email comparison failed with status $unexpected_email_status." >&2
      exit "$unexpected_email_status"
      ;;
  esac
fi

echo "Public repository content check passed."
