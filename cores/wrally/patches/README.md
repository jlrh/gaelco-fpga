# `patches/` — parches locales a `jtroot/modules` (gitignorado)

`jtroot/` (el `$JTROOT` propio de este core, ver `tools/_wrally_jtframe.sh`) **no se versiona**: es
una copia de `Gaelco/jt_ref/jtcores/modules` regenerable en cualquier momento. Si alguna vez hay que
rehacer `jtroot/` desde cero (copia perdida, máquina nueva, etc.), estos parches se pierden con ella
y hay que reaplicarlos a mano.

## `jtframe_mister-crt_adjust-colorw4.patch`

Extiende el CRT Adjust de terceros (rmonic79) — ya integrado en el `jtframe_mister.sv` compartido,
activado con la macro `CRT_ADJUST` de `cfg/macros.def` — para soportar `COLORW=4` (el color nativo
`xBRG_444` de `wrally`). El wiring original solo soportaba `COLORW=5` (piloto Asterix) y `COLORW=8`
(Cowboys); sin el parche, activar `CRT_ADJUST` con `COLORW=4` compilaba pero **rompía los colores en
pantalla** (bug real, 2026-09-17: `arcade_video` recibía `DW=12` en vez de los 24 bits reales que
entrega `crt_adjust.sv` — ver el propio parche para el detalle completo, va comentado).

Para reaplicarlo tras regenerar `jtroot/` (copiando de nuevo `modules/` desde el checkout
compartido `Gaelco/jt_ref/jtcores`):

```bash
patch jtroot/modules/jtframe/target/mister/hdl/jtframe_mister.sv < cores/wrally/patches/jtframe_mister-crt_adjust-colorw4.patch
```

(`-p1 -d ...` falla porque las cabeceras del `.patch` llevan rutas absolutas de dos máquinas/
checkouts distintos que no comparten prefijo — pasar el fichero destino directo a `patch`
ignora esas cabeceras y aplica por contexto; o aplicar los cambios a mano, son pocas líneas,
el propio `.patch` lleva el contexto necesario).

## Fix 2026-09-18 — `CRT_ADJUST` + `JTFRAME_SDRAM96`: imagen partida y RDBASE a mitad

Dos bugs del wiring genérico `CRT_ADJUST` de `jtframe_mister.sv` (no específicos de `wrally`,
ver `metodologia-cores_FPGA/_inbox/gaelco-20260918-crt-adjust-jtframe-sdram96-checklist-otros-cores.md`
y su ficha hermana `squash-20260918-...`), confirmados también aquí porque `wrally` define a la
vez `JTFRAME_SDRAM96` y `CRT_ADJUST`:

1. **Imagen partida en dos (mitades intercambiadas)**: `clk_sys` con `JTFRAME_SDRAM96` es
   `clk96`, pero `pxl_cen` lo sigue generando el juego a `clk48` → el pulso dura 2 ciclos de
   `clk_sys` → el puntero de escritura de `crt_adjust.sv` avanza el doble por píxel. Fix: ya
   estaba corregido en el checkout compartido (commit `92e03d1`, 2026-09-18) pero la copia de
   `jtroot/` de este repo era anterior a ese commit y no lo traía. Se resolvió **re-copiando
   `jtroot/modules/jtframe/target/mister/hdl/jtframe_mister.sv` fresco desde el checkout
   compartido** (ya con el fix) y reaplicando este mismo parche de `COLORW=4` encima — por eso
   el `.patch` ya no lleva el edge-detect como diff local: vive en el baseline compartido.
2. **`CRT_ADJUST_RDBASE` a mitad del valor correcto** (imagen ESTRECHA con CRT Adjust activo,
   H-Size no la recupera): la fórmula `(clk_sys/pixel_clock)*4` usaba `clk_sys=48MHz` por
   analogía con `asterix` (que no define `SDRAM96`); con `SDRAM96` real es `clk_sys=96MHz` →
   `CRT_ADJUST_RDBASE` pasó de `24` a `48` en `cfg/macros.def`. Esto **no** es parte de este
   `.patch` (vive en `cfg/macros.def`, versionado normalmente).

**Si se regenera `jtroot/` de nuevo**: mientras el checkout compartido siga por delante del
commit `92e03d1` (o posterior), no hace falta ningún parche extra para el edge-detect — solo
reaplicar este `.patch` de `COLORW=4`. Comprobar igualmente con
`grep -n pxl_cen_1t jtroot/modules/jtframe/target/mister/hdl/jtframe_mister.sv` antes de dar un
build por bueno.
