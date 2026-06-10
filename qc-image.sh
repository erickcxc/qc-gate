#!/usr/bin/env bash
# qc-image.sh - QC gate for generated visual assets.
# Compares a candidate image to the operator's reference images against RUBRIC.md,
# using Gemini (vision in, JSON verdict out). PASS copies the candidate into the
# approve dir; FAIL routes it to the reject dir. Nothing is approved unless it passes.
#
# The secret is referenced only by env-var name (GEMINI_API_KEY). It is never printed.

set -euo pipefail

QC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$QC_DIR/../../.." && pwd)"

# Load .env from repo root (same key the image pipeline uses).
if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a; source "$REPO_ROOT/.env"; set +a
fi

MODEL="${QC_MODEL:-gemini-2.5-flash}"
API_BASE="https://generativelanguage.googleapis.com/v1beta/models"
RUBRIC_FILE="$QC_DIR/RUBRIC.md"
APPROVE_DIR="$QC_DIR/../APPROVED"
REJECT_DIR="$QC_DIR/rejected"
REPORT_DIR="$QC_DIR/reports"
declare -a REFS=()
CANDIDATE=""

usage() {
  cat <<EOF
Usage: $(basename "$0") -c CANDIDATE -r REF [-r REF ...] [options]

  -c, --candidate FILE   Image to judge (required)
  -r, --ref FILE         Reference image (repeatable; the target aesthetic)
      --rubric FILE       Rubric markdown (default: qc/RUBRIC.md)
      --approve-dir DIR   Where PASS lands (default: ../APPROVED)
      --reject-dir DIR    Where FAIL lands (default: qc/rejected)
      --report-dir DIR    Where the JSON verdict lands (default: qc/reports)
  -h, --help

Exit 0 = PASS (copied to approve dir). Exit 2 = FAIL. Exit 1 = error.
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--candidate) CANDIDATE="$2"; shift 2;;
    -r|--ref) REFS+=("$2"); shift 2;;
    --rubric) RUBRIC_FILE="$2"; shift 2;;
    --approve-dir) APPROVE_DIR="$2"; shift 2;;
    --reject-dir) REJECT_DIR="$2"; shift 2;;
    --report-dir) REPORT_DIR="$2"; shift 2;;
    -h|--help) usage 0;;
    *) echo "Unknown arg: $1" >&2; usage 1;;
  esac
done

[[ -z "${GEMINI_API_KEY:-}" ]] && { echo "Error: GEMINI_API_KEY not set." >&2; exit 1; }
[[ -z "$CANDIDATE" || ! -f "$CANDIDATE" ]] && { echo "Error: candidate not found: $CANDIDATE" >&2; exit 1; }
[[ ${#REFS[@]} -eq 0 ]] && { echo "Error: at least one -r reference required." >&2; exit 1; }
[[ ! -f "$RUBRIC_FILE" ]] && { echo "Error: rubric not found: $RUBRIC_FILE" >&2; exit 1; }
mkdir -p "$APPROVE_DIR" "$REJECT_DIR" "$REPORT_DIR"

mime_of() {
  local lower
  lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$lower" in
    *.jpg|*.jpeg) echo "image/jpeg";;
    *.webp) echo "image/webp";;
    *) echo "image/png";;
  esac
}

# --- Build the judge payload ---
INSTRUCTION="You are a strict visual QC judge. The FIRST images are REFERENCE images that
define the target aesthetic (the operator's mood board). The LAST image is the CANDIDATE to
judge. Compare the candidate to the references using this rubric, then return ONLY the JSON
object described in the rubric's Output contract. No prose, no markdown fences.

RUBRIC:
$(cat "$RUBRIC_FILE")

Remember: judge the LAST image (the candidate) against the REFERENCE images that came before
it. Return JSON only."

PAYLOAD_FILE=$(mktemp)
REPORT_RAW=$(mktemp)
trap "rm -f '$PAYLOAD_FILE' '$REPORT_RAW'" EXIT

{
  printf '{"contents":[{"parts":['
  printf '{"text":%s}' "$(printf '%s' "$INSTRUCTION" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')"
  for img in "${REFS[@]}"; do
    [[ -f "$img" ]] || { echo "Error: ref not found: $img" >&2; exit 1; }
    printf ',{"inline_data":{"mime_type":"%s","data":"%s"}}' "$(mime_of "$img")" "$(base64 -i "$img")"
  done
  printf ',{"text":"CANDIDATE (judge this one):"}'
  printf ',{"inline_data":{"mime_type":"%s","data":"%s"}}' "$(mime_of "$CANDIDATE")" "$(base64 -i "$CANDIDATE")"
  printf ']}],"generationConfig":{"responseMimeType":"application/json","temperature":0.2}}'
} > "$PAYLOAD_FILE"

echo "QC: $(basename "$CANDIDATE") vs ${#REFS[@]} references  [model: $MODEL]"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "$API_BASE/$MODEL:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d @"$PAYLOAD_FILE")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Error: API HTTP $HTTP_CODE" >&2
  echo "$BODY" | python3 -m json.tool 2>/dev/null | head -20 >&2 || echo "$BODY" >&2
  exit 1
fi

# Extract the model's JSON text verdict.
echo "$BODY" | python3 -c "
import json,sys
d=json.load(sys.stdin)
parts=d.get('candidates',[{}])[0].get('content',{}).get('parts',[])
print(''.join(p.get('text','') for p in parts))
" > "$REPORT_RAW"

# Gate: parse verdict, apply qc_gate.decide, route the file, write the report.
set +e
QC_DIR="$QC_DIR" CAND="$CANDIDATE" APPROVE="$APPROVE_DIR" REJECT="$REJECT_DIR" REPORTD="$REPORT_DIR" \
  python3 "$QC_DIR/qc_route.py" "$REPORT_RAW"
RC=$?
set -e
exit $RC