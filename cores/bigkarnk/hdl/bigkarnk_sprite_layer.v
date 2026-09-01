`default_nettype none

module bigkarnk_sprite_layer #(
    parameter VTOTAL = 272,
    parameter integer YOFFS = 16
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [8:0]  vpos,
    input  wire [8:0]  hpos,

    output wire [10:0] spr_a,  input wire [15:0] spr_q,
    output wire [19:0] rom_a,  input wire [7:0] d_p0, d_p1, d_p2, d_p3, input wire gfx_ok,

    output wire [12:0] lb_q,
    output wire        busy
);
    reg [8:0] vpos_d;
    always @(posedge clk) vpos_d <= vpos;
    wire line_change = (vpos != vpos_d);

    wire [8:0] next_vpos = (vpos == VTOTAL-1) ? 9'd0 : (vpos + 9'd1);
    wire       rbank = vpos[0];
    wire       wbank = next_vpos[0];

    wire boot_skip;
`ifdef BIGKARNK_SCENE
    assign boot_skip = 1'b0;
`elsif SIMULATION
    reg [15:0] frm = 0;
    always @(posedge clk) if (line_change && vpos==9'd0) frm <= frm + 16'd1;
    assign boot_skip = (frm < 16'd140);
`else
    assign boot_skip = 1'b0;
`endif

    reg start;
    always @(posedge clk or posedge rst) begin
        if (rst) start <= 1'b0; else start <= line_change & ~boot_skip;
    end

    bigkarnk_sprite_engine u_spr (
        .clk(clk), .ce(1'b1), .start(start), .line(next_vpos + YOFFS[8:0]), .busy(busy),
        .spr_a(spr_a), .spr_q(spr_q),
        .rom_a(rom_a), .d_p0(d_p0), .d_p1(d_p1), .d_p2(d_p2), .d_p3(d_p3), .gfx_ok(gfx_ok),
        .lb_x(hpos), .lb_q(lb_q),
        .wbank(wbank), .rbank(rbank)
    );
endmodule

`default_nettype wire
