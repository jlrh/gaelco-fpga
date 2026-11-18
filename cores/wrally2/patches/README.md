# jtframe patch for World Rally 2

`jtframe_wrally2.patch` contains every jtframe change that the released `ffwrally2_20261117.rbf` was
built with. Apply it to a clean [jtcores](https://github.com/jotego/jtcores) checkout **after**
`cores/wrally2/tools/patch_twin_arx.py`:

```
cd <jtcores>
python3 cores/wrally2/tools/patch_twin_arx.py modules/jtframe/target/mister/hdl/jtframe_mister.sv
patch -p1 < cores/wrally2/patches/jtframe_wrally2.patch
```

What it changes (the Twin and UART parts are inactive unless the core defines the macro; the PROM clock
and SDRAM parts apply to every core built from that jtframe tree, so keep this tree for World Rally 2):

| Area | Files | Why |
|------|-------|-----|
| Twin HDMI+VGA (`JTFRAME_TWIN_FB`) | `jtframe_common_ports.inc`, `game_sdram.v`, `jtframe_game_instance.v`, `jtframe_emu.sv`, `jtframe_mister.sv` | `tfb_*` ports from the game; the MiSTer framebuffer ports are enabled and the DDR3 is driven by `wrally2_twin_fb` (core `hdl/`), which draws the second cabinet on the HDMI output while the first one goes out through VGA. Automatic 8:3 aspect only for OSD mode *Twin*; *Twin HDMI+VGA* is 4:3 on each output. |
| Game UART (`JTFRAME_GAME_UART`, `JTFRAME_UART`) | `game_sdram.v`, `jtframe_emu.sv` | Connects the game's `uart_tx`/`uart_rx` and routes it to the MiSTer user port (DS5002 diagnostics). |
| DS5002 firmware PROM | `prom_dwnld.v` | The PROM read port must use `clk48`: with `JTFRAME_SDRAM96`, `clk` is 96 MHz while the DS5002 runs from the 48 MHz domain. |
| SDRAM | `game_sdram.v`, `jtframe_romrq_bcache.v` | ROM slots are generated with `OKLATCH(0)`, and the byte cache stores the second half-word one clock later so a cache line is never marked valid before both halves are written. |

Patch base: jtcores `8b626a56880657c9b2611eca527aebc5aa8684c7`. On a newer jtframe some hunks may need
to be applied by hand.
