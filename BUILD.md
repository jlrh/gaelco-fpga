# Building the core (reproducible) — World Rally

🇬🇧 English (below) · [🇪🇸 Español](#compilar-el-core-reproducible--world-rally)

Steps to rebuild the `.rbf` from scratch, including the step that makes the bitstream **distributable**
(DS5002 firmware loaded at runtime, not baked in). Tested for MiSTer.

## Requirements
- A [**jtcores**](https://github.com/jotego/jtcores) checkout (brings jtframe + fx68k + jt6295 + mc8051
  as modules) and its toolchain (`setprj.sh`, `jtcore`).
- **Quartus** (the version your MiSTer board needs).
- **Python 3** (for the patch step).
- Your World Rally **ROMs** (not included) — see [`DETAILS.md`](DETAILS.md).

## Steps

1. **Place the core** inside jtcores:
   ```
   cp -r cores/wrally  <jtcores>/cores/wrally
   ```

2. **Generate the project** (without compiling yet):
   ```
   cd <jtcores> && source setprj.sh
   jtcore wrally -mister
   ```
   This creates `<jtcores>/cores/wrally/mister/` with the Quartus project and the generated GAMETOP
   `jtwrally_game_sdram.v`.

3. **Runtime-DS5002 patch (REQUIRED for a distributable `.rbf`):**
   ```
   python3 cores/wrally/tools/patch_dallas_runtime.py \
       <jtcores>/cores/wrally/mister/jtwrally_game_sdram.v
   ```
   Without this step, jtframe generates the `wrdallas` block with `raw_addr` (22-bit, overflows at
   0x400000) + a single-clock `jtframe_prom` → the only option would be to **bake** the firmware into the
   bitstream (copyrighted `.rbf`). The script switches it to the full address + a dual-clock
   `jtframe_dual_ram`, so the firmware is **loaded at runtime** from the `.mra` (like the real NVSRAM).
   See the detailed why in the header of
   [`cores/wrally/tools/patch_dallas_runtime.py`](cores/wrally/tools/patch_dallas_runtime.py). The script
   is idempotent.

4. **Compile with Quartus** (like any jtframe core), e.g.:
   ```
   jtcore wrally -mister -c     # or open the .qpf in Quartus and compile
   ```
   The result is `mister/output_files/jtwrally.rbf`.

## The `.mra`
The `.mra` (`cores/wrally/mra/`) already includes `wrdallas.bin` (CRC `547d1768`) in the PROM region at
0x400000, so the DS5002 firmware enters the download stream and is read by the step-3 `jtframe_dual_ram`.

## Simulation
To simulate (Verilator) the step-3 patch is **not** needed: the global template uses `jtframe_prom` with
`SIMFILE` and loads `wrdallas.bin` via `$readmemh`.

## Legal / distribution
- This repo's **code** is GPLv3 and contains no ROMs or firmware.
- The **`.rbf` in [`releases/`](releases/)** was built with these steps: the DS5002 firmware is NOT inside
  → it is **distributable**. (Validated on HW: signature `A53E` = the DS5002 boots with the firmware
  loaded at runtime.) The game **ROMs** are provided by each user.

## World Rally 2 (`cores/wrally2/`)
World Rally 2 builds like any jtframe core, with three differences:

1. **No DS5002 address patch is needed.** The core is `SDRAM_LARGE` (24-bit addressing), so the firmware
   in the `.mra` loads at runtime via the standard PROM path — the `.rbf` is distributable as-is.

2. **jtframe needs two patches** (shared framework files, so they ship as a script and a patch). From the
   root of a [jtcores](https://github.com/jotego/jtcores) checkout (tested base: `8b626a5`) with this
   repo's `cores/wrally2/` copied into `cores/wrally2/`:
   ```
   python3 cores/wrally2/tools/patch_twin_arx.py modules/jtframe/target/mister/hdl/jtframe_mister.sv
   patch -p1 < cores/wrally2/patches/jtframe_wrally2.patch
   ```
   `patch_twin_arx.py` makes the OSD "Original" aspect resolve to 8:3 in Twin. `jtframe_wrally2.patch`
   adds the Twin HDMI+VGA output, the DS5002 PROM clock and the SDRAM cache fix — see
   [`cores/wrally2/patches/README.md`](cores/wrally2/patches/README.md).

3. **Build macros of the release** (not in `cfg/macros.def`, passed on the command line):
   ```
   jtcore wrally2 -t mister -d JTFRAME_TWIN_FB -d MISTER_FB -d WRALLY2_VRAM_SHARE -d JTFRAME_NOHQ2X -d WRALLY2_DUAL_SPR
   ```
   Before Quartus runs, add these two lines at the **end** of the generated `.qsf`:
   ```
   set_global_assignment -name ALLOW_POWER_UP_DONT_CARE OFF
   set_global_assignment -name SDC_FILE <path>/cores/wrally2/syn/wrally2_clk48_96.sdc
   ```
   The `.sdc` is already in the project, but Quartus reads it before `sys_top.sdc` creates the PLL clocks,
   so its clk48↔clk96 multicycles are ignored unless it is read again at the end.

**ROMs:** the `.mra` builds the gfx banks from the standard merged `wrally2.zip`. **No ROMs or firmware are
in this repo.**

**Default screen mode:** do **not** distribute a `config/wrally2.CFG`. With no CFG the core boots at its
factory default (Monitor = Left, single 4:3, Aspect = Original, Scale = Normal) — playable from boot.

---

# Compilar el core (reproducible) — World Rally

🇪🇸 Español · [🇬🇧 English ↑](#building-the-core-reproducible--world-rally)

Pasos para reconstruir el `.rbf` desde cero, incluido el paso que hace el bitstream **distribuible**
(firmware del DS5002 cargado en runtime, no horneado). Probado para MiSTer.

## Requisitos
- Un checkout de [**jtcores**](https://github.com/jotego/jtcores) (trae jtframe + fx68k + jt6295 + mc8051
  como módulos) y su toolchain (`setprj.sh`, `jtcore`).
- **Quartus** (la versión que pida tu placa MiSTer).
- **Python 3** (para el paso del parche).
- Tus **ROMs** de World Rally (no se incluyen) — ver [`DETAILS.md`](DETAILS.md).

## Pasos

1. **Coloca el core** dentro de jtcores:
   ```
   cp -r cores/wrally  <jtcores>/cores/wrally
   ```

2. **Genera el proyecto** (sin compilar todavía):
   ```
   cd <jtcores> && source setprj.sh
   jtcore wrally -mister
   ```
   Esto crea `<jtcores>/cores/wrally/mister/` con el proyecto Quartus y el GAMETOP generado
   `jtwrally_game_sdram.v`.

3. **Parche del DS5002 en runtime (IMPRESCINDIBLE para un `.rbf` distribuible):**
   ```
   python3 cores/wrally/tools/patch_dallas_runtime.py \
       <jtcores>/cores/wrally/mister/jtwrally_game_sdram.v
   ```
   Sin este paso, jtframe genera el bloque `wrdallas` con `raw_addr` (22 bits, desborda en 0x400000) +
   `jtframe_prom` de un reloj → la única salida sería **hornear** el firmware en el bitstream (.rbf con
   copyright). El script lo cambia a dirección completa + `jtframe_dual_ram` doble reloj, de modo que el
   firmware se **carga en runtime** desde el `.mra` (como la NVSRAM real). Ver el porqué detallado en la
   cabecera de [`cores/wrally/tools/patch_dallas_runtime.py`](cores/wrally/tools/patch_dallas_runtime.py).
   El script es idempotente.

4. **Compila con Quartus** (como cualquier core jtframe), p.ej.:
   ```
   jtcore wrally -mister -c     # o abre el .qpf en Quartus y compila
   ```
   El resultado es `mister/output_files/jtwrally.rbf`.

## El `.mra`
El `.mra` (`cores/wrally/mra/`) ya incluye `wrdallas.bin` (CRC `547d1768`) en la región PROM a 0x400000,
para que el firmware del DS5002 entre en el stream de descarga y lo lea el `jtframe_dual_ram` del paso 3.

## Simulación
Para simular (Verilator) **no** hace falta el parche del paso 3: la plantilla global usa `jtframe_prom`
con `SIMFILE` y carga `wrdallas.bin` por `$readmemh`.

## Legalidad / distribución
- El **código** de este repo es GPLv3 y no contiene ROMs ni firmware.
- El **`.rbf` de [`releases/`](releases/)** se compiló con estos pasos: el firmware del DS5002 NO va
  dentro → es **distribuible**. (Validado en HW: firma `A53E` = el DS5002 arranca con el firmware
  cargado por runtime.) Las **ROMs** del juego las aporta cada usuario.

## World Rally 2 (`cores/wrally2/`)
World Rally 2 se compila como cualquier core jtframe, con tres diferencias:

1. **No hace falta parche de dirección del DS5002.** El core es `SDRAM_LARGE` (direccionamiento de 24 bits),
   así que el firmware del `.mra` carga en runtime por el camino PROM estándar — el `.rbf` es distribuible
   tal cual.

2. **jtframe necesita dos parches** (son ficheros compartidos del framework, por eso van como script y
   parche). Desde la raíz de un clon de [jtcores](https://github.com/jotego/jtcores) (base probada:
   `8b626a5`) con el `cores/wrally2/` de este repo copiado en `cores/wrally2/`:
   ```
   python3 cores/wrally2/tools/patch_twin_arx.py modules/jtframe/target/mister/hdl/jtframe_mister.sv
   patch -p1 < cores/wrally2/patches/jtframe_wrally2.patch
   ```
   `patch_twin_arx.py` hace que el aspecto "Original" del OSD salga a 8:3 en Twin. `jtframe_wrally2.patch`
   añade la salida Twin HDMI+VGA, el reloj de la PROM del DS5002 y el arreglo de la caché de SDRAM — ver
   [`cores/wrally2/patches/README.md`](cores/wrally2/patches/README.md).

3. **Macros de la release** (no están en `cfg/macros.def`, van en la línea de órdenes):
   ```
   jtcore wrally2 -t mister -d JTFRAME_TWIN_FB -d MISTER_FB -d WRALLY2_VRAM_SHARE -d JTFRAME_NOHQ2X -d WRALLY2_DUAL_SPR
   ```
   Antes de que corra Quartus, añade estas dos líneas al **final** del `.qsf` generado:
   ```
   set_global_assignment -name ALLOW_POWER_UP_DONT_CARE OFF
   set_global_assignment -name SDC_FILE <ruta>/cores/wrally2/syn/wrally2_clk48_96.sdc
   ```
   El `.sdc` ya está en el proyecto, pero Quartus lo lee antes de que `sys_top.sdc` cree los relojes de la
   PLL y sus multicycle clk48↔clk96 se ignoran si no se vuelve a leer al final.

**ROMs:** el `.mra` construye los bancos de gfx desde el `wrally2.zip` merged estándar. **No hay ROMs ni
firmware en este repo.**

**Modo de pantalla por defecto:** **no** distribuyas un `config/wrally2.CFG`. Sin CFG el core arranca en su
default de fábrica (Monitor = Left, individual 4:3, Aspect = Original, Scale = Normal) — jugable desde el arranque.
