#!/usr/bin/env bash
# Build everything CI builds, in the same order, and assemble site/.  It must
# pass before anything lands on main.
#
#   scripts/build-site.sh
#
# Needs: elan, Python 3.12 or later with leanblueprint (in .venv or on the
# path), graphviz, and a TeX installation with xelatex and latexmk.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -d .venv ]; then PATH="$PWD/.venv/bin:$PATH"; fi

lake build
# Fails on a sorry that is not tagged @[open_question], a rule with no
# @[source], a malformed EARS statement, or a criterion nothing defines.
lake exe status
python3 scripts/render_status.py
# The survey, the blueprint and the citations agree with each other.
python3 scripts/check_survey.py
lake build Review
rm -rf build/review
lake exe review-doc --output build/review
# web writes blueprint/lean_decls, which checkdecls reads.
leanblueprint web
leanblueprint checkdecls
leanblueprint pdf
python3 scripts/render_progress.py

scripts/assemble-site.sh
echo "site/ is ready; preview with: python3 scripts/serve_site.py"
