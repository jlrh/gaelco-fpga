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

Para reaplicarlo tras regenerar `jtroot/`:

```bash
patch -p1 -d jtroot/modules/jtframe/target/mister/hdl < cores/wrally/patches/jtframe_mister-crt_adjust-colorw4.patch
```

(o aplicar los cambios a mano, son pocas líneas — el propio `.patch` lleva el contexto necesario).
