import sys, re

def check_slots(html):
    # Find the start of chart-1 data
    marker = '"chart-1"'
    start_idx = html.find(marker)
    if start_idx == -1:
        return "chart-1 not found"

    # Extract a large chunk around chart-1
    chunk = html[start_idx:start_idx+30000]

    # Look for any series name and its data
    # Series pattern matches: {"name":"Available",...,"data":[[timestamp, value],...]}
    series_pattern = re.compile(r'{"name":"([^"]*)".*?"data":\[(.*?)]}')
    matches = series_pattern.finditer(chunk)

    found_any = False
    results = []
    for match in matches:
        sname = match.group(1)
        sdata = match.group(2)
        # Look for any non-zero value in this series
        # Entry pattern: ["timestamp", value]
        entries = re.findall(r'\["([^"]*)",\s*([^]]*)\]', sdata)
        for ts, val in entries:
            v = val.strip().replace('"', '')
            try:
                # If it's a number like 1 or "1.0", it's available
                fv = float(v)
                if fv > 0:
                    results.append(f"AVAILABLE in series '{sname}': {ts} (Value: {fv})")
                    found_any = True
            except:
                pass

    if not found_any:
        return "No non-zero values found in any series in chart-1."
    return "\n".join(results)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 check_slots.py <html_file>")
        sys.exit(1)
    with open(sys.argv[1], 'r', encoding='utf-8', errors='ignore') as f:
        print(check_slots(f.read()))

