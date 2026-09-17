# Parches locales sobre `jtroot/` (gitignorado)

`jtroot/` no es versionable en su sitio real (está en `.gitignore`, se regenera copiando el
árbol compartido `Gaelco/jt_ref/jtcores/modules`). Cualquier cambio necesario en ese árbol para
que biomtoy funcione tiene que guardarse aquí y reaplicarse cada vez que `jtroot/` se monte de
nuevo.

## `jtframe_mister-pxl_cen_1t.patch`

Fix "imagen partida en dos" cuando `CRT_ADJUST` está activo junto con `JTFRAME_SDRAM96`
(el caso de biomtoy: `clk_sys` = clk96, pero `pxl_cen` lo genera el juego a clk48 → el pulso dura
dos ciclos de clk96 → el puntero de escritura de `crt_adjust.sv` avanza el doble de lo debido).
Detecta el flanco de `pxl_cen` (`pxl_cen_1t = pxl_cen & ~pxl_cen_d`) y lo usa en vez de `pxl_cen`
crudo para alimentar `u_crt_adjust`.

Aplicado por primera vez en la sesión que preparó el worktree de `jtcores-biomtoy-clean` (visible
como diff sin commitear en ese worktree: `modules/jtframe/target/mister/hdl/jtframe_mister.sv`).
No vive en el árbol compartido — solo en el `jtroot/` de este repo.

Reaplicar sobre `jtroot/modules/jtframe/target/mister/hdl/jtframe_mister.sv` tras cada montaje:

```bash
patch -p1 -d jtroot < cores/biomtoy/patches/jtframe_mister-pxl_cen_1t.patch
```

Commit de origen del árbol compartido en el momento de capturar el patch: `2986573e...`
(ver `jtroot/ORIGEN.txt`).
