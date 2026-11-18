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
68000 @10 MHz, encrypted VRAM. **Status: playable on MiSTer (beta).** `squash_20260714.rbf`.

### Thunder Hoop (Gaelco, 1992) — *beta*
68000 @12 MHz, encrypted VRAM, gfx with `[0,2,1,3]` de-interleave. **Status: working on MiSTer (beta)**
(boot, video, audio). `thoop_20260714.rbf`.

### Biomechanical Toy (Gaelco, 1994/95) — *beta*
68000 @12 MHz, *plain VRAM* (no encryption). **Status: working on MiSTer (beta).** `biomtoy_20260714.rbf`.

### TH Strikes Back / Thunder Hoop 2 (Gaelco, 1994) — *beta*
68000 @12 MHz + **DS5002FP** coprocessor (passive protection). Plain VRAM (no encryption), Rev-B sprite
format. The DS5002 firmware is **loaded at runtime from the `.mra`** (`JTFRAME_PROM_START`, like World Rally) —
**no firmware is included in this repo**. **Status: boots and passes the self-test on MiSTer (beta).**
Prebuilt `thoop2_20260714.rbf` in [`releases/`](releases/) (firmware loaded at runtime from the `.mra`), or build from source (`cores/thoop2/`).
> ⚠️ The romset **must contain the DS5002 firmware** `thoop2_ds5002fp.bin` (CRC `6881384d`); it is not in the standard MAME set, and without it the coprocessor has no code and the game **freezes a few seconds into play**.
> (V005 fixes a timing-closure bug present in V004 — the mc8051/DS5002 path was unconstrained, causing **board-dependent freezes during gameplay**.)

### Glass (Gaelco, 1993)
Type-1 core (`gaelco.cpp`): **MC68000 @12 MHz** + **DS5002FP** coprocessor (active protection) + encrypted
VRAM. Video: 2 tilemaps + sprites (4bpp) + **OKI MSM6295**. The DS5002 is implemented with the **mc8051**
core (Oregano), like World Rally / Alligator. **Status: playable on MiSTer** — boot, video, audio, DS5002
coprocessor, and the end-of-mission-1 reveal validated on hardware (the mission-1 hang was a DS5002
render-IRQ overrun, fixed by running the mc8051 at its faithful rate).

The DS5002 firmware is **loaded at runtime from the `.mra`** — **no firmware is included in this repo** and
**none is baked into the bitstream**. Prebuilt `glass_20260713.rbf` in [`releases/`](releases/) —
**distributable** (DS5002 firmware loaded at runtime from the `.mra`, not baked in).
> ⚠️ The romset (**`glassa`**, Break Edition) **must contain the DS5002 firmware** (`glass_ds5002fp_sram.bin`,
> CRC `47c9df4c`); without it the coprocessor has no code and the game hangs.

### Alligator Hunt (Gaelco, 1994)
**First Gaelco Type-2 core** (`gaelco2.cpp`, **GAE1** custom chip): **MC68000** + **DS5002FP** coprocessor
+ **OKI MSM6295**. The Type-2 video is new vs the Type-1 family (2 tilemaps + 2 sprite banks with
shadow/highlight, larger palette).

**Status: playable on MiSTer** — boot, video, audio, DS5002 coprocessor, attract demo and gameplay
validated on hardware. The DS5002 is implemented with the **mc8051** core (Oregano), like World Rally /
TH Strikes Back. CRT/analog (15 kHz) timing validated.

The DS5002 firmware is **loaded at runtime from the `.mra`** — **no firmware is included in this repo** and
**none is baked into the bitstream**. Prebuilt `aligator_20260714.rbf` in [`releases/`](releases/) —
**distributable** (DS5002 firmware loaded at runtime from the `.mra`, not baked into the bitstream),
**validated playable on MiSTer**. Or build from source (`cores/aligator/`) applying **both**
`tools/patch_dallas_runtime.py` + `tools/patch_scratch_runtime.py` (the first builds the runtime program
PROM, the second the runtime data SCRATCH of the DS5002 — **both are required** for a distributable `.rbf`
without the freeze).
> ⚠️ The romset **must contain the DS5002 firmware** (`aligator_ds5002fp_sram.bin`); without it the
> coprocessor has no code and the game freezes a few seconds into play.

### World Rally 2: Twin Racing (Gaelco, 1995)
**Type-2 core** (`gaelco2.cpp`, **GAE1** custom chip): **MC68000** at 13 MHz + **DS5002FP** coprocessor
(mc8051 core, 12 MHz as in Alligator Hunt). Two-player **dual-monitor** racing cabinet: the single GAE1
feeds two side-by-side screens, 5 bpp tilemaps, analog wheels (ADC) and GAE1 stereo sound (samples in the
gfx ROMs — no OKI).

**Status: playable on MiSTer** — boot, video, audio, DS5002 coprocessor and gameplay validated on
hardware. Prebuilt **`ffwrally2_20261117.rbf`** in [`releases/`](releases/) — distributable, validated on
hardware (2026-11-18).

OSD options:
- **Monitor**: **Left** / **Right** (one cabinet, 384×240, 4:3) / **Twin** (both cabinets side by side,
  768 wide, shown at **8:3 automatically**) / **Twin HDMI+VGA** (**one cabinet per MiSTer output**:
  left cabinet on the analog VGA output, right cabinet on HDMI, each 4:3). Default is **Left**.
- **Audio**: **Stereo** (cabinet 1 left speaker, cabinet 2 right, as in MAME) / **Monitor** (follows the
  Monitor option: Left or Right plays that cabinet on both speakers, Twin is stereo) / **Mix**.
- **Control Type** (1 Stick / 2 Sticks / Triggers / Wheel), **Steering** (Ramp / Pot + spring / Pot
  free) and **Ramp speed**: each cabinet is steered independently.

The DS5002 firmware is **loaded at runtime from the `.mra`** — **no firmware is included in this repo** and
**none is baked into the bitstream**. The `.mra` builds the gfx banks **entirely from the standard merged
`wrally2.zip`** (files inside their clone folders, e.g. `wrally2a/wr2_ic68.ic68`) via `<interleave>`.
The `.mra` and the `.rbf` go together: this `.mra` does not work with older `.rbf` files.
> ⚠️ The romset **must contain the DS5002 firmware** (`wrally2_ds5002fp_sram.bin`); without it the
> coprocessor has no code and the game does not boot.
> 🖥️ **Do not ship a `config/wrally2.CFG`**: the factory default (no CFG) boots Left / Original / Normal.
> 📺 Twin HDMI+VGA needs a display on each output (VGA through the MiSTer analog I/O board or an
> adapter, HDMI as usual). With `dvi_mode=1` in `MiSTer.ini` HDMI has no audio.

To build from source see [`BUILD.md`](BUILD.md#world-rally-2-coreswrally2): jtframe needs one patch
(`cores/wrally2/patches/`).

### Big Karnak (Gaelco, 1991)
The **earliest Gaelco** in this collection and the **simplest** (board REF.901112-1, **Unprotected — no
DS5002FP**, plain unencrypted VRAM). **68000 @12 MHz** with a dedicated **sound CPU**: **MC6809E** +
**YM3812 (OPL2)** + **OKI MSM6295**. The Type-1 video is the squash/thoop family (4 tilemap planes +
sprites, 4-quadrant gfx).

**Status: playable on MiSTer** — boot, video and audio validated on hardware. Video is **pixel-perfect vs
MAME** (0.00% across all test scenes); CRT/analog timing runs at **58.74 Hz**. Because the board is
unprotected there is **no coprocessor firmware** — the core needs only `bigkarnk.zip`.

Prebuilt `bigkarnk_20260701.rbf` in [`releases/`](releases/) — **distributable**, or build from source
(`cores/bigkarnk/`); no address patch and no firmware are required.
> ℹ️ Naming: the `.rbf` is `bigkarnk_YYYYMMDD.rbf` (**no `jt` prefix** — this core is not jotego's; the
> `jt` prefix is reserved for his own cores). Internal JTFRAME module names keep `jt`.

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
- ✅ **Playable on MiSTer** (validated on hardware): boot, video, audio, DS5002 coprocessor, gameplay.
- ✅ **Snow stage (Monte Carlo) glitches — FIXED:** the red bar and the "clipped spectators" were the
  **same tilemap bug** — the gfx prefetch used a single half-buffer pair, so with **flip-X** tiles the next
  tile overwrote the current one before it was consumed (neighbouring-tile pens → red / wrong pixels).
  Fixed with a **per-tile-parity double buffer** in `wrally_tilemap.v`. Verified **0-diff vs real MAME**
  on the affected frames.
- ✅ **Refresh/geometry:** **59.98 Hz** (8 MHz pixel clock, `HTOTAL`=513 → 15.6 kHz hsync), `368×232`
  (MAME native), 1-pixel display offset corrected.
- ✅ **Timing:** setup slack **+0.47 ns** — the cen-paced mc8051 wrapper/IRAM → DS5002 PROM paths are now
  covered by a `*u_mcu*` multicycle in `syn/wrally_clk48_96.sdc` (previously unconstrained → false −10 ns).
- DS5002 firmware loaded at runtime from the `.mra` (no firmware in this repo, none baked in the bitstream).
- Prebuilt `wrally_20260701.rbf` in [`releases/`](releases/) — distributable, validated playable on MiSTer.

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
- Prebuilt `aligator_20260714.rbf` in [`releases/`](releases/) — distributable, validated playable on MiSTer.
  Build from source needs **both** `tools/patch_dallas_runtime.py` (runtime program PROM) + `tools/patch_scratch_runtime.py` (runtime data SCRATCH).

### World Rally 2
- ✅ **Playable on MiSTer** (validated on hardware): boot, video, audio, DS5002 coprocessor, gameplay.
- ✅ **Dual-monitor**: OSD "Monitor" = Left / Right / Twin (8:3 automatically) / **Twin HDMI+VGA** (one cabinet per output).
- ✅ Sprites are drawn from a copy of the sprite list taken in vblank (as the real board does): fixes the split headlight beam at night.
- DS5002 firmware loaded at runtime from the `.mra` (no firmware in this repo, none baked in the bitstream).
- Prebuilt `ffwrally2_20261117.rbf` in [`releases/`](releases/) — distributable, validated on hardware.
- ⚠️ Real potentiometer wheel not yet tested on hardware (joystick/keyboard steering validated).
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
68000 @10 MHz, VRAM cifrada. **Estado: jugable en MiSTer (beta).** `squash_20260714.rbf`.

### Thunder Hoop (Gaelco, 1992) — *beta*
68000 @12 MHz, VRAM cifrada, gfx con de-interleave `[0,2,1,3]`. **Estado: funcionando en MiSTer (beta)**
(arranque, vídeo, audio). `thoop_20260714.rbf`.

### Biomechanical Toy (Gaelco, 1994/95) — *beta*
68000 @12 MHz, *VRAM plana* (sin cifrado). **Estado: funcionando en MiSTer (beta).** `biomtoy_20260714.rbf`.

### Alligator Hunt (Gaelco, 1994)
**Primer core Gaelco Tipo-2** (`gaelco2.cpp`, chip custom **GAE1**): **MC68000** + coprocesador
**DS5002FP** + **OKI MSM6295**. El vídeo Tipo-2 es nuevo respecto a la familia Tipo-1 (2 tilemaps + 2
bancos de sprites con sombras/highlights, paleta mayor).

**Estado: jugable en MiSTer** — arranque, vídeo, audio, coprocesador DS5002, demo de atracción y partida
validados en hardware. El DS5002 se implementa con el core **mc8051** (Oregano), como World Rally /
TH Strikes Back. Timing CRT/analógico (15 kHz) validado.

El firmware del DS5002 se **carga en runtime desde el `.mra`** — **no se incluye firmware en este repo** y
**no va horneado en el bitstream**. `.rbf` precompilado `aligator_20260714.rbf` en [`releases/`](releases/) —
**distribuible** (firmware del DS5002 cargado en runtime desde el `.mra`, no horneado en el bitstream),
**validado jugable en MiSTer**. O compilar desde fuente (`cores/aligator/`) aplicando **los dos**
`tools/patch_dallas_runtime.py` + `tools/patch_scratch_runtime.py` (el primero hace el PROM del programa en
runtime, el segundo el SCRATCH de datos en runtime del DS5002 — **ambos imprescindibles** para un `.rbf`
distribuible sin el freeze).
> ⚠️ El romset **debe contener el firmware del DS5002** (`aligator_ds5002fp_sram.bin`); sin él el
> coprocesador no tiene código y el juego se congela a los pocos segundos de partida.

### World Rally 2: Twin Racing (Gaelco, 1995)
**Core Tipo-2** (`gaelco2.cpp`, chip custom **GAE1**): **MC68000** a 13 MHz + coprocesador **DS5002FP**
(core mc8051, a 12 MHz como en Alligator Hunt). Recreativa de carreras de 2 jugadores con **doble
monitor**: un único GAE1 alimenta dos pantallas lado a lado, tilemaps de 5 bpp, volantes analógicos (ADC)
y sonido estéreo del GAE1 (samples en las ROMs de gfx — sin OKI).

**Estado: jugable en MiSTer** — arranque, vídeo, audio, coprocesador DS5002 y partida validados en
hardware. `.rbf` precompilado **`ffwrally2_20261117.rbf`** en [`releases/`](releases/) — distribuible,
validado en placa (2026-11-18).

Opciones del OSD:
- **Monitor**: **Left** / **Right** (una cabina, 384×240, 4:3) / **Twin** (las dos cabinas lado a lado,
  768 de ancho, a **8:3 automáticamente**) / **Twin HDMI+VGA** (**una cabina por cada salida de la
  MiSTer**: la izquierda por la salida analógica VGA y la derecha por HDMI, cada una 4:3). Por defecto
  **Left**.
- **Audio**: **Stereo** (cabina 1 por el altavoz izquierdo, cabina 2 por el derecho, como MAME) /
  **Monitor** (sigue a la opción Monitor: Left o Right suenan por los dos altavoces, Twin en estéreo) /
  **Mix**.
- **Control Type** (1 Stick / 2 Sticks / Triggers / Wheel), **Steering** (Ramp / Pot + spring / Pot
  free) y **Ramp speed**: cada cabina gira de forma independiente.

El firmware del DS5002 se **carga en runtime desde el `.mra`** — **no se incluye firmware en este repo** y
**no va horneado en el bitstream**. El `.mra` construye los bancos de gfx **enteramente desde el
`wrally2.zip` merged estándar** (ficheros en sus carpetas de clon, p.ej. `wrally2a/wr2_ic68.ic68`) con
`<interleave>`. El `.mra` y el `.rbf` van juntos: este `.mra` no funciona con `.rbf` anteriores.
> ⚠️ El romset **debe contener el firmware del DS5002** (`wrally2_ds5002fp_sram.bin`); sin él el
> coprocesador no tiene código y el juego no arranca.
> 🖥️ **No distribuir un `config/wrally2.CFG`**: el default de fábrica (sin CFG) arranca en Left / Original / Normal.
> 📺 Twin HDMI+VGA necesita una pantalla en cada salida (VGA por la placa de I/O analógica o un adaptador,
> HDMI como siempre). Con `dvi_mode=1` en `MiSTer.ini` el HDMI va sin audio.

Para compilar desde fuente ver [`BUILD.md`](BUILD.md#world-rally-2-coreswrally2-1): jtframe necesita un
parche (`cores/wrally2/patches/`).

### Big Karnak (Gaelco, 1991)
El **Gaelco más antiguo** de esta colección y el **más sencillo** (placa REF.901112-1, **sin protección —
sin DS5002FP**, VRAM plana sin cifrar). **68000 @12 MHz** con **CPU de sonido dedicada**: **MC6809E** +
**YM3812 (OPL2)** + **OKI MSM6295**. El vídeo Tipo-1 es de la familia squash/thoop (4 planos de tilemap +
sprites, gfx en 4 cuadrantes).

**Estado: jugable en MiSTer** — arranque, vídeo y audio validados en hardware. El vídeo es **pixel-perfect
vs MAME** (0.00% en todas las escenas de prueba); el timing CRT/analógico va a **58.74 Hz**. Al ser una
placa sin protección **no hay firmware de coprocesador** — el core solo necesita `bigkarnk.zip`.

`.rbf` precompilado `bigkarnk_20260701.rbf` en [`releases/`](releases/) — **distribuible**, o compilar
desde fuente (`cores/bigkarnk/`); no hace falta ningún parche de dirección ni firmware.
> ℹ️ Nomenclatura: el `.rbf` es `bigkarnk_YYYYMMDD.rbf` (**sin prefijo `jt`** — este core no es de jotego;
> el prefijo `jt` se reserva para sus propios cores). Los módulos internos de JTFRAME conservan `jt`.

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
- ✅ **Jugable en MiSTer** (validado en hardware): arranque, vídeo, audio, coprocesador DS5002, partida.
- ✅ **Glitches de la fase de nieve (Monte Carlo) — ARREGLADOS:** la barra roja y los "espectadores
  recortados" eran **el mismo bug del tilemap** — el prefetch de gfx usaba un solo par de half-buffers, y
  con tiles **flip-X** el tile siguiente pisaba el actual antes de consumirse (pens del tile vecino → rojo /
  píxeles mal). Resuelto con un **doble-buffer por paridad de tile** en `wrally_tilemap.v`. Verificado
  **0-diff vs MAME real** en los frames afectados.
- ✅ **Refresco/geometría:** **59.98 Hz** (pixel clock 8 MHz, `HTOTAL`=513 → 15.6 kHz hsync), `368×232`
  (nativo de MAME), corregido el desplazamiento de 1 píxel.
- ✅ **Timing:** setup slack **+0.47 ns** — los paths cen-paced del wrapper/IRAM del mc8051 → PROM del DS5002
  ya van cubiertos por un multicycle `*u_mcu*` en `syn/wrally_clk48_96.sdc` (antes sin constrain → falso −10 ns).
- Firmware DS5002 cargado en runtime desde la `.mra` (sin firmware en el repo, nada horneado en el bitstream).
- `.rbf` precompilado `wrally_20260701.rbf` en [`releases/`](releases/) — distribuible, validado jugable en MiSTer.

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
- `.rbf` precompilado `aligator_20260714.rbf` en [`releases/`](releases/) — distribuible, validado jugable en MiSTer.
  Compilar desde fuente requiere **los dos** `tools/patch_dallas_runtime.py` (PROM del programa en runtime) + `tools/patch_scratch_runtime.py` (SCRATCH de datos en runtime).

### World Rally 2
- ✅ **Jugable en MiSTer** (validado en hardware): arranque, vídeo, audio, coprocesador DS5002, partida.
- ✅ **Doble monitor**: OSD "Monitor" = Left / Right / Twin (8:3 automático) / **Twin HDMI+VGA** (una cabina por salida).
- ✅ Los sprites se dibujan desde una copia de la lista tomada en el vblank (como la placa real): arregla el haz de los faros partido de noche.
- Firmware del DS5002 cargado en runtime desde el `.mra` (sin firmware en el repo, sin hornear en el bitstream).
- `.rbf` precompilado `ffwrally2_20261117.rbf` en [`releases/`](releases/) — distribuible, validado en placa.
- ⚠️ Volante real de potenciómetro aún sin probar en hardware (dirección por joystick/teclado validada).
- ⚠️ Detalle cosmético menor: en la zona del acantilado algunos sprites de hierba se dibujan sobre las rocas (prioridad de sprites vs MAME); no afecta a la partida.

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

<!-- omf_release:dependencias:bigkarnk -->
## Dependencias externas de `bigkarnk`

Este repositorio contiene **solo el código de los cores**. Para compilar `bigkarnk`
hacen falta estas piezas, que se distribuyen desde su propio origen:

| Qué | De dónde | Dónde va |
|---|---|---|
| jtframe — framework de compilacion y modulos comunes (video, sdram, ram, dwnld, OSD). ⚠ NO sirve el upstream tal cual: este core lleva el fix de `pxl_cen` en jtframe_mister.sv sin el cual el CRT Adjust parte la imagen | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe` |
| fx68k — MC68000 (CPU principal): fx68k.sv, fx68kAlu.sv, uaddrPla.sv + microrom.mem/nanorom.mem | [https://github.com/jtfpga/fx68k](https://github.com/jtfpga/fx68k) | `modules/fx68k` |
| jt6295 — OKI MSM6295 (sonido ADPCM) | [https://github.com/jotego/jt6295](https://github.com/jotego/jt6295) | `modules/jt6295` |
| jtopl — YM3812 / OPL2 (sonido). Exclusivo de Big Karnak entre los cores Gaelco de esta familia | [https://github.com/jotego/jtopl](https://github.com/jotego/jtopl) | `modules/jtopl` |
<!-- /omf_release:dependencias:bigkarnk -->
<!-- omf_release:dependencias:biomtoy -->
## Dependencias externas de `biomtoy`

Este repositorio contiene **solo el código de los cores**. Para compilar `biomtoy`
hacen falta estas piezas, que se distribuyen desde su propio origen:

| Qué | De dónde | Dónde va |
|---|---|---|
| jtframe — framework de compilacion y modulos comunes (video, sdram, ram, dwnld, OSD). ⚠ NO sirve el upstream tal cual: este core lleva el fix de `pxl_cen` en jtframe_mister.sv sin el cual el CRT Adjust parte la imagen | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe` |
| fx68k — MC68000 (CPU principal): fx68k.sv, fx68kAlu.sv, uaddrPla.sv + microrom.mem/nanorom.mem | [https://github.com/jtfpga/fx68k](https://github.com/jtfpga/fx68k) | `modules/fx68k` |
| jt6295 — OKI MSM6295 (sonido ADPCM) | [https://github.com/jotego/jt6295](https://github.com/jotego/jt6295) | `modules/jt6295` |
<!-- /omf_release:dependencias:biomtoy -->
<!-- omf_release:dependencias:squash -->
## Dependencias externas de `squash`

Este repositorio contiene **solo el código de los cores**. Para compilar `squash`
hacen falta estas piezas, que se distribuyen desde su propio origen:

| Qué | De dónde | Dónde va |
|---|---|---|
| jtframe — framework de compilacion y modulos comunes (video, sdram, ram, dwnld, OSD). ⚠ NO sirve el upstream tal cual: este core lleva el fix de `pxl_cen` en jtframe_mister.sv sin el cual el CRT Adjust parte la imagen | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe` |
| fx68k — MC68000 (CPU principal): fx68k.sv, fx68kAlu.sv, uaddrPla.sv + microrom.mem/nanorom.mem | [https://github.com/jtfpga/fx68k](https://github.com/jtfpga/fx68k) | `modules/fx68k` |
| jt6295 — OKI MSM6295 (sonido ADPCM) | [https://github.com/jotego/jt6295](https://github.com/jotego/jt6295) | `modules/jt6295` |
<!-- /omf_release:dependencias:squash -->

<!-- omf_release:dependencias:thoop -->
## Dependencias externas de `thoop`

Este repositorio contiene **solo el código de los cores**. Para compilar `thoop`
hacen falta estas piezas, que se distribuyen desde su propio origen:

| Qué | De dónde | Dónde va |
|---|---|---|
| jtframe — framework de compilacion y modulos comunes (video, sdram, ram, dwnld, OSD). ⚠ NO sirve el upstream tal cual: este core lleva el fix de `pxl_cen` en jtframe_mister.sv sin el cual el CRT Adjust parte la imagen | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe` |
| fx68k — MC68000 (CPU principal): fx68k.sv, fx68kAlu.sv, uaddrPla.sv + microrom.mem/nanorom.mem | [https://github.com/jtfpga/fx68k](https://github.com/jtfpga/fx68k) | `modules/fx68k` |
| jt6295 — OKI MSM6295 (sonido ADPCM) | [https://github.com/jotego/jt6295](https://github.com/jotego/jt6295) | `modules/jt6295` |
<!-- /omf_release:dependencias:thoop -->

<!-- omf_release:dependencias:ffthoop -->
## Dependencias externas de `ffthoop`

Este repositorio contiene **solo el código de los cores**. Para compilar `ffthoop`
hacen falta estas piezas, que se distribuyen desde su propio origen:

| Qué | De dónde | Dónde va |
|---|---|---|
| jtframe — framework de compilacion y modulos comunes (video, sdram, ram, dwnld, OSD). ⚠ NO sirve el upstream tal cual: este core lleva el fix de `pxl_cen` en jtframe_mister.sv sin el cual el CRT Adjust parte la imagen | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe` |
| fx68k — MC68000 (CPU principal): fx68k.sv, fx68kAlu.sv, uaddrPla.sv + microrom.mem/nanorom.mem | [https://github.com/jtfpga/fx68k](https://github.com/jtfpga/fx68k) | `modules/fx68k` |
| jt6295 — OKI MSM6295 (sonido ADPCM) | [https://github.com/jotego/jt6295](https://github.com/jotego/jt6295) | `modules/jt6295` |
<!-- /omf_release:dependencias:ffthoop -->

<!-- omf_release:dependencias:ffwrally2 -->
## Dependencias externas de `ffwrally2`

Este repositorio contiene **solo el código de los cores**. Para compilar `ffwrally2`
hacen falta estas piezas, que se distribuyen desde su propio origen:

| Qué | De dónde | Dónde va |
|---|---|---|
| jtframe — framework de compilacion y modulos comunes (video, sdram, ram, dwnld, OSD, mc8051) | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe` |
| fx68k — MC68000 (CPU principal): fx68k.sv, fx68kAlu.sv, uaddrPla.sv | [https://github.com/jtfpga/fx68k](https://github.com/jtfpga/fx68k) | `modules/fx68k` |
| mc8051 — DS5002FP (coprocesador de proteccion): core mc8051 de Oregano Systems, distribuido dentro de jtframe. cores/wrally2/hdl/mc8051_regen.v es su regeneracion VHDL->Verilog (ghdl) vendorizada localmente. | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe/hdl/cpu/8051` |
<!-- /omf_release:dependencias:ffwrally2 -->
<!-- omf_release:dependencias:ffwrally -->
## Dependencias externas de `ffwrally`

Este repositorio contiene **solo el código de los cores**. Para compilar `ffwrally`
hacen falta estas piezas, que se distribuyen desde su propio origen:

| Qué | De dónde | Dónde va |
|---|---|---|
| jtframe — framework de compilacion y modulos comunes (video, sdram, ram, dwnld, OSD, mc8051) | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe` |
| fx68k — MC68000 (CPU principal): fx68k.sv, fx68kAlu.sv, uaddrPla.sv | [https://github.com/jtfpga/fx68k](https://github.com/jtfpga/fx68k) | `modules/fx68k` |
| mc8051 — DS5002FP (coprocesador de proteccion): core mc8051 de Oregano Systems, distribuido dentro de jtframe. cores/wrally/hdl/mc8051_regen.v es su regeneracion VHDL->Verilog (ghdl) vendorizada localmente. | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe/hdl/cpu/8051` |
| jt6295 — OKI MSM6295 (sonido ADPCM) | [https://github.com/jotego/jt6295](https://github.com/jotego/jt6295) | `modules/jt6295` |
| crt_adjust (rmonic79) — Ajuste de geometria CRT de terceros (H-Size/H-Position/V-Shift), NO es funcionalidad de jtframe -- vendorizado sin modificar dentro de jtframe, activado por cfg/macros.def (CRT_ADJUST). El wiring COMPARTIDO en jtframe_mister.sv que lo activa SI necesita un parche local para COLORW=4 -- ver cores/wrally/patches/. | [https://github.com/rmonic79/MiSTer-CRT-Adjust](https://github.com/rmonic79/MiSTer-CRT-Adjust) | `modules/jtframe/hdl/video/rmonic79` |
<!-- /omf_release:dependencias:ffwrally -->
<!-- omf_release:dependencias:ffthoop2 -->
## Dependencias externas de `ffthoop2`

Este repositorio contiene **solo el código de los cores**. Para compilar `ffthoop2`
hacen falta estas piezas, que se distribuyen desde su propio origen:

| Qué | De dónde | Dónde va |
|---|---|---|
| jtframe — framework de compilacion y modulos comunes (video, sdram, ram, dwnld, OSD, mc8051) | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe` |
| fx68k — MC68000 (CPU principal): fx68k.sv, fx68kAlu.sv, uaddrPla.sv | [https://github.com/jtfpga/fx68k](https://github.com/jtfpga/fx68k) | `modules/fx68k` |
| mc8051 — DS5002FP (coprocesador de proteccion): core mc8051 de Oregano Systems, distribuido dentro de jtframe. cores/thoop2/hdl/mc8051_regen.v es su regeneracion VHDL->Verilog (ghdl) vendorizada localmente. | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe/hdl/cpu/8051` |
| jt6295 — OKI MSM6295 (sonido ADPCM); aqui vendorizado dentro de cores/thoop2/hdl/ (jt6295_*.v) segun el cierre de files.yaml | [https://github.com/jotego/jt6295](https://github.com/jotego/jt6295) | `modules/jt6295` |
| crt_adjust (rmonic79) — Ajuste de geometria CRT de terceros (H-Size/H-Position/V-Shift), NO es funcionalidad de jtframe -- vendorizado sin modificar dentro de jtframe, activado por cfg/macros.def (CRT_ADJUST). COLORW=5 de thoop2 ya soportado de fabrica por el wiring compartido, sin parche local. | [https://github.com/rmonic79/MiSTer-CRT-Adjust](https://github.com/rmonic79/MiSTer-CRT-Adjust) | `modules/jtframe/hdl/video/rmonic79` |
<!-- /omf_release:dependencias:ffthoop2 -->

<!-- omf_release:dependencias:ffglass -->
## Dependencias externas de `ffglass`

Este repositorio contiene **solo el código de los cores**. Para compilar `ffglass`
hacen falta estas piezas, que se distribuyen desde su propio origen:

| Qué | De dónde | Dónde va |
|---|---|---|
| jtframe — framework de compilacion y modulos comunes (video, sdram, ram, dwnld, OSD, mc8051) | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe` |
| fx68k — MC68000 (CPU principal): fx68k.sv, fx68kAlu.sv, uaddrPla.sv | [https://github.com/jtfpga/fx68k](https://github.com/jtfpga/fx68k) | `modules/fx68k` |
| mc8051 — DS5002FP (coprocesador de proteccion): core mc8051 de Oregano Systems, distribuido dentro de jtframe. cores/glass/hdl/mc8051_regen.v es su regeneracion VHDL->Verilog (ghdl) vendorizada localmente. | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe/hdl/cpu/8051` |
| jt6295 — OKI MSM6295 (sonido ADPCM); aqui vendorizado dentro de cores/glass/hdl/ (jt6295_*.v) segun el cierre de files.yaml | [https://github.com/jotego/jt6295](https://github.com/jotego/jt6295) | `modules/jt6295` |
| crt_adjust (rmonic79) — Ajuste de geometria CRT de terceros (H-Size/H-Position/V-Shift), NO es funcionalidad de jtframe -- vendorizado sin modificar dentro de jtframe, activado por cfg/macros.def (CRT_ADJUST). COLORW=5 de glass ya soportado de fabrica por el wiring compartido, sin parche local. | [https://github.com/rmonic79/MiSTer-CRT-Adjust](https://github.com/rmonic79/MiSTer-CRT-Adjust) | `modules/jtframe/hdl/video/rmonic79` |
<!-- /omf_release:dependencias:ffglass -->

<!-- omf_release:dependencias:ffsquash -->
## Dependencias externas de `ffsquash`

Este repositorio contiene **solo el código de los cores**. Para compilar `ffsquash`
hacen falta estas piezas, que se distribuyen desde su propio origen:

| Qué | De dónde | Dónde va |
|---|---|---|
| jtframe — framework de compilacion y modulos comunes (video, sdram, ram, dwnld, OSD) | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe` |
| fx68k — MC68000 (CPU principal): fx68k.sv, fx68kAlu.sv, uaddrPla.sv + microrom.mem/nanorom.mem | [https://github.com/jtfpga/fx68k](https://github.com/jtfpga/fx68k) | `modules/fx68k` |
| jt6295 — OKI MSM6295 (sonido ADPCM) | [https://github.com/jotego/jt6295](https://github.com/jotego/jt6295) | `modules/jt6295` |
| crt_adjust (rmonic79) — Ajuste de geometria CRT de terceros (H-Size/H-Position/V-Shift), NO es funcionalidad de jtframe -- vendorizado sin modificar dentro de jtframe, activado por cfg/macros.def (CRT_ADJUST, CRT_ADJUST_HTOTAL=384/VTOTAL=272/RDBASE=64). | [https://github.com/rmonic79/MiSTer-CRT-Adjust](https://github.com/rmonic79/MiSTer-CRT-Adjust) | `modules/jtframe/hdl/video/rmonic79` |
<!-- /omf_release:dependencias:ffsquash -->
<!-- omf_release:dependencias:ffaligator -->
## Dependencias externas de `ffaligator`

Este repositorio contiene **solo el código de los cores**. Para compilar `ffaligator`
hacen falta estas piezas, que se distribuyen desde su propio origen:

| Qué | De dónde | Dónde va |
|---|---|---|
| jtframe — framework de compilacion y modulos comunes (video, sdram, ram, dwnld, OSD, mc8051) | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe` |
| fx68k — MC68000 (CPU principal): fx68k.sv, fx68kAlu.sv, uaddrPla.sv | [https://github.com/jtfpga/fx68k](https://github.com/jtfpga/fx68k) | `modules/fx68k` |
| mc8051 — DS5002FP (coprocesador de proteccion): core mc8051 de Oregano Systems, distribuido dentro de jtframe. cores/aligator/hdl/mc8051_regen.v es su regeneracion VHDL->Verilog (ghdl) vendorizada localmente. | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe/hdl/cpu/8051` |
| crt_adjust (rmonic79) — Ajuste de geometria CRT de terceros (H-Size/H-Position/V-Shift), NO es funcionalidad de jtframe -- vendorizado sin modificar dentro de jtframe, activado por cfg/macros.def (CRT_ADJUST). COLORW=5 coincide con el piloto Asterix, sin parche adicional. | [https://github.com/rmonic79/MiSTer-CRT-Adjust](https://github.com/rmonic79/MiSTer-CRT-Adjust) | `modules/jtframe/hdl/video/rmonic79` |
<!-- /omf_release:dependencias:ffaligator -->
<!-- omf_release:dependencias:ffbiomtoy -->
## Dependencias externas de `ffbiomtoy`

Este repositorio contiene **solo el código de los cores**. Para compilar `ffbiomtoy`
hacen falta estas piezas, que se distribuyen desde su propio origen:

| Qué | De dónde | Dónde va |
|---|---|---|
| jtframe — framework de compilacion y modulos comunes (video, sdram, ram, dwnld, OSD). ⚠ NO sirve el upstream tal cual: este core lleva el parche local pxl_cen_1t en jtframe_mister.sv (ver cores/biomtoy/patches/), sin el cual CRT_ADJUST + JTFRAME_SDRAM96 sale con la imagen partida. | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe` |
| fx68k — MC68000 (CPU principal): fx68k.sv, fx68kAlu.sv, uaddrPla.sv + microrom.mem/nanorom.mem | [https://github.com/jtfpga/fx68k](https://github.com/jtfpga/fx68k) | `modules/fx68k` |
| jt6295 — OKI MSM6295 (sonido ADPCM) | [https://github.com/jotego/jt6295](https://github.com/jotego/jt6295) | `modules/jt6295` |
<!-- /omf_release:dependencias:ffbiomtoy -->
