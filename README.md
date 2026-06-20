# gaelco-fpga

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
├── hdl/    Verilog del core (wrally_*.v, jtwrally_game.v, wrally_dbg_uart.v, mc8051_regen.v)
├── cfg/    macros.def, mem.yaml, files.yaml
├── mra/    definición .mra (cómo ensamblar las ROMs)
├── syn/    wrally_clk48_96.sdc (constraints de timing)
└── tools/  patch_dallas_runtime.py (DS5002 en runtime) + regen del core mc8051 (ghdl → Verilog)
```

## ROMs

**No se incluyen** (material con copyright). Cada cual aporta las ROMs originales de su placa. El
`.mra` describe cómo ensamblarlas.

## Trabajos pendientes

El core es **jugable**, pero quedan cosas por pulir (no bloquean la partida):

- **Glitches rojos de sombra en la fase de nieve (Monte Carlo):**
  - *Balizas* de la carretera: aparecen como una barra roja sólida (en la placa real / MAME son
    imperceptibles, tiñen apenas la nieve blanca). Es el camino sombra-sobre-tilemap.
  - *Arco de salida*: glitches rojos a la derecha, solo en partida. El propio MAME documenta este
    glitch como un esquema de prioridad "bogus" (no hay referencia dorada).
- **Timing:** ~−9.5 ns de setup slack en un path del mc8051 (cen-paced, no funcional); falta afinar el
  multicycle del SDC para un build timing-limpio.

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
