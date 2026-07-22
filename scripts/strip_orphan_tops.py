import pya, os

gds = globals().get("gds")
if not gds:
    raise SystemExit("pass -rd gds=<path.gds>")
design_top = globals().get("top", "top")
out = globals().get("out", gds)  # overwrite in place by default

ly = pya.Layout()
ly.read(gds)

if ly.cell(design_top) is None:
    raise SystemExit("design top '%s' not found in %s" % (design_top, gds))

before = [c.name for c in ly.top_cells()]
removed = []
for c in list(ly.top_cells()):
    if c.name != design_top:
        removed.append(c.name)
        c.prune_cell()  # deletes this cell + sub-cells used only by it

after = [c.name for c in ly.top_cells()]
if after != [design_top]:
    raise SystemExit("expected single top '%s', got %s" % (design_top, after))

ly.write(out)
print("[strip_orphan_tops] tops %d -> %d, removed %d orphans -> %s"
      % (len(before), len(after), len(removed), os.path.basename(out)))
