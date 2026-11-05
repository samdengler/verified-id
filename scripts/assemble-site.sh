#!/usr/bin/env bash
# Assemble site/ from the build outputs, in the layout a static host serves:
# the progress page at the root, the review document under review/, the
# blueprint under blueprint/, and the specs and exports beside them.
#
#   scripts/assemble-site.sh
#
# scripts/build-site.sh, scripts/preview.sh and CI all use this script.  The
# blueprint PDF is required unless ALLOW_MISSING=1, which the preview sets
# because it skips that step.
set -euo pipefail
cd "$(dirname "$0")/.."

optional() {
  if [ -f "$1" ]; then
    cp "$1" "$2"
  elif [ "${ALLOW_MISSING:-}" != 1 ]; then
    echo "missing $1" >&2
    exit 1
  fi
}

rm -rf site
mkdir -p site/blueprint site/review
cp build/progress/index.html site/index.html
cp -r build/review/html-multi/. site/review/
# pages/ holds the redirect that takes the blueprint's links to a Lean name
# into the review document.
cp -r pages/. site/
cp -r blueprint/web/. site/blueprint/
python3 scripts/site_nav.py site/blueprint
optional blueprint/print/print.pdf site/blueprint/print.pdf
cp -r .kiro/specs site/specs
cp build/ears.md build/ears.csv build/ears-criteria.csv build/provenance.csv build/assumptions.csv \
  build/ranking.json build/status.json site/
