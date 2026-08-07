#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

if git grep -I -l -E \
  '(/Users/[^/[:space:]]+|/home/[^/[:space:]]+|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|github_pat_[A-Za-z0-9_]+|gh[opusr]_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|(^|[^0-9])(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3})([^0-9]|$))' \
  -- . \
  ':(exclude)scripts/verify-public-repo.sh' \
  ':(exclude)scripts/package-release.sh'; then
  echo "Potential private path, email, credential, private key, or private IP found in tracked files." >&2
  exit 1
fi

echo "Public repository content check passed."
