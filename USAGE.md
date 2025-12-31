# Disney World Wait Times - Usage Guide

## Quick Start

### Basic Usage (Default: TRON)
```bash
./render.sh --magnify 10
```

### Track a Different Ride

Use config parameters to specify park and ride:

```bash
pixlet render tron_wait.star park_id=6 ride_id=75 --magnify 10
```

Or with the wrapper script:
```bash
SSL_CERT_FILE=$(pwd)/combined-ca-bundle.pem pixlet render tron_wait.star park_id=6 ride_id=75 --magnify 10
```

## Finding Park and Ride IDs

### Option 1: Use the Helper Script

```bash
# List all Disney World parks
python3 list_parks.py

# List all rides for a specific park (e.g., Magic Kingdom = 6)
python3 list_parks.py 6
```

### Option 2: Use the API Directly

1. **Get Parks:**
   ```bash
   curl https://queue-times.com/parks.json | python3 -m json.tool | grep -A 2 "Magic Kingdom\|EPCOT\|Hollywood\|Animal Kingdom"
   ```

2. **Get Rides for a Park:**
   ```bash
   curl https://queue-times.com/parks/6/queue_times.json | python3 -m json.tool | grep -A 5 "name\|id" | head -50
   ```

## Common Disney World Parks

- **Magic Kingdom**: `park_id=6`
- **EPCOT**: `park_id=7` (verify with API)
- **Hollywood Studios**: `park_id=8` (verify with API)
- **Animal Kingdom**: `park_id=9` (verify with API)

## Popular Rides

### Magic Kingdom (park_id=6)
- TRON Lightcycle / Run: `ride_id=11527`
- Space Mountain: `ride_id=75` (verify)
- Big Thunder Mountain: `ride_id=76` (verify)
- Haunted Mansion: `ride_id=78` (verify)
- Pirates of the Caribbean: `ride_id=79` (verify)

### Finding Other Rides
Use `list_parks.py` to find the exact ride IDs for any attraction.

## Design Themes

The app automatically selects a design theme based on the ride name:

- **TRON**: Neon cyan/blue grid theme
- **Space Mountain**: Space theme with cyan/magenta
- **Haunted Mansion**: Gold/black theme
- **Big Thunder Mountain**: Orange/brown theme
- **Pirates**: Blue/orange nautical theme
- **Park Defaults**: Each park has its own default theme

## Examples

### Track Space Mountain
```bash
pixlet render tron_wait.star park_id=6 ride_id=75 --magnify 10
```

### Track Haunted Mansion
```bash
pixlet render tron_wait.star park_id=6 ride_id=78 --magnify 10
```

### Track EPCOT Ride (example)
```bash
# First find the ride ID:
python3 list_parks.py 7

# Then render:
pixlet render tron_wait.star park_id=7 ride_id=<ride_id> --magnify 10
```

## Troubleshooting

### Wait Time Not Showing

The wait_time display has been fixed. If you still see "OPEN" when there's a wait time:

1. **Check the API directly:**
   ```bash
   curl https://queue-times.com/parks/6/queue_times.json | python3 -c "import json, sys; data=json.load(sys.stdin); tron=[r for land in data.get('lands',[]) for r in land.get('rides',[]) if r.get('id')==11527][0]; print('wait_time:', tron.get('wait_time'))"
   ```

2. **Clear cache and re-render:**
   ```bash
   rm -f tron_wait.webp
   ./render.sh --magnify 10
   ```

3. **Check if the ride is actually open:**
   - The app shows "OPEN" when wait_time is 0 or None
   - It shows "DOWN" when the ride is closed
   - It shows "X MIN" when there's an actual wait time

### Certificate Errors

See the main README.md for certificate setup instructions.

## Advanced: Creating Ride-Specific Files

For easier use, you can create separate files for different rides:

```bash
# Copy the template
cp tron_wait.star space_mountain.star

# Edit space_mountain.star and change:
# DEFAULT_PARK_ID = 6
# DEFAULT_RIDE_ID = 75
# RIDE_NAME = "SPACE MTN"
```

Then render with:
```bash
./render.sh space_mountain.star --magnify 10
```

