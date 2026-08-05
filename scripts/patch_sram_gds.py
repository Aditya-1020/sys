import os
import re
import pya

BOUND_LAYER = 235
BOUND_DATATYPE = 4

gds = globals().get("gds")
lef = globals().get("lef")
if not gds or not lef:
    raise SystemExit("pass -rd gds=<path.gds> -rd lef=<path.lef> [-rd out=<path.gds>]")
out = globals().get("out", gds)

with open(lef) as f:
    m = re.search(r"^\s*SIZE\s+([\d.]+)\s+BY\s+([\d.]+)\s*;", f.read(), re.M)
if not m:
    raise SystemExit("no 'SIZE w BY h ;' found in %s" % lef)
width, height = float(m.group(1)), float(m.group(2))

ly = pya.Layout()
ly.read(gds)

tops = ly.top_cells()
if len(tops) != 1:
    raise SystemExit("expected a single top cell, got %s" % [c.name for c in tops])
top = tops[0]

layer = ly.layer(BOUND_LAYER, BOUND_DATATYPE)
existing = pya.Region(top.begin_shapes_rec(layer))
if existing.count():
    print("[patch_sram_gds] %s already has a %d/%d boundary, copying unchanged"
          % (top.name, BOUND_LAYER, BOUND_DATATYPE))
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    ly.write(out)
    raise SystemExit(0)

bbox = top.dbbox()
if abs(bbox.left) > 1e-6 or abs(bbox.bottom) > 1e-6:
    print("[patch_sram_gds] warning: geometry does not start at (0,0): %s" % bbox)
if bbox.width() - width > 1e-6 or bbox.height() - height > 1e-6:
    print("[patch_sram_gds] warning: geometry %gx%g exceeds LEF SIZE %gx%g"
          % (bbox.width(), bbox.height(), width, height))

top.shapes(layer).insert(pya.DBox(0.0, 0.0, width, height))

os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
ly.write(out)
print("[patch_sram_gds] %s: added %d/%d boundary 0 0 %g %g -> %s"
      % (top.name, BOUND_LAYER, BOUND_DATATYPE, width, height, out))
