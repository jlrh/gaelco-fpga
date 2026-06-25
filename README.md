# gaelco-fpga

🇬🇧 English (below) · [🇪🇸 Español](#español)

FPGA recreations of **Gaelco** arcade boards, built on the
[**JTFRAME**](https://github.com/jotego/jtframe) framework (Jose Tejada / jotego). Multi-platform
(MiSTer, Pocket, …) from the same code.

> ⚠️ **Independent project.** It uses jotego's JTFRAME framework (GPLv3) —with all due credit and
> gratitude— but **it is not a jotego core, nor affiliated with him, nor endorsed by him**. Any bug or
> limitation is this project's responsibility, not jotego's or JTFRAME's.

## Cores

### World Rally (Gaelco, 1993)
Top-down racer. Hardware: **MC68000 @12 MHz** + **Dallas DS5002FP** (secure 8051 MCU) + Gaelco custom
video ASIC (2 tilemaps + sprites) + encrypted VRAM + **OKI MSM6295**.

**Status: playable on MiSTer** — boot, video, audio, DS5002 coprocessor handshake, attract demo and
gameplay. The DS5002 is implemented with the **mc8051** core (Oregano, bundled with jtframe) adapted to
the DS5002 timing.

A prebuilt `.rbf` is available in [`releases/`](releases/) — **distributable**: the DS5002 firmware is
loaded at *runtime* from the `.mra`, it is not baked into the bitstream.

> The next three are the **Gaelco Type-1 family** (`gaelco.cpp`): **MC68000** + Gaelco custom video
> (2 tilemaps + sprites, 4bpp, xBGR-555) + **OKI MSM6295**. **Simpler than World Rally: no DS5002**
> coprocessor. Built reusing the same infrastructure (fx68k, jt6295, jtframe). Prebuilt `.rbf` for each
> in [`releases/`](releases/); no DS5002 patch needed. **⚠️ All three are BETA** (see Known issues).
> **Analog/CRT (15 kHz) now works:** horizontal-sync timing fixed (`HTOTAL` 400→512 for ~15.6 kHz hsync,
> `VTOTAL` 348→272 for ~57.45 Hz, like World Rally). Both HDMI and analog/CRT supported.

### Squash (Gaelco, 1992) — *beta*
68000 @10 MHz, encrypted VRAM. **Status: playable on MiSTer (beta).** `jtsquash_V009.rbf`.

### Thunder Hoop (Gaelco, 1992) — *beta*
68000 @12 MHz, encrypted VRAM, gfx with `[0,2,1,3]` de-interleave. **Status: working on MiSTer (beta)**
(boot, video, audio). `jtthoop_V005.rbf`.

### Biomechanical Toy (Gaelco, 1994/95) — *beta*
68000 @12 MHz, *plain VRAM* (no encryption). **Status: working on MiSTer (beta).** `jtbiomtoy_V002.rbf`.

### TH Strikes Back / Thunder Hoop 2 (Gaelco, 1994) — *beta*
68000 @12 MHz + **DS5002FP** coprocessor (passive protection). Plain VRAM (no encryption), Rev-B sprite
format. The DS5002 firmware is **loaded at runtime from the `.mra`** (`JTFRAME_PROM_START`, like World Rally) —
**no firmware is included in this repo**. **Status: boots and passes the self-test on MiSTer (beta).**
Build from source (`cores/thoop2/`) with the firmware supplied by the `.mra`.

## Build

This repo contains **only the core code** (`cores/wrally/`). The framework and third-party cores
(jtframe, fx68k, jt6295, mc8051) are **not included**: jtframe provides them.

1. Clone [jtcores](https://github.com/jotego/jtcores) (brings jtframe + fx68k + jt6295 as modules).
2. Place this repo's `cores/wrally/` inside your jtcores checkout.
3. Generate the project: `jtcore wrally -mister`.
4. **Apply the runtime-DS5002 patch** (required for a distributable `.rbf`):
   `python3 cores/wrally/tools/patch_dallas_runtime.py <jtcores>/cores/wrally/mister/jtwrally_game_sdram.v`
5. Compile with Quartus.

📋 **Step-by-step details and the reason for the patch in [`BUILD.md`](BUILD.md).**

Core layout:
```
cores/wrally/
├── hdl/    Core Verilog (see hdl/README.md for a per-file description)
├── cfg/    macros.def, mem.yaml, files.yaml
├── mra/    .mra definition (how to assemble the ROMs)
├── syn/    wrally_clk48_96.sdc (timing constraints)
└── tools/  patch_dallas_runtime.py (runtime DS5002) + mc8051 core regen (ghdl → Verilog)
```

## ROMs

**Not included** (copyrighted material). Everyone provides the original ROMs of their own board. The
`.mra` describes how to assemble them.

## Known issues / TODO

The cores are playable/working; the items below are polish and do not block gameplay.

### World Rally
- ✅ **Refresh rate:** adjusted to ~**60.1 Hz** (`VBP` 19→10, `VTOTAL`=260), closer to the original board.
- **Red shadow glitches in the snow stage (Monte Carlo):**
  - *Roadside beacons*: shown as a solid red bar (on the real PCB / MAME they are imperceptible, barely
    tinting the white snow). It is the shadow-over-tilemap path.
  - *Start arch*: red glitches on the right, only in gameplay. MAME itself documents this glitch as a
    "bogus" priority scheme (no golden reference).
- **Timing:** ~−9.5 ns setup slack on an mc8051 path (cen-paced, not functional); the SDC multicycle
  still needs tuning for a timing-clean build.

### Squash *(beta)*
- **Boot/check-screen grid** not fully pixel-perfect (rightmost column + a corner connector).
- ✅ **Layer ordering — FIXED:** the scoreboard advertising and the sets-score display (sprite↔tilemap
  *sandwiching* priority, as in MAME `screen_update_squash`) now render in the correct order.
- ✅ **CRT geometry:** wider, centred image (6 MHz pixel clock, `HTOTAL`=384 → ~83% active picture,
  15.625 kHz hsync) so it fills an analog/CRT screen instead of leaving side bands.
- Various minor graphic glitches.

### Thunder Hoop *(beta)*
- **Boot/check-screen grid** adjustment pending.
- Various minor graphic glitches.

### TH Strikes Back *(beta)*
- DS5002 firmware loaded at runtime from the `.mra` (no firmware in this repo).
- Various minor graphic glitches; fine-tuning of video priority/timing pending.

### Biomechanical Toy *(beta)*
- **Boot/check-screen grid** adjustment pending.
- Various minor graphic glitches.

## Credits

- **JTFRAME**, **jt6295** — Jose Tejada (jotego)
- **fx68k** (68000 core) — Jared Boone (ijor)
- **mc8051** — Oregano Systems (via jtframe)
- **MAME** — hardware reference (`wrally.cpp` driver)
- Gaelco SA — for releasing the DS5002FP code for emulation

## Acknowledgements

- To **José Tejada (jotego)**, for his fantastic work over so many years and, especially, for his
  **JTFRAME / jtcore** framework, on which this core is built.
- To **Sorgelig** and the whole **MiSTer FPGA** project.
- To the **MiSTer FPGA community** and the **Spanish Telegram channel**.
- To the **MAME community**, because without their preservation work this core would not be possible.
- And to **Anthropic**, for **Claude**, which turns a project of this magnitude into almost child's play.

## License

**GPLv3** (see [`LICENSE`](LICENSE)) — required by the jtframe / fx68k / jt6295 dependencies.

---

## Español

🇪🇸 Español · [🇬🇧 English ↑](#gaelco-fpga)

Recreaciones en FPGA de placas arcade de **Gaelco**, construidas sobre el framework
[**JTFRAME**](https://github.com/jotego/jtframe) (Jose Tejada / jotego). Multi-plataforma
(MiSTer, Pocket, …) desde el mismo código.

> ⚠️ **Proyecto independiente.** Usa el framework JTFRAME (GPLv3) de jotego —con todo el mérito y
> agradecimiento— pero **no es un core de jotego ni está afiliado a él ni avalado por él**. Cualquier
> error o limitación es responsabilidad de este proyecto, no de jotego ni de JTFRAME.

## Cores

### World Rally (Gaelco, 1993)
Racer cenital. Hardware: **MC68000 @12 MHz** + **Dallas DS5002FP** (MCU seguro 8051) + ASIC de
vídeo Gaelco (2 tilemaps + sprites) + VRAM cifrada + **OKI MSM6295**.

**Estado: jugable en MiSTer** — arranque, vídeo, audio, handshake del coprocesador DS5002, demo de
atracción y partida. El DS5002 se implementa con el core **mc8051** (Oregano, incluido en jtframe)
adaptado al timing del DS5002.

Hay un `.rbf` precompilado en [`releases/`](releases/) — **distribuible**: el firmware del DS5002 se
carga en *runtime* desde el `.mra`, no va horneado en el bitstream.

> Los tres siguientes son la **familia Gaelco Tipo-1** (`gaelco.cpp`): **MC68000** + vídeo custom Gaelco
> (2 tilemaps + sprites, 4bpp, xBGR-555) + **OKI MSM6295**. **Más simples que World Rally: SIN
> coprocesador DS5002.** Construidos reutilizando la misma infraestructura (fx68k, jt6295, jtframe).
> `.rbf` precompilado de cada uno en [`releases/`](releases/); no necesitan el parche del DS5002.
> **⚠️ Los tres son BETA** (ver Trabajos pendientes).
> **La salida analógica/CRT (15 kHz) ya funciona:** corregido el timing de sincronismo horizontal
> (`HTOTAL` 400→512 para hsync ~15,6 kHz, `VTOTAL` 348→272 para ~57,45 Hz, como World Rally).
> Soporta tanto HDMI como analógica/CRT.

### Squash (Gaelco, 1992) — *beta*
68000 @10 MHz, VRAM cifrada. **Estado: jugable en MiSTer (beta).** `jtsquash_V009.rbf`.

### Thunder Hoop (Gaelco, 1992) — *beta*
68000 @12 MHz, VRAM cifrada, gfx con de-interleave `[0,2,1,3]`. **Estado: funcionando en MiSTer (beta)**
(arranque, vídeo, audio). `jtthoop_V005.rbf`.

### Biomechanical Toy (Gaelco, 1994/95) — *beta*
68000 @12 MHz, *VRAM plana* (sin cifrado). **Estado: funcionando en MiSTer (beta).** `jtbiomtoy_V002.rbf`.

## Construir

Este repo contiene **solo el código del core** (`cores/wrally/`). El framework y los cores de
terceros (jtframe, fx68k, jt6295, mc8051) **no se incluyen**: los aporta jtframe.

1. Clona [jtcores](https://github.com/jotego/jtcores) (trae jtframe + fx68k + jt6295 como módulos).
2. Coloca `cores/wrally/` de este repo dentro de tu checkout de jtcores.
3. Genera el proyecto: `jtcore wrally -mister`.
4. **Aplica el parche del DS5002 en runtime** (imprescindible para un `.rbf` distribuible):
   `python3 cores/wrally/tools/patch_dallas_runtime.py <jtcores>/cores/wrally/mister/jtwrally_game_sdram.v`
5. Compila con Quartus.

📋 **Pasos detallados y el porqué del parche en [`BUILD.md`](BUILD.md).**

Estructura del core:
```
cores/wrally/
├── hdl/    Verilog del core (ver hdl/README.md para la descripción de cada fichero)
├── cfg/    macros.def, mem.yaml, files.yaml
├── mra/    definición .mra (cómo ensamblar las ROMs)
├── syn/    wrally_clk48_96.sdc (constraints de timing)
└── tools/  patch_dallas_runtime.py (DS5002 en runtime) + regen del core mc8051 (ghdl → Verilog)
```

## ROMs

**No se incluyen** (material con copyright). Cada cual aporta las ROMs originales de su placa. El
`.mra` describe cómo ensamblarlas.

## Trabajos pendientes

Los cores son jugables/funcionales; lo de abajo es pulido y no bloquea la partida.

### World Rally
- **Glitches rojos de sombra en la fase de nieve (Monte Carlo):**
  - *Balizas* de la carretera: aparecen como una barra roja sólida (en la placa real / MAME son
    imperceptibles, tiñen apenas la nieve blanca). Es el camino sombra-sobre-tilemap.
  - *Arco de salida*: glitches rojos a la derecha, solo en partida. El propio MAME documenta este
    glitch como un esquema de prioridad "bogus" (no hay referencia dorada).
- **Timing:** ~−9.5 ns de setup slack en un path del mc8051 (cen-paced, no funcional); falta afinar el
  multicycle del SDC para un build timing-limpio.

### Squash *(beta)*
- **Rejilla de la pantalla de arranque/check** no del todo pixel-perfect (última columna + un conector de esquina).
- **Orden de capas:** la publicidad del marcador y el display de los sets (prioridad sprite↔tilemap)
  todavía no salen en el orden correcto.
- Diversos glitches gráficos menores.

### Thunder Hoop *(beta)*
- **Rejilla de la pantalla de arranque/check**: ajuste pendiente.
- Diversos glitches gráficos menores.

### Biomechanical Toy *(beta)*
- **Rejilla de la pantalla de arranque/check**: ajuste pendiente.
- Diversos glitches gráficos menores.

## Créditos

- **JTFRAME**, **jt6295** — Jose Tejada (jotego)
- **fx68k** (núcleo 68000) — Jared Boone (ijor)
- **mc8051** — Oregano Systems (vía jtframe)
- **MAME** — referencia de hardware (driver `wrally.cpp`)
- Gaelco SA — por liberar el código del DS5002FP para emulación

## Agradecimientos

- A **José Tejada (jotego)**, por su fantástico trabajo de tantos años y, muy en especial, por su
  framework **JTFRAME / jtcore**, sobre el que se construye este core.
- A **Sorgelig** y todo el proyecto **MiSTer FPGA**.
- A la **comunidad MiSTer FPGA** y al **canal de Telegram en español**.
- A la **comunidad MAME**, porque sin su trabajo de preservación este core no sería posible.
- Y a **Anthropic**, por **Claude**, que permite convertir un proyecto de esta envergadura en casi un
  juego de niños.

## Licencia

**GPLv3** (ver [`LICENSE`](LICENSE)) — obligado por las dependencias jtframe / fx68k / jt6295.
