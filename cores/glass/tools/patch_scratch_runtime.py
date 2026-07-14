#!/usr/bin/env python3
# ============================================================================
#  patch_scratch_runtime.py  (idempotente)
#
#  El wrapper jtglass_game_sdram.v lo AUTO-GENERA `jtframe mem` (desde cfg/mem.yaml)
#  y se REGENERA en cada build (_ali_regen.sh). El SCRATCH on-chip del DS5002 (u_scratch,
#  32KB dentro de aligator_main) se carga en RUNTIME desde la .mra por su puerto 1, con el
#  MISMO download que alimenta el PROM del firmware (u_prom_dallas): las señales del wrapper
#  dallas_dd[7:0] / dallas_waddr[14:0] / dallas_we (dominio `clk`).
#
#  jtglass_game tiene 4 puertos nuevos (scr_dl_clk/addr/data/we) para recibir ese download,
#  pero como NO están en mem.yaml, el wrapper generado no los conecta. Este parche inserta esas
#  4 conexiones en la instancia `jtglass_game u_game(...)` del wrapper, justo tras la línea
#  ".dallas_data ( dallas_data )," (ancla estable, parte de los puertos mem.yaml de u_game).
#
#  Idempotente: si las conexiones ya están, no hace nada. Re-ejecutable sin duplicar.
#
#  Uso:
#     python3 patch_scratch_runtime.py <wrapper.v> [<wrapper2.v> ...]
#  Sin argumentos: parchea los wrappers conocidos (mister, mist, ver/aligator) si existen.
# ============================================================================
import os
import re
import sys

# Marcador para detectar idempotencia y delimitar el bloque insertado.
MARKER = "scratch DS5002 runtime download"

BLOCK = (
    "    // {marker}: el scratch on-chip del DS5002 se carga desde la .mra\n"
    "    // por el MISMO download que el PROM del firmware (dallas_*). Inyectado por patch_scratch_runtime.py.\n"
    "    .scr_dl_clk  ( clk          ),\n"
    "    .scr_dl_addr ( dallas_waddr ),\n"
    "    .scr_dl_data ( dallas_dd    ),\n"
    "    .scr_dl_we   ( dallas_we    ),\n"
).format(marker=MARKER)

# Ancla: la conexión .dallas_data ( dallas_data ) dentro de la instancia u_game.
# (En el PROM u_prom_dallas el puerto es .q ( dallas_data ), texto distinto -> no colisiona.)
ANCHOR_RE = re.compile(
    r"^([ \t]*)\.dallas_data\s*\(\s*dallas_data\s*\)\s*,\s*$",
    re.MULTILINE,
)


def patch_text(text):
    """Devuelve (nuevo_texto, cambiado_bool). Idempotente."""
    if MARKER in text:
        return text, False  # ya parcheado
    if "dallas_data" not in text:
        # Wrapper sin PROM dallas (p.ej. target 'mist' antiguo): nada que parchear aquí.
        return text, False
    m = ANCHOR_RE.search(text)
    if not m:
        raise RuntimeError(
            "no se encontró el ancla '.dallas_data ( dallas_data ),' (¿formato del wrapper cambió?)"
        )
    insert_at = m.end()
    # Inserta el bloque justo después de la línea del ancla (que termina en '\n').
    # m.end() apunta al fin del match (sin el salto de línea consumido por $), así que
    # buscamos el siguiente '\n' para insertar en la línea siguiente.
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
    core = os.path.dirname(here)  # cores/glass
    cands = [
        os.path.join(core, "mister", "jtglass_game_sdram.v"),
        os.path.join(core, "mist", "jtglass_game_sdram.v"),
        os.path.join(core, "ver", "glass", "jtglass_game_sdram.v"),
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
