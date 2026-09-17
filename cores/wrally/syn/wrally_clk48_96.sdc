set CLK48 {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}
set CLK96 {emu|pll|pll_inst|altera_pll_i|general[4].gpll~PLL_OUTPUT_COUNTER|divclk}

set_multicycle_path -from [get_clocks $CLK48] -to [get_clocks $CLK96] -setup -end 2
set_multicycle_path -from [get_clocks $CLK48] -to [get_clocks $CLK96] -hold  -end 1

set_multicycle_path -from [get_clocks $CLK96] -to [get_clocks $CLK48] -setup -end 2
set_multicycle_path -from [get_clocks $CLK96] -to [get_clocks $CLK48] -hold  -end 1

set_false_path -to [get_registers {*jtframe_vumeter*}]

set_multicycle_path -from [get_registers {*u_core*}] -setup -end 4
set_multicycle_path -from [get_registers {*u_core*}] -hold  -end 3
set_multicycle_path -to   [get_registers {*u_core*}] -setup -end 4
set_multicycle_path -to   [get_registers {*u_core*}] -hold  -end 3

set_multicycle_path -from [get_registers {*u_mcu*}] -setup -end 4
set_multicycle_path -from [get_registers {*u_mcu*}] -hold  -end 3
set_multicycle_path -to   [get_registers {*u_mcu*}] -setup -end 4
set_multicycle_path -to   [get_registers {*u_mcu*}] -hold  -end 3
