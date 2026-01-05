#!/usr/bin/env bash
set -euo pipefail

# Render every WDW park hours listed in PARKS.
# GIFs with magnify=10 into ./park_hours/test/<park>.gif

cd "$(dirname "$0")"
OUT_DIR="./test"
mkdir -p "$OUT_DIR"

# Try to use the combined CA bundle if it exists to fix cert issues
REPO_ROOT="$(cd .. && pwd)"
if [ -f "${REPO_ROOT}/combined-ca-bundle.pem" ]; then
  export SSL_CERT_FILE="${REPO_ROOT}/combined-ca-bundle.pem"
fi

PIXLET_BIN="${PIXLET_BIN:-pixlet}"
MAG=10

# Fetch data once to avoid cert issues inside pixlet if possible, or just use curl -k
echo "Fetching calendar data..."
DATE_STR=$(date +%Y-%m-%d)
MOCK_DATA=$(curl -sk -H "User-Agent: Mozilla/5.0" "https://disneyworld.disney.go.com/finder/api/v1/explorer-service/calendar/wdw/80007798;entityType=destination/${DATE_STR}/day")

if ! command -v "$PIXLET_BIN" >/dev/null 2>&1; then
  echo "pixlet not found (set PIXLET_BIN if needed)" >&2
  exit 1
fi

# park_id "Park Name"
PARKS=(
  "6 Magic_Kingdom"
  "5 EPCOT"
  "7 Hollywood_Studios"
  "8 Animal_Kingdom"
)

for entry in "${PARKS[@]}"; do
  park_id=$(awk '{print $1}' <<< "$entry")
  park_name=$(awk '{print $2}' <<< "$entry")
  
  out="${OUT_DIR}/${park_name}.gif"
  echo "Rendering GIF park=${park_id} (${park_name}) -> ${out}"
  "$PIXLET_BIN" render park_hours.star park_id="${park_id}" mock_data="${MOCK_DATA}" --magnify "${MAG}" --gif --output "${out}"
done

