#!/usr/bin/env bash
set -euo pipefail

# Render every WDW ride listed in THE_RIDES.
# Default: GIFs with magnify=10 into ./test/<ride>.gif
# Test mode: WEBP (no magnification) into ./test/<ride>.webp and push to device.
#
# Requirements:
# - pixlet installed and on PATH (override via PIXLET_BIN)
# - run from repo root (script does cd to its own dir)
# - MODE=gif (default) or MODE=push
#   * gif  => writes GIFs, magnify=10
#   * push => writes WEBPs, no magnify, then pushes each to device
# - network access to queue-times.com
#
# Usage:
#   chmod +x test.sh
#   ./test.sh                     # GIFs -> ./test/*.gif
#   MODE=push ./test.sh           # WEBPs -> ./test/*.webp and push each
#   OUT_DIR=/tmp/out ./test.sh    # change output directory
#   PIXLET_BIN=/path/pixlet ...   # custom pixlet
#   PUSH_DEVICE=... PUSH_TOKEN=... MODE=push ./test.sh  # override device/token

cd "$(dirname "$0")"
REPO_ROOT="$(pwd)"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/test}"
mkdir -p "$OUT_DIR"

PIXLET_BIN="${PIXLET_BIN:-pixlet}"
MAG=10
MODE="${MODE:-gif}"   # gif | push
PUSH_DEVICE="${PUSH_DEVICE:-heedlessly-conscious-heroic-raptor-8b5}"
PUSH_TOKEN="${PUSH_TOKEN:-eyJhbGciOiJFUzI1NiIsImtpZCI6IjY1YzFhMmUzNzJjZjljMTQ1MTQyNzk5ODZhMzYyNmQ1Y2QzNTI0N2IiLCJ0eXAiOiJKV1QifQ.eyJhdWQiOiJodHRwczovL2FwaS50aWRieXQuY29tIiwiZXhwIjozMzQ0MDA0NDc5LCJpYXQiOjE3NjcyMDQ0NzksImlzcyI6Imh0dHBzOi8vYXBpLnRpZGJ5dC5jb20iLCJzdWIiOiJYWGlEZUd5RlBDYzdZTTdua0pMaTlUTmlQYzYyIiwic2NvcGUiOiJkZXZpY2UiLCJkZXZpY2UiOiJoZWVkbGVzc2x5LWNvbnNjaW91cy1oZXJvaWMtcmFwdG9yLThiNSJ9.4l8NqEQOSkvPou2wWrKXvGzFOceXVb_XFoTe2M0sxADysRKu-WWYQNp9Qfj9X2bheKxZbZemMHbnqw6tsS3JDQ}"

if ! command -v "$PIXLET_BIN" >/dev/null 2>&1; then
  echo "pixlet not found (set PIXLET_BIN if needed)" >&2
  exit 1
fi

# park_id ride_id "Ride Name"
THE_RIDES=(
  # Magic Kingdom (6)
  "6 133 it's a small world"
  "6 1184 A Pirate's Adventure ~ Treasures of the Seven Seas"
  "6 248 Astro Orbiter"
  "6 130 Big Thunder Mountain Railroad"
  "6 131 Buzz Lightyear's Space Ranger Spin"
  "6 13764 Casey Jr. Splash 'N' Soak Station"
  "6 13763 Cinderella Castle"
  "6 1214 Country Bear Musical Jamboree"
  "6 132 Dumbo the Flying Elephant"
  "6 128 Enchanted Tales with Belle"
  "6 140 Haunted Mansion"
  "6 134 Jingle Cruise"
  "6 135 Mad Tea Party"
  "6 1188 Main Street Vehicles"
  "6 147 Meet Ariel at Her Grotto"
  "6 6700 Meet Cinderella and a Visiting Princess at Princess Fairytale Hall"
  "6 144 Meet Daring Disney Pals as Circus Stars at Pete's Silly Sideshow"
  "6 145 Meet Dashing Disney Pals as Circus Stars at Pete's Silly Sideshow"
  "6 146 Meet Mickey at Town Square Theater"
  "6 6699 Meet Princess Tiana and a Visiting Princess at Princess Fairytale Hall"
  "6 15395 Meet Santa Jack and Sally at Town Square Theater at Mickey's Very Merry Christmas Party"
  "6 171 Mickey's PhilharMagic"
  "6 125 Monsters Inc. Laugh Floor"
  "6 136 Peter Pan's Flight"
  "6 137 Pirates of the Caribbean"
  "6 161 Prince Charming Regal Carrousel"
  "6 129 Seven Dwarfs Mine Train"
  "6 138 Space Mountain"
  "6 355 Swiss Family Treehouse"
  "6 11527 TRON Lightcycle / Run"
  "6 126 The Barnstormer"
  "6 356 The Hall of Presidents"
  "6 141 The Magic Carpets of Aladdin"
  "6 142 The Many Adventures of Winnie the Pooh"
  "6 13630 Tiana's Bayou Adventure"
  "6 143 Tomorrowland Speedway"
  "6 1190 Tomorrowland Transit Authority PeopleMover"
  "6 127 Under the Sea - Journey of The Little Mermaid"
  "6 1181 Walt Disney World Railroad - Fantasyland"
  "6 1189 Walt Disney World Railroad - Main Street, U.S.A."
  "6 457 Walt Disney's Carousel of Progress"
  "6 334 Walt Disney's Enchanted Tiki Room"

  # EPCOT (5)
  "5 13774 Advanced Training Lab"
  "5 13773 American Heritage Gallery"
  "5 7323 Awesome Planet"
  "5 13781 Bijutsu-kan Gallery"
  "5 13770 Bruce's Shark World"
  "5 829 Canada Far and Wide in Circle-Vision 360"
  "5 2495 Disney and Pixar Short Film Festival"
  "5 2679 Frozen Ever After"
  "5 13772 Gallery of Arts and History"
  "5 466 Gran Fiesta Tour Starring The Three Caballeros"
  "5 10916 Guardians of the Galaxy: Cosmic Rewind"
  "5 13767 House of the Whispering Willows"
  "5 13777 ImageWorks - The \"What If\" Labs"
  "5 155 Journey Into Imagination With Figment"
  "5 12387 Journey of Water, Inspired by Moana"
  "5 13778 Kidcot Fun Stops"
  "5 156 Living with the Land"
  "5 6701 Meet Anna and Elsa at Royal Sommerhus"
  "5 13627 Meet Beloved Disney Pals at Mickey & Friends"
  "5 13780 Mexico Folk Art Gallery"
  "5 158 Mission: SPACE"
  "5 13779 Palais du Cinéma"
  "5 13775 Project Tomorrow: Inventing the Wonders of the Future"
  "5 10914 Remy's Ratatouille Adventure"
  "5 10915 Remy's Ratatouille Adventure Single Rider"
  "5 13782 SeaBase Aquarium"
  "5 151 Soarin' Around the World"
  "5 159 Spaceship Earth"
  "5 13776 Stave Church Gallery"
  "5 160 Test Track"
  "5 10900 Test Track Presented by Chevrolet Single Rider"
  "5 153 The Seas with Nemo & Friends"
  "5 152 Turtle Talk With Crush"

  # Hollywood Studios (7)
  "7 5477 Alien Swirling Saucers"
  "7 1176 Beauty and the Beast – Live on Stage"
  "7 1174 For the First Time in Forever: A Frozen Sing-Along Celebration"
  "7 6702 Indiana Jones™ Epic Stunt Spectacular!"
  "7 12430 Meet Ariel at Walt Disney Presents"
  "7 6704 Meet Disney Stars at Red Carpet Dreams"
  "7 12425 Meet Edna Mode at the Edna Mode Experience"
  "7 6703 Meet Olaf at Celebrity Spotlight"
  "7 15402 Meet Stitch at Celebrity Spotlight at Disney Jollywood Nights"
  "7 6361 Mickey & Minnie's Runaway Railway"
  "7 6368 Millennium Falcon: Smugglers Run"
  "7 10902 Millennium Falcon: Smugglers Run Single Rider"
  "7 119 Rock 'n' Roller Coaster Starring Aerosmith"
  "7 10901 Rock 'n' Roller Coaster Starring Aerosmith Single Rider"
  "7 5476 Slinky Dog Dash"
  "7 120 Star Tours – The Adventures Continue"
  "7 6369 Star Wars: Rise of the Resistance"
  "7 14531 Star Wars: Rise of the Resistance Single Rider"
  "7 14859 The Little Mermaid – A Musical Adventure – New!"
  "7 123 The Twilight Zone Tower of Terror™"
  "7 117 Toy Story Mania!"
  "7 7333 Vacation Fun - An Original Animated Short with Mickey & Minnie"
  "7 5145 Walt Disney Presents"

  # Animal Kingdom (8)
  "8 13807 Affection Section"
  "8 4439 Avatar Flight of Passage"
  "8 13806 Conservation Station"
  "8 111 DINOSAUR"
  "8 13809 Dino-Sue"
  "8 13811 Discovery Island Trails"
  "8 110 Expedition Everest - Legend of the Forbidden Mountain"
  "8 14533 Expedition Everest - Legend of the Forbidden Mountain Single Rider"
  "8 10921 Feathered Friends in Flight!"
  "8 657 Festival of the Lion King"
  "8 10920 Finding Nemo: The Big Blue... and Beyond!"
  "8 651 Gorilla Falls Exploration Trail"
  "8 112 Kali River Rapids"
  "8 113 Kilimanjaro Safaris"
  "8 116 Meet Favorite Disney Pals at Adventurers Outpost"
  "8 12451 Meet Moana at Character Landing"
  "8 4438 Na'vi River Journey"
  "8 6680 The Animation Experience at Conservation Station"
  "8 13812 The Oasis Exhibits"
  "8 13751 Tree of Life"
  "8 13808 Wilderness Explorers"
  "8 655 Wildlife Express Train"
  "8 14943 Zootopia: Better Zoogether!"
)

slugify() {
  # lowercase, replace non-alnum with underscores, collapse repeats, trim edges
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | \
    sed -e 's/[^a-z0-9]/_/g' -e 's/__*/_/g' -e 's/^_//' -e 's/_$//'
}

for entry in "${THE_RIDES[@]}"; do
  park_id=$(awk '{print $1}' <<< "$entry")
  ride_id=$(awk '{print $2}' <<< "$entry")
  ride_name="${entry#* * }"

  slug=$(slugify "$ride_name")
  if [[ "$MODE" == "gif" ]]; then
    out="${OUT_DIR}/${slug}.gif"
    echo "Rendering GIF park=${park_id} ride=${ride_id} (${ride_name}) -> ${out}"
    "$PIXLET_BIN" render tron_wait.star park_id="${park_id}" ride_id="${ride_id}" --magnify "${MAG}" --gif --output "${out}"
  elif [[ "$MODE" == "push" ]]; then
    out="${OUT_DIR}/${slug}.webp"
    echo "Rendering WEBP park=${park_id} ride=${ride_id} (${ride_name}) -> ${out}"
    "$PIXLET_BIN" render tron_wait.star park_id="${park_id}" ride_id="${ride_id}" --output "${out}"
    echo "Pushing to device ${PUSH_DEVICE} -> ${out}"
    "$PIXLET_BIN" push "${PUSH_DEVICE}" "${out}" --api-token "${PUSH_TOKEN}"
    echo "[$(date +%H:%M:%S)] Waiting 5 seconds..."
    sleep 5
  else
    echo "Unknown MODE=${MODE}; use gif or push" >&2
    exit 1
  fi
done

