#!/usr/bin/env bash
# Check Verified Airline's One ID pages against this build of the model.  The
# airline's site has its own repository and keeps a copy of the files this
# build writes to build/one-id-data/ in model/one-id/.  Its own check script
# stops if a page cites a requirement or a reading the model no longer has, or
# shows a result the decisions do not.
#
#   scripts/check-airline.sh
#
# Uses the checkout in AIRLINE_REPO, or ../verified-airline.  Until that
# checkout has model/one-id/, there are no One ID pages to check, and this
# prints that it skipped.
set -euo pipefail
cd "$(dirname "$0")/.."
repo="${AIRLINE_REPO:-../verified-airline}"
if [ ! -d "$repo/model/one-id" ]; then
  echo "check-airline: skipped; $repo/model/one-id/ does not exist, so there are no One ID pages to check"
  exit 0
fi
check="$repo/scripts/check_one_id.py"
if [ ! -f "$check" ]; then
  echo "check-airline: $repo/model/one-id/ exists but $check does not" >&2
  exit 1
fi
echo "checking Verified Airline's One ID pages in $repo against build/one-id-data/"
python3 "$check" --model build/one-id-data
