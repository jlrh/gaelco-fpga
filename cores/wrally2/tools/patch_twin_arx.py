#!/usr/bin/env python3

import sys

MARKER = "JTFRAME_TWIN_ARX"
BLOCK = """`ifdef JTFRAME_TWIN_ARX
// wrally2 twin (status[14]) -> ARX 8:3 (two 4:3 monitors); everything else = core ARX (4:3).
// Gated by macro: other cores don't define JTFRAME_TWIN_ARX and take the `else`.
wire [12:0] freak_arx = status[14] ? 13'd8 : raw_arx;
wire [12:0] freak_ary = status[14] ? 13'd3 : raw_ary;
`else
wire [12:0] freak_arx = raw_arx;
wire [12:0] freak_ary = raw_ary;
`endif

video_freak u_crop("""

def main():
    if len(sys.argv) != 2:
        sys.exit("usage: patch_twin_arx.py <path-to>/jtframe_mister.sv")
    path = sys.argv[1]
    with open(path, "r", encoding="utf-8", newline="") as f:
        src = f.read()

    if MARKER in src:
        print("already patched (JTFRAME_TWIN_ARX present) — nothing to do")
        return

    if "video_freak u_crop(" not in src:
        sys.exit("ERROR: 'video_freak u_crop(' not found in %s (unexpected jtframe version)" % path)

    src = src.replace("video_freak u_crop(", BLOCK, 1)

    replaced = 0
    for a, b in ((".ARX        ( raw_arx       )", ".ARX        ( freak_arx     )"),
                 (".ARY        ( raw_ary       )", ".ARY        ( freak_ary     )")):
        if a in src:
            src = src.replace(a, b, 1)
            replaced += 1
    if replaced != 2:
        sys.exit("ERROR: could not rewire .ARX/.ARY ports (%d/2) — check jtframe_mister.sv formatting" % replaced)

    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(src)
    print("patched OK: JTFRAME_TWIN_ARX block inserted + .ARX/.ARY rewired to freak_arx/freak_ary")

if __name__ == "__main__":
    main()
