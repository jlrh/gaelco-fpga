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
68000 @10 MHz, encrypted VRAM. **Status: playable on MiSTer (beta).** `jtsquash_V011.rbf`.

### Thunder Hoop (Gaelco, 1992) — *beta*
68000 @12 MHz, encrypted VRAM, gfx with `[0,2,1,3]` de-interleave. **Status: working on MiSTer (beta)**
(boot, video, audio). `jtthoop_V005.rbf`.

### Biomechanical Toy (Gaelco, 1994/95) — *beta*
68000 @12 MHz, *plain VRAM* (no encryption). **Status: working on MiSTer (beta).** `jtbiomtoy_V002.rbf`.

### TH Strikes Back / Thunder Hoop 2 (Gaelco, 1994) — *beta*
68000 @12 MHz + **DS5002FP** coprocessor (passive protection). Plain VRAM (no encryption), Rev-B sprite
format. The DS5002 firmware is **loaded at runtime from the `.mra`** (`JTFRAME_PROM_START`, like World Rally) —
**no firmware is included in this repo**. **Status: boots and passes the self-test on MiSTer (beta).**
Prebuilt `jtthoop2_V005.rbf` in [`releases/`](releases/) (firmware loaded at runtime from the `.mra`), or build from source (`cores/thoop2/`).
> ⚠️ The romset **must contain the DS5002 firmware** `thoop2_ds5002fp.bin` (CRC `6881384d`); it is not in the standard MAME set, and without it the coprocessor has no code and the game **freezes a few seconds into play**.
> (V005 fixes a timing-closure bug present in V004 — the mc8051/DS5002 path was unconstrained, causing **board-dependent freezes during gameplay**.)

### Alligator Hunt (Gaelco, 1994)
**First Gaelco Type-2 core** (`gaelco2.cpp`, **GAE1** custom chip): **MC68000** + **DS5002FP** coprocessor
+ **OKI MSM6295**. The Type-2 video is new vs the Type-1 family (2 tilemaps + 2 sprite banks with
shadow/highlight, larger palette).

**Status: playable on MiSTer** — boot, video, audio, DS5002 coprocessor, attract demo and gameplay
validated on hardware. The DS5002 is implemented with the **mc8051** core (Oregano), like World Rally /
TH Strikes Back. CRT/analog (15 kHz) timing validated.

The DS5002 firmware is **loaded at runtime from the `.mra`** — **no firmware is included in this repo** and
**none is baked into the bitstream**. Prebuilt `jtaligator_V016.rbf` in [`releases/`](releases/) —
**distributable** (DS5002 firmware loaded at runtime from the `.mra`, not baked into the bitstream),
**validated playable on MiSTer**. Or build from source (`cores/aligator/`) applying **both**
`tools/patch_dallas_runtime.py` + `tools/patch_scratch_runtime.py` (the first builds the runtime program
PROM, the second the runtime data SCRATCH of the DS5002 — **both are required** for a distributable `.rbf`
without the freeze).
> ⚠️ The romset **must contain the DS5002 firmware** (`aligator_ds5002fp_sram.bin`); without it the
> coprocessor has no code and the game freezes a few seconds into play.

### World Rally 2: Twin Racing (Gaelco, 1995)
**Type-2 core** (`gaelco2.cpp`, **GAE1** custom chip): **MC68000** + **DS5002FP** coprocessor, running at
**13 MHz**. Two-player **dual-monitor** racing cabinet: the single GAE1 feeds two side-by-side screens,
5 bpp tilemaps, analog wheels (ADC) and GAE1 stereo sound (samples in the gfx ROMs — no OKI).

**Status: playable on MiSTer** — boot, video, audio, DS5002 coprocessor and gameplay validated on
hardware. The DS5002 is implemented with the **mc8051** core (Oregano). The CPU/MCU run at a faithful
**13/13 MHz** (fractional cen). The OSD **"Monitor"** option selects **Left / Right / Twin**: single
monitors are 384×240 (4:3); **Twin** is 768 wide (two 4:3 monitors) shown at **8:3 automatically**.
Default is **Left** (single, 4:3) so it is playable from boot on a normal monitor/CRT.

The DS5002 firmware is **loaded at runtime from the `.mra`** — **no firmware is included in this repo** and
**none is baked into the bitstream**. Prebuilt `jtwrally2_V010.rbf` in [`releases/`](releases/) —
**distributable**, **validated playable on MiSTer**. To build from source (`cores/wrally2/`) apply
`tools/patch_twin_arx.py` (automatic 8:3 aspect in Twin) and compile with `WR2_CEN_FRAC=1` (13/13 MHz) —
see [`BUILD.md`](BUILD.md). Unlike World Rally / Alligator, **no DS5002 address patch is needed** (the core
is `SDRAM_LARGE`, so the firmware loads at runtime from the `.mra` without patching).
> ✅ The `.mra` (**V.014**) builds the 16 MB gfx bank **entirely from the standard `wrally2.zip`** via
> `<interleave>` directives — **no custom gfx blob** is needed. (Earlier drafts used a pre-built
> `wrally2_gfx.zip`; that is no longer required.) Video and sound validated on hardware.
> ⚠️ The romset **must contain the DS5002 firmware** (`wrally2_ds5002fp_sram.bin`); without it the
> coprocessor has no code and the game does not boot.
> 🖥️ **Do not ship a `config/wrally2.CFG`**: the factory default (no CFG) boots Left / Original / Normal.

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

### Alligator Hunt
- ✅ **Playable on MiSTer** (validated on hardware): boot, video, audio, DS5002 coprocessor, gameplay.
- ✅ **CRT/analog timing** validated (`HTOTAL`=512 → ~15.6 kHz hsync, `VTOTAL`=264 → ~59.2 Hz).
- DS5002 firmware loaded at runtime from the `.mra` (no firmware in this repo, none baked in the bitstream).
- Prebuilt `jtaligator_V016.rbf` in [`releases/`](releases/) — distributable, validated playable on MiSTer.
  Build from source needs **both** `tools/patch_dallas_runtime.py` (runtime program PROM) + `tools/patch_scratch_runtime.py` (runtime data SCRATCH).

### World Rally 2
- ✅ **Playable on MiSTer** (validated on hardware): boot, video, audio, DS5002 coprocessor, gameplay.
- ✅ **Dual-monitor**: OSD "Monitor" = Left / Right / Twin; Twin (768) shows at **8:3 automatically**. Default = Left (single 4:3).
- ✅ CPU/MCU at faithful **13/13 MHz** (fractional cen, `WR2_CEN_FRAC`).
- DS5002 firmware loaded at runtime from the `.mra` (no firmware in this repo, none baked in the bitstream).
- Prebuilt `jtwrally2_V010.rbf` in [`releases/`](releases/) — distributable, validated playable on MiSTer.
- ⚠️ Minor known cosmetic issue: in the cliff area a few grass sprites draw over the rocks (sprite priority vs MAME); does not affect gameplay.

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
68000 @10 MHz, VRAM cifrada. **Estado: jugable en MiSTer (beta).** `jtsquash_V011.rbf`.

### Thunder Hoop (Gaelco, 1992) — *beta*
68000 @12 MHz, VRAM cifrada, gfx con de-interleave `[0,2,1,3]`. **Estado: funcionando en MiSTer (beta)**
(arranque, vídeo, audio). `jtthoop_V005.rbf`.

### Biomechanical Toy (Gaelco, 1994/95) — *beta*
68000 @12 MHz, *VRAM plana* (sin cifrado). **Estado: funcionando en MiSTer (beta).** `jtbiomtoy_V002.rbf`.

### Alligator Hunt (Gaelco, 1994)
**Primer core Gaelco Tipo-2** (`gaelco2.cpp`, chip custom **GAE1**): **MC68000** + coprocesador
**DS5002FP** + **OKI MSM6295**. El vídeo Tipo-2 es nuevo respecto a la familia Tipo-1 (2 tilemaps + 2
bancos de sprites con sombras/highlights, paleta mayor).

**Estado: jugable en MiSTer** — arranque, vídeo, audio, coprocesador DS5002, demo de atracción y partida
validados en hardware. El DS5002 se implementa con el core **mc8051** (Oregano), como World Rally /
TH Strikes Back. Timing CRT/analógico (15 kHz) validado.

El firmware del DS5002 se **carga en runtime desde el `.mra`** — **no se incluye firmware en este repo** y
**no va horneado en el bitstream**. `.rbf` precompilado `jtaligator_V016.rbf` en [`releases/`](releases/) —
**distribuible** (firmware del DS5002 cargado en runtime desde el `.mra`, no horneado en el bitstream),
**validado jugable en MiSTer**. O compilar desde fuente (`cores/aligator/`) aplicando **los dos**
`tools/patch_dallas_runtime.py` + `tools/patch_scratch_runtime.py` (el primero hace el PROM del programa en
runtime, el segundo el SCRATCH de datos en runtime del DS5002 — **ambos imprescindibles** para un `.rbf`
distribuible sin el freeze).
> ⚠️ El romset **debe contener el firmware del DS5002** (`aligator_ds5002fp_sram.bin`); sin él el
> coprocesador no tiene código y el juego se congela a los pocos segundos de partida.

### World Rally 2: Twin Racing (Gaelco, 1995)
**Core Tipo-2** (`gaelco2.cpp`, chip custom **GAE1**): **MC68000** + coprocesador **DS5002FP** a **13 MHz**.
Recreativa de carreras de 2 jugadores con **doble monitor**: un único GAE1 alimenta dos pantallas lado a
lado, tilemaps de 5 bpp, volantes analógicos (ADC) y sonido estéreo del GAE1 (samples en las ROMs de gfx —
sin OKI).

**Estado: jugable en MiSTer** — arranque, vídeo, audio, coprocesador DS5002 y partida validados en
hardware. El DS5002 se implementa con el core **mc8051** (Oregano). CPU/MCU a **13/13 MHz** fiel (cen
fraccional). La opción de OSD **"Monitor"** elige **Left / Right / Twin**: los monitores individuales son
384×240 (4:3); **Twin** son 768 de ancho (dos monitores 4:3) mostrados a **8:3 automáticamente**. Por
defecto arranca en **Left** (individual 4:3) para que sea jugable desde el arranque en un monitor/CRT normal.

El firmware del DS5002 se **carga en runtime desde el `.mra`** — **no se incluye firmware en este repo** y
**no va horneado en el bitstream**. `.rbf` precompilado `jtwrally2_V010.rbf` en [`releases/`](releases/) —
**distribuible**, **validado jugable en MiSTer**. Para compilar desde fuente (`cores/wrally2/`) aplica
`tools/patch_twin_arx.py` (8:3 automático en Twin) y compila con `WR2_CEN_FRAC=1` (13/13 MHz) — ver
[`BUILD.md`](BUILD.md). A diferencia de World Rally / Alligator, **no hace falta parche de dirección del
DS5002** (el core es `SDRAM_LARGE`, así que el firmware carga en runtime desde el `.mra` sin parchear).
> ✅ El `.mra` (**V.014**) construye el banco de gfx de 16 MB **enteramente desde el `wrally2.zip` estándar**
> con directivas `<interleave>` — **no hace falta ningún blob de gfx**. (Borradores anteriores usaban un
> `wrally2_gfx.zip` pre-generado; ya no es necesario.) Vídeo y sonido validados en hardware.
> ⚠️ El romset **debe contener el firmware del DS5002** (`wrally2_ds5002fp_sram.bin`); sin él el
> coprocesador no tiene código y el juego no arranca.
> 🖥️ **No distribuir un `config/wrally2.CFG`**: el default de fábrica (sin CFG) arranca en Left / Original / Normal.

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

### Alligator Hunt
- ✅ **Jugable en MiSTer** (validado en hardware): arranque, vídeo, audio, coprocesador DS5002, partida.
- ✅ **Timing CRT/analógico** validado (`HTOTAL`=512 → hsync ~15,6 kHz, `VTOTAL`=264 → ~59,2 Hz).
- Firmware del DS5002 cargado en runtime desde el `.mra` (sin firmware en el repo, sin hornear en el bitstream).
- `.rbf` precompilado `jtaligator_V016.rbf` en [`releases/`](releases/) — distribuible, validado jugable en MiSTer.
  Compilar desde fuente requiere **los dos** `tools/patch_dallas_runtime.py` (PROM del programa en runtime) + `tools/patch_scratch_runtime.py` (SCRATCH de datos en runtime).

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
