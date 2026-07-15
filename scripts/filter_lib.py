# Remove unwanted cell groups from a Liberty file by brace counting
import re, sys

BAD_PREFIXES = (
    "sky130_fd_sc_hd__lpflow_",   # power-gating / isolation / level-shift cells
    "sky130_fd_sc_hd__probe_",    # probe cells
    "sky130_fd_sc_hd__probec_",
)

def main(src, dst):
    cell_re = re.compile(r'^\s*cell\s*\(\s*"?([A-Za-z0-9_]+)"?\s*\)')
    out, skipping, depth, removed = [], False, 0, []
    with open(src) as f:
        for line in f:
            if not skipping:
                m = cell_re.match(line)
                if m and m.group(1).startswith(BAD_PREFIXES):
                    depth = line.count("{") - line.count("}")
                    skipping = depth > 0
                    removed.append(m.group(1))
                    continue
                out.append(line)
            else:
                depth += line.count("{") - line.count("}")
                if depth <= 0:
                    skipping = False
    with open(dst, "w") as f:
        f.writelines(out)
    print(f"removed {len(removed)} cells:")
    for c in removed:
        print("  " + c)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])