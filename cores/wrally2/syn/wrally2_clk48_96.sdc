set CLK48  {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}
set CLK96A {emu|pll|pll_inst|altera_pll_i|general[4].gpll~PLL_OUTPUT_COUNTER|divclk}
set CLK96B {emu|pll|pll_inst|altera_pll_i|general[5].gpll~PLL_OUTPUT_COUNTER|divclk}

foreach C96 [list $CLK96A $CLK96B] {
    set_multicycle_path -from [get_clocks $CLK48] -to [get_clocks $C96] -setup -end 2
    set_multicycle_path -from [get_clocks $CLK48] -to [get_clocks $C96] -hold  -end 1
    set_multicycle_path -from [get_clocks $C96] -to [get_clocks $CLK48] -setup -end 2
    set_multicycle_path -from [get_clocks $C96] -to [get_clocks $CLK48] -hold  -end 1
}

if { [info exists ::env(WR2_CEN_FRAC)] && $::env(WR2_CEN_FRAC) ne "0" } {
    set MC  3 ; set MCH 2
} else {
    set MC  4 ; set MCH 3
}
post_message "WR2 mc8051 DS5002 multicycle setup=$MC hold=$MCH (env WR2_CEN_FRAC=[expr {[info exists ::env(WR2_CEN_FRAC)] ? $::env(WR2_CEN_FRAC) : {<unset>}}])"
set_multicycle_path -from [get_registers {*u_core*}] -setup -end $MC
set_multicycle_path -from [get_registers {*u_core*}] -hold  -end $MCH

set_multicycle_path -to [get_registers {*u_core*}] -setup -end $MC
set_multicycle_path -to [get_registers {*u_core*}] -hold  -end $MCH

set_multicycle_path -from [get_registers {*u_mcu|rom_data_q*}]  -setup -end $MC
set_multicycle_path -from [get_registers {*u_mcu|rom_data_q*}]  -hold  -end $MCH
set_multicycle_path -from [get_registers {*u_mcu|xdata_din_q*}] -setup -end $MC
set_multicycle_path -from [get_registers {*u_mcu|xdata_din_q*}] -hold  -end $MCH
set_multicycle_path -to   [get_registers {*u_mcu|rom_addr_r*}]  -setup -end $MC
set_multicycle_path -to   [get_registers {*u_mcu|rom_addr_r*}]  -hold  -end $MCH
set_multicycle_path -to   [get_registers {*u_mcu|x_addr_r*}]    -setup -end $MC
set_multicycle_path -to   [get_registers {*u_mcu|x_addr_r*}]    -hold  -end $MCH
set_multicycle_path -to   [get_registers {*u_mcu|x_dout_r*}]    -setup -end $MC
set_multicycle_path -to   [get_registers {*u_mcu|x_dout_r*}]    -hold  -end $MCH
set_multicycle_path -to   [get_registers {*u_mcu|x_wr_r*}]      -setup -end $MC
set_multicycle_path -to   [get_registers {*u_mcu|x_wr_r*}]      -hold  -end $MCH
set_multicycle_path -to   [get_registers {*u_mcu|x_acc_r*}]     -setup -end $MC
set_multicycle_path -to   [get_registers {*u_mcu|x_acc_r*}]     -hold  -end $MCH

set_multicycle_path -from [get_registers {*u_mcu|u_iram*}] -setup -end $MC
set_multicycle_path -from [get_registers {*u_mcu|u_iram*}] -hold  -end $MCH
set_multicycle_path -to   [get_registers {*u_mcu|u_iram*}] -setup -end $MC
set_multicycle_path -to   [get_registers {*u_mcu|u_iram*}] -hold  -end $MCH

set_false_path -to [get_registers {*jtframe_vumeter*}]
