#!/usr/bin/env python3

import os
import re
import sys

MARKER = "scratch DS5002 runtime download"

BLOCK = (
    "    // {marker}: el scratch on-chip del DS5002 se carga desde la .mra\n"
    "    // por el MISMO download que el PROM del firmware (dallas_*). Inyectado por patch_scratch_runtime.py.\n"
    "    .scr_dl_clk  ( clk          ),\n"
    "    .scr_dl_addr ( dallas_waddr ),\n"
    "    .scr_dl_data ( dallas_dd    ),\n"
    "    .scr_dl_we   ( dallas_we    ),\n"
).format(marker=MARKER)

ANCHOR_RE = re.compile(
    r"^([ \t]*)\.dallas_data\s*\(\s*dallas_data\s*\)\s*,\s*$",
    re.MULTILINE,
)

def patch_text(text):
    """Devuelve (nuevo_texto, cambiado_bool). Idempotente."""
    if MARKER in text:
        return text, False
    if "dallas_data" not in text:

        return text, False
    m = ANCHOR_RE.search(text)
    if not m:
        raise RuntimeError(
            "no se encontró el ancla '.dallas_data ( dallas_data ),' (¿formato del wrapper cambió?)"
        )
    insert_at = m.end()

    nl = text.find("\n", insert_at)
    if nl == -1:
        nl = len(text)
    new_text = text[: nl + 1] + BLOCK + text[nl + 1 :]
    return new_text, True

def patch_file(path):
    if not os.path.isfile(path):
        print("  SKIP (no existe): %s" % path)
        return
    with open(path, "r", encoding="utf-8", newline="") as f:
        text = f.read()
    new_text, changed = patch_text(text)
    if not changed:
        print("  OK (ya parcheado): %s" % path)
        return
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(new_text)
    print("  PARCHEADO: %s" % path)

def default_targets():
    here = os.path.dirname(os.path.abspath(__file__))
    core = os.path.dirname(here)
    cands = [
        os.path.join(core, "mister", "jtaligator_game_sdram.v"),
        os.path.join(core, "mist", "jtaligator_game_sdram.v"),
        os.path.join(core, "ver", "aligator", "jtaligator_game_sdram.v"),
    ]
    return [c for c in cands if os.path.isfile(c)]

def main(argv):
    targets = argv[1:] if len(argv) > 1 else default_targets()
    if not targets:
        print("patch_scratch_runtime.py: no hay wrappers que parchear")
        return 0
    print("patch_scratch_runtime.py: parcheando %d wrapper(s)" % len(targets))
    rc = 0
    for t in targets:
        try:
            patch_file(t)
        except Exception as e:
            print("  ERROR en %s: %s" % (t, e))
            rc = 1
    return rc

if __name__ == "__main__":
    sys.exit(main(sys.argv))
