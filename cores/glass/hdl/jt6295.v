/*  This file is part of JT6295.
    JT6295 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT6295 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT6295.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 6-1-2020 */

module jt6295(
    input                  rst,
    input                  clk,
    input                  cen ,
    input                  ss,

    input                  wrn,
    input         [ 7:0]   din,
    output        [ 7:0]   dout,

    output        [17:0]   rom_addr,
    input         [ 7:0]   rom_data,
    input                  rom_ok,

    output signed [13:0]   sound,
    output                 sample
);

parameter INTERPOL=0;

parameter SAMPLE=0;

wire        cen_sr;
wire        cen_sr4, cen_sr4b;
wire        cen_sr32,
            cen_48k,
            cen_eff;

wire [ 3:0] busy, ack, start, stop;
wire [17:0] start_addr, stop_addr ,
            ch_addr;
wire [ 9:0] ctrl_addr;
wire [ 7:0] ch_data, ctrl_data;
wire [ 3:0] data0, data1, data2, data3, pipe_data;
wire [ 3:0] att, pipe_att;
wire        ctrl_ok, ctrl_cs, zero;
wire        pipe_en;
wire signed [11:0] pipe_snd;

assign dout   = { 4'hf, busy | start };
assign sample = SAMPLE==0 ? cen_48k : cen_eff;

jt6295_timing u_timing(
    .clk        ( clk       ),
    .cen        ( cen       ),
    .ss         ( ss        ),
    .cen_sr     ( cen_sr    ),
    .cen_sr4    ( cen_sr4   ),
    .cen_sr4b   ( cen_sr4b  ),
    .cen_sr32   ( cen_sr32  ),
    .cen_48k    ( cen_48k   )
);

jt6295_rom u_rom(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen4       ( cen_sr4       ),
    .cen32      ( cen_sr32      ),

    .adpcm_addr ( ch_addr       ),
    .ctrl_addr  ( { 8'd0, ctrl_addr } ),

    .adpcm_dout ( ch_data       ),
    .ctrl_dout  ( ctrl_data     ),

    .ctrl_ok    ( ctrl_ok       ),

    .rom_addr   ( rom_addr      ),
    .rom_data   ( rom_data      ),
    .rom_ok     ( rom_ok        )
);

jt6295_ctrl u_ctrl(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen1       ( cen_sr        ),
    .cen4       ( cen_sr4       ),

    .wrn        ( wrn           ),
    .din        ( din           ),

    .start_addr ( start_addr    ),
    .stop_addr  ( stop_addr     ),

    .att        ( att           ),

    .rom_addr   ( ctrl_addr     ),
    .rom_data   ( ctrl_data     ),
    .rom_ok     ( ctrl_ok       ),

    .start      ( start         ),
    .stop       ( stop          ),
    .busy       ( busy          ),
    .ack        ( ack           ),
    .zero       ( zero          )
);

jt6295_serial u_serial(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen_sr        ),
    .cen4       ( cen_sr4       ),

    .start_addr ( start_addr    ),
    .stop_addr  ( stop_addr     ),
    .att        ( att           ),
    .start      ( start         ),
    .stop       ( stop          ),
    .busy       ( busy          ),
    .ack        ( ack           ),
    .zero       ( zero          ),

    .rom_addr   ( ch_addr       ),
    .rom_data   ( ch_data       ),

    .pipe_en    ( pipe_en       ),
    .pipe_att   ( pipe_att      ),
    .pipe_data  ( pipe_data     )
);

jt6295_adpcm u_adpcm(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen_sr4       ),

    .en         ( pipe_en       ),
    .att        ( pipe_att      ),
    .data       ( pipe_data     ),
    .sound      ( pipe_snd      )
);

jt6295_acc #(.INTERPOL(INTERPOL)) u_acc(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen_sr        ),
    .cen4       ( cen_sr4       ),

    .sound_in   ( pipe_snd      ),
    .sound_out  ( sound         ),
    .sample     ( cen_eff       )
);

`ifdef SIMULATION
integer fsnd;
initial begin
    fsnd=$fopen("jt6295.raw","wb");
end
wire signed [15:0] snd_log = { sound, 2'b0 };
always @(posedge cen_sr) begin
    $fwrite(fsnd,"%u", {snd_log, snd_log});
end
`endif
endmodule
