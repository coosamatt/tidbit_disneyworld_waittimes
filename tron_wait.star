load("render.star", "render")
load("http.star", "http")
load("encoding/json.star", "json")

# Minimal reset: show wait time, or DOWN/PARK CLOSED/NOT FOUND. No “OPEN” text ever.
DEFAULT_PARK_ID = 6
DEFAULT_RIDE_ID = 11527

def _short_name(name, park_id):
    # Special-case TRON
    if name != None and "TRON" in name:
        return "TRON"
    if name == None:
        return "RIDE"
    # Prefer first word; truncate to 8 chars
    first = name.split(" ")[0]
    short = first[:8]
    if len(first) > 8:
        short = first[:7] + "…"
    return short

def _park_code(park_id):
    if park_id == 6:
        return "MK"
    if park_id == 7:
        return "EPCOT"
    if park_id == 8:
        return "HS"
    if park_id == 9:
        return "AK"
    return "WDW"

def _wait_color(wait_time):
    # Color code based on rough thresholds (minutes)
    if wait_time == None:
        return "#FFA500"  # orange for unknown/down
    if wait_time <= 20:
        return "#00FF7F"  # green
    if wait_time <= 45:
        return "#FFD700"  # gold
    return "#FF4500"     # red

def main(config):
    park_id = DEFAULT_PARK_ID
    ride_id = DEFAULT_RIDE_ID
    if config != None:
        if "park_id" in config:
            park_id = int(str(config["park_id"]))
        if "ride_id" in config:
            ride_id = int(str(config["ride_id"]))

    # Fetch queue times
    resp = http.get("https://queue-times.com/parks/%d/queue_times.json" % park_id)
    data = json.decode(resp.body())
    if data == None:
        return render.Root(child=render.Text(content="API ERROR", color="#FF0000"))

    # Fetch reservation slots (Lightning Lane) - best effort
    ll_text = "LL SOLD OUT"
    ll_color = "#7CFFEA"
    ll_resp = http.get("https://queue-times.com/en-US/parks/%d/rides/%d/reservation_slots" % (park_id, ride_id))
    ll_body = ll_resp.body()
    ll_body_trim = ll_body.lstrip()
    if ll_body_trim.startswith("{") or ll_body_trim.startswith("["):
        ll_data = json.decode(ll_body_trim)
        slots = []
        if type(ll_data) == "list":
            slots = ll_data
        elif type(ll_data) == "dict":
            slots = ll_data.get("slots", [])
        if len(slots) > 0:
            first = slots[0]
            tval = ""
            if type(first) == "dict":
                tval = first.get("time", "") or first.get("start_time", "")
            elif type(first) == "string":
                tval = first
            if tval == "":
                tval = "AVAILABLE"
            ll_text = "LL - " + tval
            ll_color = "#00E5FF"

    # Park closed heuristic
    open_count = 0
    total_count = 0
    for land in data.get("lands", []):
        for ride_obj in land.get("rides", []):
            total_count += 1
            if ride_obj.get("is_open"):
                open_count += 1
    park_closed = (open_count == 0 and total_count > 0)

    # Find ride
    ride = None
    for land in data.get("lands", []):
        for ride_obj in land.get("rides", []):
            if ride_obj.get("id") == ride_id:
                ride = ride_obj
                break
    if ride == None:
        for ride_obj in data.get("rides", []):
            if ride_obj.get("id") == ride_id:
                ride = ride_obj
                break

    status_color = "#FFFFFF"
    # Determine status and badge
    if park_closed:
        status_line = "PARK CLOSED"
        badge = render.Text(content="CLOSED", color="#00E5FF")
        ride_name = "PARK"
        status_color = "#00E5FF"
    elif ride == None:
        status_line = "NOT FOUND"
        badge = render.Text(content="ERR", color="#FF0000")
        ride_name = "NOT FOUND"
        status_color = "#FFA500"
    else:
        ride_name_full = ride.get("name", "RIDE")
        ride_name = _short_name(ride_name_full, park_id)
        wt = ride.get("wait_time")
        is_open = ride.get("is_open", False)
        # If ride is closed, show DOWN even if wait_time is 0 or missing
        if not is_open:
            status_line = "DOWN"
            status_color = "#FFA500"
            badge = render.Text(content="DOWN", color="#6A00FF")
        else:
            if wt == None:
                status_line = "DOWN"
                status_color = "#FFA500"
            elif wt > 0:
                status_line = str(wt) + " MIN"
                status_color = _wait_color(wt)
            else:
                status_line = "0 MIN"
                status_color = _wait_color(0)
            badge = render.Text(content="OPEN", color="#00E5FF")

    # Show full ride name (no badge)
    header_name = ride_name_full if (ride_name_full != None) else ride_name
    header = render.Row(
        expanded=True,
        main_align="start",
        children=[render.Text(content=header_name, color="#00E5FF")],
    )
    # Center: single line status
    center_color = status_color
    center = render.Text(content=status_line, color=center_color)

    # Line 3: Lightning Lane status/small text
    ll_line = render.Text(content=ll_text, color=ll_color)

    # No footer on main display; attribution should move to settings UI when added

    # Simple text marquee for header to show full text
    def _marquee_frames(text, width_chars, color):
        padded = text + "   " + text
        n = len(text) + 3
        frames = []
        for i in range(n):
            window = padded[i:i+width_chars]
            frames.append(window)
        return frames

    header_frames = _marquee_frames(header_name, 12, "#00E5FF")
    widgets = []
    dwell = 4  # slower title animation
    frame_count = len(header_frames)
    for i in range(frame_count):
        htxt = header_frames[i % len(header_frames)]

        header_dyn = render.Row(
            expanded=True,
            main_align="start",
            children=[render.Text(content=htxt, color="#00E5FF")],
        )
        ui = render.Box(
            padding=2,
            child=render.Column(
                expanded=True,
                main_align="space_between",
                children=[header_dyn, center, ll_line],
            ),
        )

        frame_widget = render.Box(
            width=64,
            height=32,
            color="#05060A",
            child=ui,
        )
        # Add dwell duplicates to slow the animation
        for _ in range(dwell):
            widgets.append(frame_widget)

    return render.Root(child=render.Animation(children=widgets))
