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
        return "Magic Kingdom"
    if park_id == 5:
        return "EPCOT"
    if park_id == 7:
        return "Hollywood Studios"
    if park_id == 8:
        return "ANIMAL KINGDOM"
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

def _safe_bg(color_hex):
    # Keep backgrounds readable; avoid very light/white tones
    if color_hex == None:
        return "#20252B"
    # Ensure we only operate on strings
    if type(color_hex) != type(""):
        return "#20252B"
    if len(color_hex) != 7 or not color_hex.startswith("#"):
        return "#20252B"
    r = int(color_hex[1:3], 16)
    g = int(color_hex[3:5], 16)
    b = int(color_hex[5:7], 16)
    # Perceived brightness
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    if lum > 210:  # too light
        return "#20252B"
    return color_hex

def _extract_ll_from_park_page(html, park_id, ride_id):
    """
    Scrape LL info from the park-wide queue times page.
    Looks for the reservation_slots link for the specific ride.
    """
    search_str = "/parks/" + str(park_id) + "/rides/" + str(ride_id) + "/reservation_slots"
    pos = html.find(search_str)
    if pos < 0:
        return None
        
    # Find the next span containing the text
    span_start = html.find("<span", pos)
    if span_start < 0:
        return None
    
    text_start = html.find(">", span_start) + 1
    text_end = html.find("</span>", text_start)
    if text_end < 0:
        return None
        
    raw_text = html[text_start:text_end].strip()
    # Handle the arrow symbol and clean up
    # Expecting: "↳ Reservation slots available for 12:15"
    # or "↳ No reservation slots currently available"
    if "Reservation slots available for" in raw_text:
        t_parts = raw_text.split("for")
        time_part = t_parts[-1].strip()
        # time_part is "HH:MM" in 24-hour format
        parts = time_part.split(":")
        if len(parts) == 2:
            h = int(parts[0])
            m = int(parts[1])
            ampm = "AM"
            if h >= 12:
                ampm = "PM"
            h_display = h % 12
            if h_display == 0:
                h_display = 12
            
            res = "LL - " + str(h_display) + ":"
            if m < 10:
                res += "0"
            res += str(m) + " " + ampm
            return res
        return "LL - " + time_part
    if "No reservation slots" in raw_text:
        return "LL SOLD OUT"
        
    return None

def _utc_to_eastern_time(tval):
    """
    Best-effort UTC->Eastern conversion for times like "HH:MM:SS" or
    "MM/DD/YY HH:MM:SS". Date is ignored; we apply a fixed -5h offset
    (Orlando is -5h). If parsing fails, return the original string.
    """
    if tval == None:
        return None
    if type(tval) != type(""):
        return tval
    time_part = tval
    parts = tval.split(" ")
    if len(parts) > 1:
        time_part = parts[-1]
    hhmmss = time_part.split(":")
    if len(hhmmss) < 2:
        return tval
    h_str = hhmmss[0]
    m_str = hhmmss[1]
    s_str = hhmmss[2] if len(hhmmss) > 2 else "0"
    digits = "0123456789"
    for ch in h_str + m_str + s_str:
        if ch not in digits:
            return tval
    h = int(h_str)
    m = int(m_str)
    s = int(s_str)
    
    # -5 hours for Eastern Time (best effort)
    h = (h - 5) % 24
    
    # 12-hour format conversion
    ampm = "AM"
    if h >= 12:
        ampm = "PM"
    h_display = h % 12
    if h_display == 0:
        h_display = 12
        
    res = str(h_display) + ":"
    if m < 10:
        res += "0"
    res += str(m) + " " + ampm
    return res

# Major ride ASCII icons
RIDE_ICONS = {
    11527: ">> ", # TRON
    138:   "** ", # Space Mtn
    137:   "(X) ",# Pirates
    140:   "[!] ",# Mansion
    130:   "^^ ", # Thunder
    110:   "// ", # Everest
    10916: "@@ ", # Guardians
    6369:  "[R] ",# Rise
}

# Per-ride theming: [background, title/header, status, accent]
THEME_BY_RIDE = {
    # Magic Kingdom (6)
    133: ["#f7f0e8", "#5a6fb4", "#c06fa0", "#ffd166"],
    1184: ["#0f1c26", "#c28b57", "#ffae42", "#4fa3c7"],
    248: ["#050910", "#9cf3ff", "#ff5cc7", "#2c6bff"],
    130: ["#2a160c", "#ffb15a", "#e67630", "#8b4513"],
    131: ["#0b0f24", "#8cf1ff", "#c3ff3e", "#9a7bff"],
    13764: ["#103a6b", "#ffe156", "#7ad1ff", "#e94e77"],
    13763: ["#0e1020", "#9bc4ff", "#ffd1ff", "#f5d76e"],
    1214: ["#22130b", "#f2c078", "#e1a35d", "#7a4b2a"],
    132: ["#123c63", "#f6c344", "#f28bbf", "#76d7ff"],
    128: ["#1a100d", "#f5d76e", "#e9b872", "#e07a5f"],
    140: ["#0d0a12", "#d6b87c", "#8b6a3f", "#5a3a7a"],
    134: ["#0f1f18", "#dce775", "#ffb347", "#c41e3a"],
    135: ["#1a1030", "#ff9be0", "#8ef0ff", "#ffe66d"],
    1188: ["#1b120d", "#f4d35e", "#e07a5f", "#bfc0c0"],
    147: ["#0b1f2b", "#7bdff2", "#f4acb7", "#58c4dd"],
    6700: ["#111524", "#ffd166", "#9ad5ff", "#f25f5c"],
    6699: ["#111524", "#ffd166", "#9ad5ff", "#f25f5c"],
    144: ["#111524", "#ffd166", "#9ad5ff", "#f25f5c"],
    145: ["#111524", "#ffd166", "#9ad5ff", "#f25f5c"],
    146: ["#111524", "#ffd166", "#9ad5ff", "#f25f5c"],
    15395: ["#111524", "#ffd166", "#9ad5ff", "#f25f5c"],
    171: ["#0f0d1f", "#8bd3ff", "#ffd166", "#c77dff"],
    125: ["#0b0d21", "#8cf1ff", "#9dff6a", "#ff6fb7"],
    136: ["#0a1326", "#7fc8f8", "#e6d06f", "#8ac926"],
    137: ["#0c161e", "#7fc8ff", "#ffae42", "#f25c54"],
    161: ["#10152a", "#d6c5ff", "#f7d794", "#9ad5ff"],
    129: ["#0f1a14", "#a5f28f", "#f3c969", "#7d5a4f"],
    138: ["#020914", "#8cf1ff", "#ff77ff", "#21c7ff"],
    355: ["#102016", "#a8e6a3", "#e6c88b", "#5d9c59"],
    11527: ["#05060A", "#00E5FF", "#6A00FF", "#00C2FF"],
    126: ["#14264a", "#ffd166", "#ff9f1c", "#8bd3ff"],
    356: ["#0f0e1a", "#c0b283", "#9ad5ff", "#8c1515"],
    141: ["#1a0f16", "#f7c948", "#e76f51", "#4e9fca"],
    142: ["#18100c", "#f6c453", "#ffd588", "#6a994e"],
    13630: ["#0e1b16", "#9ad5a3", "#f1c27d", "#3ba27a"],
    143: ["#0f1115", "#ffd166", "#7ad1ff", "#ff5c5c"],
    1190: ["#0c1a2c", "#7ad1ff", "#21c7ff", "#a0f0ff"],
    127: ["#0a1c2a", "#6ee7ff", "#f2c6de", "#7bdff2"],
    1181: ["#120f15", "#ffcf70", "#a0c4ff", "#c44536"],
    1189: ["#120f15", "#ffcf70", "#a0c4ff", "#c44536"],
    457: ["#0f0f20", "#9ad5ff", "#ffcf70", "#8e44ad"],
    334: ["#0f1f17", "#e6d06f", "#7edfa3", "#e3644a"],

    # EPCOT (5)
    13774: ["#0c1326", "#7ad1ff", "#ffb347", "#21c7ff"],
    13773: ["#16110c", "#f1d9a9", "#9ad5ff", "#b22222"],
    7323: ["#0f1d1a", "#8ee1c7", "#f2c94c", "#56cfe1"],
    13781: ["#0f141e", "#9ad5ff", "#f6d186", "#c77dff"],
    13770: ["#0a1c2f", "#6ee7ff", "#f4a261", "#2a9d8f"],
    829: ["#0e1718", "#a8dadc", "#f1c27d", "#e63946"],
    2495: ["#0d0c1a", "#ffdd73", "#9ad5ff", "#f25c54"],
    2679: ["#0c1527", "#9ad5ff", "#b5e2fa", "#7ad1ff"],
    13772: ["#141018", "#e6d06f", "#a0c4ff", "#d3869b"],
    466: ["#111a1f", "#ffbf69", "#a0e7e5", "#f25c54"],
    10916: ["#050914", "#7ad1ff", "#ff6fb7", "#21c7ff"],
    13767: ["#0d1818", "#a8dadc", "#f6d186", "#5fa8d3"],
    13777: ["#0c0f24", "#9cf3ff", "#ffb347", "#7c83ff"],
    155: ["#160c24", "#d29bff", "#ffdd73", "#7ad1ff"],
    12387: ["#0c1d1f", "#7bdff2", "#ffd166", "#2a9d8f"],
    13778: ["#101828", "#ffcf70", "#9ad5ff", "#ff7f50"],
    156: ["#0f1e14", "#a5f28f", "#f1c27d", "#5fa8d3"],
    6701: ["#0c1622", "#9ad5ff", "#ffe0f7", "#7bdff2"],
    13627: ["#0f0d10", "#ffd166", "#ff6b6b", "#9ad5ff"],
    13780: ["#121018", "#f25c54", "#ffd166", "#7bdff2"],
    158: ["#0b0f16", "#ff6f61", "#ffd166", "#21c7ff"],
    13779: ["#0d0c18", "#f1d9a9", "#9ad5ff", "#c77dff"],
    13775: ["#081022", "#7ad1ff", "#ffd166", "#00e5ff"],
    10914: ["#0f121c", "#9ad5ff", "#f6d186", "#f28bbf"],
    10915: ["#0f121c", "#9ad5ff", "#f6d186", "#f28bbf"],
    13782: ["#0a1d29", "#6ee7ff", "#f1c27d", "#2a9d8f"],
    151: ["#0c1824", "#8bd3ff", "#ffd166", "#7ad1ff"],
    159: ["#0d0f1a", "#cfd8ff", "#8ad1ff", "#7c83ff"],
    13776: ["#141013", "#e6d06f", "#b8c1ec", "#c77dff"],
    160: ["#0f1115", "#7ad1ff", "#ffd166", "#21c7ff"],
    10900: ["#0f1115", "#7ad1ff", "#ffd166", "#21c7ff"],
    153: ["#0a1c2a", "#6ee7ff", "#f6d186", "#00c2ff"],
    152: ["#0b1f2b", "#7bdff2", "#f1c27d", "#4fc3f7"],

    # Hollywood Studios (7)
    5477: ["#0d1022", "#9dff6a", "#7ad1ff", "#ff80ab"],
    1176: ["#1a0f14", "#f4c2c2", "#ffd166", "#c77dff"],
    1174: ["#0c1426", "#9ad5ff", "#b5e2fa", "#7ad1ff"],
    6702: ["#1a120c", "#f1c27d", "#ffae42", "#3ba27a"],
    12430: ["#0b1f2b", "#7bdff2", "#f4acb7", "#58c4dd"],
    6704: ["#1a0f12", "#ffd166", "#9ad5ff", "#e63946"],
    12425: ["#0f0d16", "#ffd166", "#9ad5ff", "#ef476f"],
    6703: ["#0c1422", "#9ad5ff", "#7ad1ff", "#ff6fb7"],
    15402: ["#0c1422", "#9ad5ff", "#7ad1ff", "#ff6fb7"],
    6361: ["#0f0d10", "#ffd166", "#ff6b6b", "#9ad5ff"],
    6368: ["#050910", "#9ad5ff", "#ffd166", "#e0aaff"],
    10902: ["#050910", "#9ad5ff", "#ffd166", "#e0aaff"],
    119: ["#0a0d1a", "#9cf3ff", "#ff6fb7", "#21c7ff"],
    10901: ["#0a0d1a", "#9cf3ff", "#ff6fb7", "#21c7ff"],
    5476: ["#101820", "#ffd166", "#7ad1ff", "#ff6b6b"],
    120: ["#050910", "#7ad1ff", "#ffd166", "#21c7ff"],
    6369: ["#06080e", "#b0bec5", "#ff5c5c", "#ffd166"],
    14531: ["#06080e", "#b0bec5", "#ff5c5c", "#ffd166"],
    14859: ["#0b1f2b", "#7bdff2", "#f4acb7", "#58c4dd"],
    123: ["#0d0a12", "#d6b87c", "#9ad5ff", "#8e44ad"],
    117: ["#0f141f", "#ffd166", "#7ad1ff", "#ef476f"],
    7333: ["#0f0d10", "#ffd166", "#ff9f1c", "#9ad5ff"],
    5145: ["#0f0d10", "#ffd166", "#9ad5ff", "#8c1515"],

    # Animal Kingdom (8)
    13807: ["#0f1b14", "#a5d6a7", "#f1c27d", "#66bb6a"],
    4439: ["#081625", "#7ad1ff", "#c3ff9b", "#9a7bff"],
    13806: ["#0e1a14", "#a5f28f", "#f1c27d", "#5fa8d3"],
    13811: ["#0e1a14", "#a5f28f", "#f1c27d", "#5fa8d3"],
    13812: ["#0e1a14", "#a5f28f", "#f1c27d", "#5fa8d3"],
    13751: ["#0e1a14", "#a5f28f", "#f1c27d", "#5fa8d3"],
    13808: ["#0e1a14", "#a5f28f", "#f1c27d", "#5fa8d3"],
    111: ["#1a120c", "#f1c27d", "#ff6f61", "#7ad1ff"],
    13809: ["#141015", "#d6b87c", "#f1c27d", "#7d5a4f"],
    110: ["#0a1a24", "#8bd3ff", "#ffd166", "#f25c54"],
    14533: ["#0a1a24", "#8bd3ff", "#ffd166", "#f25c54"],
    10921: ["#0f1824", "#8bd3ff", "#ffd166", "#7ad1ff"],
    657: ["#1a120c", "#f7c948", "#e76f51", "#9ad5ff"],
    10920: ["#0a1c2a", "#6ee7ff", "#f6d186", "#00c2ff"],
    651: ["#0f1f17", "#a8e6a3", "#e6c88b", "#5d9c59"],
    112: ["#0c1818", "#7ad1ff", "#ffd166", "#2a9d8f"],
    113: ["#1a120c", "#f1c27d", "#a5d6a7", "#c97b3f"],
    116: ["#0f1a14", "#ffd166", "#9ad5ff", "#66bb6a"],
    12451: ["#0c1d1f", "#7bdff2", "#ffd166", "#2a9d8f"],
    4438: ["#081625", "#7ad1ff", "#c3ff9b", "#9a7bff"],
    6680: ["#0f141f", "#ffd166", "#9ad5ff", "#66bb6a"],
    655: ["#120f15", "#ffcf70", "#a0c4ff", "#c44536"],
    14943: ["#0f1b18", "#9ad5ff", "#f1c27d", "#66bb6a"],
}

PARK_FALLBACK = {
    6: ["#0A0C12", "#00E5FF", "#FFD700", "#6A00FF"],
    5: ["#0D1020", "#8AE0FF", "#FF7B00", "#7CFFEA"],
    7: ["#0B0A11", "#FFD54F", "#90CAF9", "#EF5350"],
    8: ["#0B120C", "#A5D6A7", "#FFB74D", "#66BB6A"],
}

def _theme_for_ride(ride_id, park_id):
    if ride_id != None and ride_id in THEME_BY_RIDE:
        return THEME_BY_RIDE[ride_id]
    if park_id in PARK_FALLBACK:
        return PARK_FALLBACK[park_id]
    return ["#05060A", "#00E5FF", "#FFD700", "#7CFFEA"]

def main(config):
    park_id = DEFAULT_PARK_ID
    ride_id = DEFAULT_RIDE_ID
    if config != None:
        if "park_id" in config:
            park_id = int(str(config["park_id"]))
        if "ride_id" in config:
            ride_id = int(str(config["ride_id"]))

    theme_bg, theme_title, theme_status, theme_accent = _theme_for_ride(ride_id, park_id)
    theme_bg = _safe_bg(theme_bg)
    park_code = _park_code(park_id)

    # Fetch queue times
    resp = http.get("https://queue-times.com/parks/" + str(park_id) + "/queue_times.json")
    data = json.decode(resp.body())
    if data == None:
        return render.Root(child=render.Text(content="API ERROR", color="#FF0000"))

    # Fetch Lightning Lane info from the park-wide queue times page
    # This page explicitly lists available slots like "↳ Reservation slots available for 12:15"
    ll_text = park_code
    ll_color = theme_accent
    ll_urls = [
        "https://queue-times.com/parks/" + str(park_id) + "/queue_times",
        "https://queue-times.com/en-US/parks/" + str(park_id) + "/queue_times",
    ]
    ll_headers = {
        "User-Agent": "pixlet-tidbyt-wdw/1.0 (+queue-times LL fetch)",
        "Accept-Language": "en-US,en;q=0.8",
    }
    for url in ll_urls:
        ll_resp = http.get(url, headers=ll_headers)
        ll_body = ll_resp.body()
        
        # Try scraping the park page for the ride's LL status
        scraped_ll = _extract_ll_from_park_page(ll_body, park_id, ride_id)
        if scraped_ll:
            ll_text = scraped_ll
            break

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

    status_color = theme_status
    # Determine status and badge
    if park_closed:
        status_line = "PARK CLOSED"
        badge = render.Text(content="CLOSED", color=theme_accent)
        ride_name = "PARK"
        status_color = theme_status
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
        # Refresh theme for the resolved ride in case ride_id was defaulted
        theme_bg, theme_title, theme_status, theme_accent = _theme_for_ride(ride_id, park_id)
        theme_bg = _safe_bg(theme_bg)
        # If ride is closed, show DOWN even if wait_time is 0 or missing
        if not is_open:
            status_line = "DOWN"
            status_color = theme_status
            badge = render.Text(content="DOWN", color=theme_accent)
        else:
            if wt == None:
                status_line = "DOWN"
                status_color = theme_status
            elif wt > 0:
                status_line = str(wt) + " MIN"
                status_color = _wait_color(wt)
            else:
                status_line = "0 MIN"
                status_color = _wait_color(0)
            badge = render.Text(content="OPEN", color=theme_accent)

    # Show full ride name (no badge)
    ride_icon = RIDE_ICONS.get(ride_id, "")
    header_name = ride_icon + (ride_name_full if (ride_name_full != None) else ride_name)
    header = render.Row(
        expanded=True,
        main_align="start",
        children=[render.Text(content=header_name, color=theme_title)],
    )
    # Center: single line status
    center_color = status_color
    center = render.Text(content=status_line, color=center_color, font="tb-8")

    # Simple text marquee helper
    def _marquee_frames(text, width_chars, color):
        padded = text + "   " + text
        n = len(text) + 3
        frames = []
        for i in range(n):
            window = padded[i:i+width_chars]
            frames.append(window)
        return frames

    # Line 3: Lightning Lane status/small text (static tom-thumb)
    ll_line = render.Text(content=ll_text, color=ll_color, font="tom-thumb")

    # No footer on main display; attribution should move to settings UI when added

    header_frames = _marquee_frames(header_name, 20, theme_title) # Increased from 16 to 20 to use more width
    widgets = []
    dwell = 4  # slower title animation
    
    # Hold first frame for 1.5 seconds at 50ms per frame
    # 1.5 / 0.05 = 30 frames total for the start
    initial_hold = 30
    
    frame_count = len(header_frames)
    for i in range(frame_count):
        htxt = header_frames[i]

        header_dyn = render.Row(
            expanded=True,
            main_align="start",
            children=[render.Text(content=htxt, color=theme_title, font="tom-thumb")],
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
            color=theme_bg,
            child=ui,
        )
        
        # Apply hold for first frame, otherwise use dwell
        count = dwell
        if i == 0:
            count = initial_hold
            
        for _ in range(count):
            widgets.append(frame_widget)

    return render.Root(child=render.Animation(children=widgets))
