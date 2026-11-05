#!/usr/bin/env bash
# Fetch the public specifications the guide refers to, and record what was
# fetched.
#
#   scripts/fetch-sources.sh
#
# Each document goes into its own folder under sources/external/, with its
# text beside it (pandoc for HTML, pdftotext for PDF).  None of it is
# committed: sources/ is ignored.  The record, sources/external.json, is
# committed: address, day fetched, SHA-256, the version and copyright line the
# document prints, and its section numbers and titles.
#
# The list of documents is in scripts/external_sources.py.  The ISO/IEC
# documents and IATA Resolution 792 are sold and are not fetched.
#
# The fetched files are untrusted: nothing here runs from inside
# sources/external, and Python reads them in isolated mode (-I).
# Needs curl, pandoc and pdftotext (poppler).
set -euo pipefail
cd "$(dirname "$0")/.."

base=sources/external
mkdir -p "$base"

python3 -I scripts/external_sources.py list | while IFS=$'\t' read -r name file kind url; do
  dir="$base/$name"
  mkdir -p "$dir"
  # The default client name: some of these sites refuse a client that claims
  # to be a browser.
  curl --silent --show-error --fail --location --max-time 300 -o "$dir/$file" "$url"
  case "$kind" in
    html) pandoc --from=html --to=gfm-raw_html --wrap=none -o "$dir/text.md" "$dir/$file" ;;
    pdf)  pdftotext -layout "$dir/$file" "$dir/text.txt" 2>/dev/null ;;
    rfc)  ;;
  esac
  echo "fetched $name"
done

python3 -I scripts/external_sources.py record "$base" "$(date +%Y-%m-%d)"
