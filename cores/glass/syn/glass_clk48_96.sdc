# aligator_clk48_96.sdc — multicycle del cruce clk48<->clk96 + del mc8051 (DS5002).
# Clon del de WRally (mismo setup CLK48+SDRAM96 + mc8051 cen-paced). Cierra el -7.4ns del 1er build
# (movimiento/streaking del gradiente = lecturas gfx intermitentes por timing del clk SDRAM no cerrado).
#
# La lógica del juego corre a clk48 (clkg=clk48); los slots SDRAM y las BRAM del GAMETOP a clk96.
# Cruces clk48<->clk96 sin constraint -> TimeQuest los analiza a 1 ciclo de clk96 (10.4ns) -> fallan.
# clk48 = clk96/2 EN FASE (misma PLL) -> multicycle setup 2 / hold 1 (relación 2:1, correcto y seguro).

set CLK48  {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}
set CLK96A {emu|pll|pll_inst|altera_pll_i|general[4].gpll~PLL_OUTPUT_COUNTER|divclk}
set CLK96B {emu|pll|pll_inst|altera_pll_i|general[5].gpll~PLL_OUTPUT_COUNTER|divclk}

foreach C96 [list $CLK96A $CLK96B] {
    set_multicycle_path -from [get_clocks $CLK48] -to [get_clocks $C96] -setup -end 2
    set_multicycle_path -from [get_clocks $CLK48] -to [get_clocks $C96] -hold  -end 1
    set_multicycle_path -from [get_clocks $C96] -to [get_clocks $CLK48] -setup -end 2
    set_multicycle_path -from [get_clocks $C96] -to [get_clocks $CLK48] -hold  -end 1
}

# === mc8051 (DS5002): paths internos del core Oregano son CEN-PACED (avanza en cen_eff=clk48/4/12) ===
# Lógica combinacional muy profunda (ALU/control) que solo cambia cada ~48 ciclos -> MULTICICLO.
# Multicycle 4 cierra con holgura sin tocar el RTL.
set_multicycle_path -from [get_registers {*u_core*}] -setup -end 4
set_multicycle_path -from [get_registers {*u_core*}] -hold  -end 3
# El worst-path real (V001/V002, -7.8ns) NO sale de u_core: es rom_data_q (wrapper u_mcu) -> u_core
# (control_mem del mc8051). rom_data_q lo retiene cen_eff (se mantiene estable toda la ventana cen,
# el core solo lo muestrea en su tick) -> tambien CEN-PACED -> relajar la ENTRADA a u_core es seguro.
# Esto NO toca la frontera SDRAM->rom_data_q (esa es captura EN rom_data_q, no -to {*u_core*}).
set_multicycle_path -to [get_registers {*u_core*}] -setup -end 4
set_multicycle_path -to [get_registers {*u_core*}] -hold  -end 3
# CRITICO (V006 seguia a -7.077): los worst-paths NO tocan registros {*u_core*} en sus EXTREMOS, asi que
# el -from/-to {*u_core*} de arriba NO los cubria. Son del tipo  <fuente cen-paced del wrapper u_mcu>
# -> (comb decode/PC del mc8051 dentro de u_core) -> <sink retenido del wrapper>:
#   rom_data_q -> ... -> rom_addr_r   (path #1, -7.077)
#   u_iram     -> ... -> rom_addr_r   (siguiente, -1.319)
# TODO el subsistema u_mcu (u_core + u_iram + rom_data_q/xdata_din_q + rom_addr_r/x_*_r) avanza SOLO en
# cen_eff (~cada 48 clk): las fuentes se retienen estables toda la ventana y los sinks solo se consumen
# al siguiente cen_eff -> CEN-PACED -> multicycle seguro. Se constrain (a) las FUENTES retenidas y
# (b) los SINKS retenidos del wrapper. OJO: NO tocar el divisor de cen (divcnt/cen_div), que es full-rate.
set_multicycle_path -from [get_registers {*u_mcu|rom_data_q*}]  -setup -end 4
set_multicycle_path -from [get_registers {*u_mcu|rom_data_q*}]  -hold  -end 3
set_multicycle_path -from [get_registers {*u_mcu|xdata_din_q*}] -setup -end 4
set_multicycle_path -from [get_registers {*u_mcu|xdata_din_q*}] -hold  -end 3
set_multicycle_path -to   [get_registers {*u_mcu|rom_addr_r*}]  -setup -end 4
set_multicycle_path -to   [get_registers {*u_mcu|rom_addr_r*}]  -hold  -end 3
set_multicycle_path -to   [get_registers {*u_mcu|x_addr_r*}]    -setup -end 4
set_multicycle_path -to   [get_registers {*u_mcu|x_addr_r*}]    -hold  -end 3
set_multicycle_path -to   [get_registers {*u_mcu|x_dout_r*}]    -setup -end 4
set_multicycle_path -to   [get_registers {*u_mcu|x_dout_r*}]    -hold  -end 3
set_multicycle_path -to   [get_registers {*u_mcu|x_wr_r*}]      -setup -end 4
set_multicycle_path -to   [get_registers {*u_mcu|x_wr_r*}]      -hold  -end 3
set_multicycle_path -to   [get_registers {*u_mcu|x_acc_r*}]     -setup -end 4
set_multicycle_path -to   [get_registers {*u_mcu|x_acc_r*}]     -hold  -end 3
# La IRAM interna del mc8051 (u_iram) tambien va a cen_eff (jtframe_ram_rst cen=cen_eff): entradas
# (addr/data/we de u_core) y salida (q a u_core) cen-paced, y su path interno WE_REG->datain_reg igual.
set_multicycle_path -from [get_registers {*u_mcu|u_iram*}] -setup -end 4
set_multicycle_path -from [get_registers {*u_mcu|u_iram*}] -hold  -end 3
set_multicycle_path -to   [get_registers {*u_mcu|u_iram*}] -setup -end 4
set_multicycle_path -to   [get_registers {*u_mcu|u_iram*}] -hold  -end 3

# VU-meter del OSD (cruce de audio, DISPLAY) -> false_path (cosmético, no afecta al juego).
set_false_path -to [get_registers {*jtframe_vumeter*}]
