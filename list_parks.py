#!/usr/bin/env python3
"""Helper script to list Disney World parks and their rides."""

import json
import sys
import urllib.request
import ssl

def get_parks():
    """Fetch and return list of parks."""
    url = "https://queue-times.com/parks.json"
    context = ssl.create_default_context()
    
    with urllib.request.urlopen(url, context=context) as response:
        data = json.loads(response.read())
    
    # Filter for Disney World parks
    disney_parks = []
    for park in data:
        name = park.get('name', '')
        if any(x in name for x in ['Walt Disney', 'Magic Kingdom', 'EPCOT', 'Hollywood', 'Animal Kingdom']):
            disney_parks.append(park)
    
    return disney_parks

def get_rides(park_id):
    """Fetch and return list of rides for a park."""
    url = f"https://queue-times.com/parks/{park_id}/queue_times.json"
    context = ssl.create_default_context()
    
    try:
        with urllib.request.urlopen(url, context=context) as response:
            data = json.loads(response.read())
        
        rides = []
        # Collect rides from lands
        for land in data.get('lands', []):
            for ride in land.get('rides', []):
                rides.append(ride)
        # Collect rides from top-level
        for ride in data.get('rides', []):
            rides.append(ride)
        
        return rides
    except Exception as e:
        print(f"Error fetching rides: {e}", file=sys.stderr)
        return []

if __name__ == "__main__":
    if len(sys.argv) > 1:
        # List rides for a specific park
        park_id = int(sys.argv[1])
        rides = get_rides(park_id)
        print(f"\nRides for Park ID {park_id}:")
        print("=" * 60)
        for ride in sorted(rides, key=lambda x: x.get('name', '')):
            ride_id = ride.get('id')
            name = ride.get('name', 'Unknown')
            print(f"  ID {ride_id:6d}: {name}")
    else:
        # List parks
        parks = get_parks()
        print("Walt Disney World Parks:")
        print("=" * 60)
        for park in parks:
            park_id = park.get('id')
            name = park.get('name', 'Unknown')
            print(f"  ID {park_id}: {name}")
        print("\nTo see rides for a park, run:")
        print("  python3 list_parks.py <park_id>")

