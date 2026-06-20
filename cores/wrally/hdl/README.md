# `hdl/` — World Rally core sources

🇬🇧 English (below) · [🇪🇸 Español](#español)

The only file written by hand for jtframe is **`jtwrally_game.v`**; `jtcore` auto-generates the GAMETOP
wrapper (`jtwrally_game_sdram.v`) from `cfg/mem.yaml`. Everything else is the core logic. The `jt`/`jtframe_`
prefixes are JTFRAME framework conventions, not authorship marks.

### Top / board
| File | Purpose |
|---|---|
| `jtwrally_game.v` | Game top for jtframe (the only module we write); wires the board to the SDRAM/download/BRAM slots. |
| `wrally_main.v` | Synthesizable "PCB": MC68000 (fx68k) + DS5002 + memory map + bus protocol + IRQ6 + shared RAM + VRAM decrypt. |

### DS5002FP MCU (the Dallas coprocessor)
| File | Purpose |
|---|---|
| `wrally_mcu.v` | Wrapper of the MCU core for the DS5002FP (mc8051/Oregano swap + cen-gate of ROM/MOVX reads). |
| `mc8051_regen.v` | The Oregano **mc8051** (8051) CPU core, auto-generated (GHDL→Verilog); runs the DS5002 firmware. |

### Clocking & 68000 bus
| File | Purpose |
|---|---|
| `wrally_clocks.v` | Clock-enable generator (68000 phi1/phi2 @12 MHz, video and OKI cens). |
| `wrally_68kdtack.v` | Generates the 68000 `/DTACK` and the co-generated CPU clock-enables (local copy of `jtframe_68kdtack_cen`). |
| `wrally_addr_decode.v` | 68000 address decoder → chip-selects per memory region. |
| `wrally_inputs.v` | Maps the named buttons/joysticks to the 68000 input ports. |
| `wrally_iolatch.v` | LS259 addressable output latch (coin counters/lockout) + OKI bank select. |

### Audio
| File | Purpose |
|---|---|
| `wrally_oki.v` | OKI MSM6295 (jt6295) glue to World Rally's 1 MB sample map. |

### Video — memory & decryption
| File | Purpose |
|---|---|
| `wrally_vmem.v` | Shared CPU↔video memories (VRAM / palette / sprite-RAM) as byte-lane block-RAMs. |
| `wrally_vram_decrypt.v` | Gaelco VRAM write decryption (gaelcrpt cipher, params P1=0x1f / P2=0x522a). |

### Video — pipeline
| File | Purpose |
|---|---|
| `wrally_video_top.v` | Video TOP for HW: timing + tilemap datapath + real-time sprites + MiSTer RGB/sync output. |
| `wrally_video_timing.v` | Video timing generator (H/V counters → visible coords, sync/blank/DE). |
| `wrally_video.v` | Tilemap datapath: two layer engines + scroll + layer/priority mix + palette. |
| `wrally_tilemap.v` | Single-layer tilemap engine (16×16, 4bpp, 64×32) → pixel for a tilemap coordinate. |
| `wrally_tile_attr.v` | Tile attribute decoder (MAME 2-word VRAM format: code/color/priority/flip). |
| `wrally_gfx_decode.v` | Tile/sprite GFX pixel decoder (16×16, 4bpp, RGN_FRAC byte-lanes). |
| `wrally_palette.v` | Palette colour converter `xBRG_444` → RGB888. |
| `wrally_sprite_layer.v` | Real-time sprite layer: double line-buffer ping-pong (render line N+1 while showing N). |
| `wrally_sprite_engine.v` | Per-line sprite engine → renders one scanline to a line buffer (incl. shadow/highlight read-modify-write). |

### Debug
| File | Purpose |
|---|---|
| `wrally_dbg_uart.v` | Debug UART transmitter (telemetry packet over MiSTer USER_IO → `/dev/ttyS1`). |

---

## Español

🇪🇸 Español · [🇬🇧 English ↑](#hdl--world-rally-core-sources)

El único fichero escrito a mano para jtframe es **`jtwrally_game.v`**; `jtcore` auto-genera el envoltorio
GAMETOP (`jtwrally_game_sdram.v`) a partir de `cfg/mem.yaml`. El resto es la lógica del core. Los prefijos
`jt`/`jtframe_` son convención del framework JTFRAME, no marca de autoría.

### Top / placa
| Fichero | Propósito |
|---|---|
| `jtwrally_game.v` | Top del juego para jtframe (el único módulo que escribimos); conecta la placa a los slots SDRAM/descarga/BRAM. |
| `wrally_main.v` | "PCB" sintetizable: MC68000 (fx68k) + DS5002 + mapa de memoria + protocolo de bus + IRQ6 + RAM compartida + descifrado VRAM. |

### MCU DS5002FP (el coprocesador Dallas)
| Fichero | Propósito |
|---|---|
| `wrally_mcu.v` | Wrapper del core MCU del DS5002FP (swap a mc8051/Oregano + cen-gate de las lecturas ROM/MOVX). |
| `mc8051_regen.v` | El core CPU **mc8051** (8051) de Oregano, auto-generado (GHDL→Verilog); ejecuta el firmware del DS5002. |

### Relojes y bus del 68000
| Fichero | Propósito |
|---|---|
| `wrally_clocks.v` | Generador de clock-enables (68000 phi1/phi2 @12 MHz, cens de vídeo y OKI). |
| `wrally_68kdtack.v` | Genera el `/DTACK` del 68000 y los clock-enables co-generados de la CPU (copia local de `jtframe_68kdtack_cen`). |
| `wrally_addr_decode.v` | Decodificador de direcciones del 68000 → chip-selects por región de memoria. |
| `wrally_inputs.v` | Mapea los botones/joysticks nombrados a los puertos de entrada del 68000. |
| `wrally_iolatch.v` | Latch direccionable LS259 (contadores/lockout de monedas) + selección de banco OKI. |

### Audio
| Fichero | Propósito |
|---|---|
| `wrally_oki.v` | Glue del OKI MSM6295 (jt6295) al mapa de samples de 1 MB de World Rally. |

### Vídeo — memoria y descifrado
| Fichero | Propósito |
|---|---|
| `wrally_vmem.v` | Memorias de vídeo compartidas CPU↔vídeo (VRAM / paleta / sprite-RAM) como block-RAM por lanes de byte. |
| `wrally_vram_decrypt.v` | Descifrado de escrituras de VRAM Gaelco (cifrado gaelcrpt, params P1=0x1f / P2=0x522a). |

### Vídeo — pipeline
| Fichero | Propósito |
|---|---|
| `wrally_video_top.v` | TOP de vídeo para HW: timing + datapath de tilemaps + sprites en tiempo real + salida RGB/sync MiSTer. |
| `wrally_video_timing.v` | Generador de timing de vídeo (contadores H/V → coords visibles, sync/blank/DE). |
| `wrally_video.v` | Datapath de tilemaps: dos motores de capa + scroll + mezcla por capa/prioridad + paleta. |
| `wrally_tilemap.v` | Motor de tilemap de una capa (16×16, 4bpp, 64×32) → pixel para una coordenada del tilemap. |
| `wrally_tile_attr.v` | Decodificador de atributos de tile (formato VRAM de 2 words de MAME: code/color/prioridad/flip). |
| `wrally_gfx_decode.v` | Decodificador de pixel de GFX de tile/sprite (16×16, 4bpp, lanes de byte RGN_FRAC). |
| `wrally_palette.v` | Conversor de color de paleta `xBRG_444` → RGB888. |
| `wrally_sprite_layer.v` | Capa de sprites en tiempo real: doble line-buffer en ping-pong (renderiza la línea N+1 mientras muestra la N). |
| `wrally_sprite_engine.v` | Motor de sprites por línea → renderiza una scanline a un line buffer (incl. read-modify-write de sombra/highlight). |

### Debug
| Fichero | Propósito |
|---|---|
| `wrally_dbg_uart.v` | Transmisor UART de debug (paquete de telemetría por USER_IO de MiSTer → `/dev/ttyS1`). |
