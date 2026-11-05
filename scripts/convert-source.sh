#!/usr/bin/env bash
# Convert the approved guide to markdown in sources/, and record its outline.
#
#   scripts/convert-source.sh [path to the .docx]
#
# The guide states no license, so the converted text is not committed:
# sources/ is ignored except for README.md and outline.json.  The outline
# holds the section numbers and headings and the hash of the .docx, so a
# citation can be checked without the text (scripts/check_survey.py).
# Needs pandoc.
set -euo pipefail
cd "$(dirname "$0")/.."

src="${1:-$HOME/Downloads/Delta/OneID/One+ID+Technical+Implementation+Guide-26.3.docx}"
out=sources/one-id-tig-26.3.md
[ -f "$src" ] || { echo "not found: $src" >&2; exit 1; }

mkdir -p sources
pandoc --from=docx --to=gfm --wrap=none -o "$out" "$src"
python3 scripts/source_outline.py "$src" "$out" "$(pandoc --version | head -1)"
echo "wrote $out ($(wc -l < "$out" | tr -d ' ') lines) and sources/outline.json"
