#!/usr/bin/env bash
# Install LICENSE, NOTICE, and trilingual README into a package staging tree.
# Usage: stage-docs.sh <staging-root> <doc-package-name>
set -euo pipefail

STAGE="${1:?staging root required}"
PKG="${2:?package name required}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOC="$STAGE/usr/share/doc/$PKG"

install -d "$DOC"
install -m 0644 "$ROOT/LICENSE" "$ROOT/NOTICE" "$DOC/"
install -m 0644 "$ROOT/README.md" "$DOC/README.en.md"
install -m 0644 "$ROOT/README.ru.md" "$DOC/"
install -m 0644 "$ROOT/README.de.md" "$DOC/"
