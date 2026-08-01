import re
from pathlib import Path

def max_table(block_name, txt):
    m = re.search(rf"{block_name}\s*\(delay_template_7x7\)\s*\{{(.*?)\n\s*\}}", txt, re.S)
    if not m:
        return None
    nums = [float(x) for x in re.findall(r'[-+]?\d*\.\d+|\d+', m.group(1))]
    return max(nums) if nums else None

for lib in sorted(Path(".").glob("sram22_64x32m4w8_*.lib")):
    txt = lib.read_text()

    # Find the clk->dout timing arc block
    m = re.search(
        r'timing\s*\(\)\s*\{.*?related_pin\s*:\s*"clk";.*?timing_type\s*:\s*rising_edge;.*?'
        r'cell_rise\s*\(delay_template_7x7\)\s*\{.*?'
        r'cell_fall\s*\(delay_template_7x7\)\s*\{.*?\}',
        txt, re.S
    )

    if not m:
        print(f"{lib.name}: timing arc not found")
        continue

    arc = m.group(0)
    rise = max_table("cell_rise", arc)
    fall = max_table("cell_fall", arc)
    rtran = max_table("rise_transition", arc)
    ftran = max_table("fall_transition", arc)

    print(f"{lib.name}")
    print(f"  cell_rise max       = {rise:.6f} ns" if rise is not None else "  cell_rise max       = n/a")
    print(f"  cell_fall max       = {fall:.6f} ns" if fall is not None else "  cell_fall max       = n/a")
    print(f"  rise_transition max = {rtran:.6f} ns" if rtran is not None else "  rise_transition max = n/a")
    print(f"  fall_transition max = {ftran:.6f} ns" if ftran is not None else "  fall_transition max = n/a")
    print()
