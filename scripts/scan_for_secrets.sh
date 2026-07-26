#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

patterns='BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|AKIA[0-9A-Z]{16}|(api[_-]?key|client[_-]?secret|access[_-]?token)[[:space:]]*[:=][[:space:]]*["'\"']?[A-Za-z0-9_./+=-]{16,}'

if git grep -nEI "$patterns" -- . \
  ':(exclude)scripts/scan_for_secrets.sh' \
  ':(exclude)docs/*.md'; then
  echo "Potential committed secret detected." >&2
  exit 1
fi

echo "Heuristic tracked-file secret scan passed."
