# Tidbyt TRON Wait Time (Queue-Times)

A Pixlet (Tidbyt) applet that displays the current status / wait time for **TRON Lightcycle / Run** at **Walt Disney World's Magic Kingdom** using the Queue-Times API.

It handles:
- **OPEN** with wait time (minutes)
- **DOWN** when the ride is not open
- **PARK CLOSED** (heuristic: if *no* rides are open in the Magic Kingdom queue times feed)

It also includes a small retro 80's TRON-style neon grid background.

> Note: Queue-Times requests that free real-time API users display attribution (“Powered by Queue-Times.com”). This applet includes that in the footer.

---

## Prereqs (macOS)

### 1) Install Pixlet
Pixlet is Tidbyt’s CLI for developing applets.

- Install via Homebrew (recommended):

```bash
brew install tidbyt/tidbyt/pixlet
```

If you don’t have Homebrew:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2) Verify
```bash
pixlet version
```

---

## Run locally (render a preview)

From this folder:

```bash
pixlet render tron_wait.star --magnify 10
```

Outputs:
- `tron_wait.webp`

Open it:
```bash
open tron_wait.webp
```

---

## Customize (optional)

### Change the Ride Being Tracked

In `tron_wait.star`, at the top of the file, you can change:

```python
PARK_ID = 6  # Magic Kingdom
RIDE_ID = 11527  # TRON Lightcycle / Run
RIDE_NAME = "TRON"  # Short name to display
PARK_NAME = "MK"  # Park abbreviation
```

**To find ride IDs:**
1. Visit https://queue-times.com/parks.json to find park IDs
2. Visit https://queue-times.com/parks/{PARK_ID}/queue_times.json to see all rides for that park
3. Search for your ride and note its `id` field

**Example - Track Space Mountain instead:**
```python
PARK_ID = 6  # Magic Kingdom
RIDE_ID = 75  # Space Mountain
RIDE_NAME = "SPACE MTN"
PARK_NAME = "MK"
```

### Customize Appearance

- **Colors**: Modify the color values in `_get_ride_status()` and `_neon_text()` calls
- **Background**: Edit `_grid_bg()` to change the TRON-style grid
- **Layout**: Adjust padding and spacing in the UI components

---

## Deploy to your Tidbyt

There are a couple common paths:

### A) Private app hosting (recommended for personal use)
Use Tidbyt’s “Private App Hosting” / developer settings in the Tidbyt mobile app to point at your hosted applet output.

Typical approach:
- Host the applet on a small web server (or GitHub Pages / similar)
- Configure the Tidbyt app to load it as a private app

### B) Publish to the community
If you want this publicly available, follow Tidbyt’s community app contribution guidelines and open a PR to `tidbyt/community`.

---

## Troubleshooting

- If the preview renders but your device shows stale data, lower `max_age` (but be kind to the API).
- If it shows "NOT FOUND", Queue-Times may have changed the ride ID/name, or the feed schema changed.

### Certificate Validation Errors

If you encounter TLS certificate verification errors like:
```
Error in get: Get "https://queue-times.com/parks.json": tls: failed to verify certificate
```

**Option 1: Set up certificate truststore (recommended)**
```bash
./setup-certificate.sh
```

This script will:
- Download the queue-times.com certificate
- Add it to your macOS keychain
- Create a combined CA bundle

**Option 2: Update system certificates**
```bash
brew update && brew upgrade
brew reinstall tidbyt/tidbyt/pixlet
```

**Option 3: Patch pixlet (advanced)**
If the above don't work, you may need to modify pixlet's Go source code to disable certificate validation. This requires:
1. Cloning the pixlet repository
2. Modifying the HTTP client to set `InsecureSkipVerify: true` in the TLS config
3. Rebuilding pixlet

**Note:** The certificate is valid (issued by Google Trust Services). The issue is typically with Go's integration with macOS's Security framework or an outdated certificate store.

---

### Disney World Park Hours

In addition to ride wait times, there is a dedicated applet for **Park Hours** in the `./park_hours` folder.

#### Usage:
```bash
pixlet render park_hours/park_hours.star park_id=6
```

#### Batch Test:
```bash
./park_hours/test_hours.sh
```
This generates GIFs for all 4 Walt Disney World parks with their respective themes and background imagery (Castle, Spaceship Earth, Tower of Terror, Tree of Life).

---

## Batch Testing & Device Push

Use `test.sh` to render every WDW ride with the themed palettes.

- Default GIF batch (magnify 10) to `./test`:
  ```bash
  chmod +x test.sh
  ./test.sh
  ```
  Outputs: `test/<ride>.gif`

- Push mode (WEBP, no magnify) and send to device:
  ```bash
  MODE=push ./test.sh
  ```
  Outputs: `test/<ride>.webp` then runs  
  `pixlet push heedlessly-conscious-heroic-raptor-8b5 <file> --api-token <token>`

Variables you can override:
- `PIXLET_BIN` – path to pixlet
- `OUT_DIR` – output directory (default `./test`)
- `MODE` – `gif` (default) or `push`
- `PUSH_DEVICE` – Tidbyt device ID (default: `heedlessly-conscious-heroic-raptor-8b5`)
- `PUSH_TOKEN` – API token for pushes
