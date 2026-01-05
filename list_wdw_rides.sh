#!/usr/bin/env bash
set -euo pipefail

# Lists all ride IDs for Walt Disney World parks using list_parks.py.
# Park IDs (per queue-times.com):
#   Magic Kingdom: 6
#   EPCOT: 5
#   Hollywood Studios: 7
#   Animal Kingdom: 8

cd "$(dirname "$0")"

for id in 6 5 7 8; do
  printf "\n=== Park %s ===\n" "$id"
  python3 list_parks.py "$id"
done

