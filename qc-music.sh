#!/usr/bin/env bash
# qc-music.sh - convenience wrapper: QC a music cover/thumbnail against the mood board.
# Usage: ./qc-music.sh path/to/candidate.png   (or no arg = judge everything in candidates/)
#
# Sends the downscaled mood-board grid (the full standard) + 3 full-res vibe exemplars,
# then gates into ../APPROVED (PASS) or ./rejected (FAIL).

set -euo pipefail
QC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
R="$QC_DIR/references"

# Reference set: the whole-board grid + one full-res exemplar per vibe.
REFS=(
  -r "$R/_moodboard-grid.jpg"   # the entire standard, downscaled
  -r "$R/IMG_8880.JPG"          # cosmic lone figure walking toward the orb (template match)
  -r "$R/IMG_8826.JPG"          # iridescent / prism (prism-flow vibe)
  -r "$R/IMG_8877.JPG"          # epic monumental scale (epic vibe)
)

judge() {
  local cand="$1"
  "$QC_DIR/qc-image.sh" -c "$cand" "${REFS[@]}" || true
  echo ""
}

if [[ $# -ge 1 ]]; then
  judge "$1"
else
  shopt -s nullglob
  cands=("$QC_DIR/candidates"/*.png "$QC_DIR/candidates"/*.jpg)
  [[ ${#cands[@]} -eq 0 ]] && { echo "No candidates in candidates/."; exit 0; }
  echo "Judging ${#cands[@]} candidate(s) against the mood board..."
  echo ""
  for c in "${cands[@]}"; do judge "$c"; done
  echo "Done. PASS -> APPROVED/   FAIL -> rejected/   verdicts -> reports/"
fi
