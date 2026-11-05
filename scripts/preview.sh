#!/usr/bin/env bash
# Rebuild the documents and serve the site at http://localhost:8000/ (or the
# port given), to review a change before it lands.
#
#   scripts/preview.sh [port]
#
# Builds the model, the status, the review document, the blueprint web pages
# and the progress page.  Skips the blueprint PDF, which scripts/build-site.sh
# and CI build; a PDF from an earlier full build is included if present.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -d .venv ]; then PATH="$PWD/.venv/bin:$PATH"; fi
port="${1:-8000}"

lake build
lake exe status
python3 scripts/render_status.py
python3 scripts/check_survey.py
lake build Review
rm -rf build/review
lake exe review-doc --output build/review
leanblueprint web
python3 scripts/render_progress.py
ALLOW_MISSING=1 scripts/assemble-site.sh

echo "serving site/ at http://localhost:$port/ (Ctrl-C to stop)"
python3 scripts/serve_site.py "$port"
