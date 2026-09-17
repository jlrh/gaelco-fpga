`default_nettype none

module wrally_video (
    input  wire        clk,
    input  wire        ce,

    input  wire [9:0]  hpos,
    input  wire [8:0]  vpos,

    input  wire [15:0] vreg_l0y,
    input  wire [15:0] vreg_l0x,
    input  wire [15:0] vreg_l1y,
    input  wire [15:0] vreg_l1x,

    output wire [13:0] vram_a0,
    input  wire [31:0] vram_q0,
    output wire [18:0] rom_a0,
    input  wire [7:0]  d0_i07, d0_i09, d0_i11, d0_i13,
    input  wire        gfx_ok0,

    output wire [13:0] vram_a1,
    input  wire [31:0] vram_q1,
    output wire [18:0] rom_a1,
    input  wire [7:0]  d1_i07, d1_i09, d1_i11, d1_i13,
    input  wire        gfx_ok1,

    output wire [9:0]  pal_a,
    input  wire [15:0] pal_q,

    output reg  [7:0]  r,
    output reg  [7:0]  g,
    output reg  [7:0]  b,

    output reg  [2:0]  tile_level,

    output reg  [9:0]  tidx_pre
);

    wire [16:0] X = {7'b0, hpos} + 17'd8;
    wire [16:0] Y = {8'b0, vpos} + 17'd16;
    wire [16:0] s0x = X + {1'b0, vreg_l0x} + 17'd4;
    wire [16:0] s0y = Y + {1'b0, vreg_l0y};
    wire [16:0] s1x = X + {1'b0, vreg_l1x};
    wire [16:0] s1y = Y + {1'b0, vreg_l1y};
    wire [9:0] t0x = s0x[9:0];
    wire [8:0] t0y = s0y[8:0];
    wire [9:0] t1x = s1x[9:0];
    wire [8:0] t1y = s1y[8:0];

    wire [3:0] pen0, pen1;
    wire [4:0] color0, color1;
    wire       prio0, prio1;

    wrally_tilemap u_l0 (
        .clk(clk), .ce(ce), .tmx(t0x), .tmy(t0y), .layer(1'b0),
        .vram_a(vram_a0), .vram_q(vram_q0),
        .rom_a(rom_a0), .d_i07(d0_i07), .d_i09(d0_i09), .d_i11(d0_i11), .d_i13(d0_i13),
        .gfx_ok(gfx_ok0),
        .pen(pen0), .color(color0), .prio(prio0)
    );
    wrally_tilemap u_l1 (
        .clk(clk), .ce(ce), .tmx(t1x), .tmy(t1y), .layer(1'b1),
        .vram_a(vram_a1), .vram_q(vram_q1),
        .rom_a(rom_a1), .d_i07(d1_i07), .d_i09(d1_i09), .d_i11(d1_i11), .d_i13(d1_i13),
        .gfx_ok(gfx_ok1),
        .pen(pen1), .color(color1), .prio(prio1)
    );

    reg [8:0] tidx; reg [2:0] tlvl;
    always @* begin
        tidx = {color1, pen1};
        tlvl = (prio1 & (|pen1)) ? 3'd3 : 3'd1;
        if (|pen0) begin
            if (~prio0) begin
                if (3'd2 > tlvl) begin tidx = {color0, pen0}; tlvl = 3'd2; end
            end else if (~pen0[3]) begin
                if (3'd4 > tlvl) begin tidx = {color0, pen0}; tlvl = 3'd4; end
            end else begin
                tidx = {color0, pen0}; tlvl = 3'd6;
            end
        end
    end
    assign pal_a = {1'b0, tidx};

    wire [7:0] pr, pg, pb;
    wrally_palette u_pal (.pal_word(pal_q), .r(pr), .g(pg), .b(pb));
    reg [2:0] tlvl_d1;
    always @(posedge clk) if (ce) begin
        r <= pr; g <= pg; b <= pb;
        tlvl_d1 <= tlvl; tile_level <= tlvl_d1;
        tidx_pre <= {1'b0, tidx};
    end

`ifdef BAR_TMDBG

    always @(posedge clk) if (ce) begin
        if (vpos>=9'd129 && vpos<=9'd179 && tidx==9'h11e)
            $display("BARRED vpos=%0d hpos=%0d | pen1=%h col1=%h pr1=%b vram_q1=%h gfx_ok1=%b | pen0=%h col0=%h pr0=%b | tidx=%h",
                     vpos, hpos, pen1, color1, prio1, vram_q1, gfx_ok1, pen0, color0, prio0, tidx);
    end
`endif

`ifdef SIMULATION

    reg [9:0] fcnt=0; reg vpd=0;
    always @(posedge clk) if (ce) begin
        if (vpos==9'd0 && !vpd) fcnt <= fcnt + 1'b1;
        vpd <= (vpos==9'd0);
        if (fcnt<31 && fcnt>=10) begin
            if (vpos==9'd200 && hpos==10'd35)
                $display("PIXDBG f=%0d BG  vram_a1=%h vram_q1=%h | vram_a0=%h vram_q0=%h | pen1=%h col1=%h pen0=%h col0=%h tidx=%h",
                         fcnt, vram_a1, vram_q1, vram_a0, vram_q0, pen1,color1, pen0,color0, tidx);
            if (vpos==9'd80 && hpos==10'd180)
                $display("PIXDBG f=%0d VREGS L0y=%h L0x=%h L1y=%h L1x=%h (MAME: fff0 8045 ffef 0046)",
                         fcnt, vreg_l0y, vreg_l0x, vreg_l1y, vreg_l1x);
        end
    end
`endif

endmodule

`default_nettype wire
