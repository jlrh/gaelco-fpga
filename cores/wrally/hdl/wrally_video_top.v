`default_nettype none

module wrally_video_top #(
    parameter integer DEADJ = 0,

    parameter integer SPADJ = 1

)(
    input  wire        clk,
    input  wire        clk96,

    input  wire        rst,
    input  wire        ce_pix,

    input  wire [15:0] vreg_l0y, vreg_l0x, vreg_l1y, vreg_l1x,

    output wire [13:0] vram_a0,  input  wire [31:0] vram_q0,
    output wire [18:0] rom_a0,   input  wire [7:0]  d0_i07, d0_i09, d0_i11, d0_i13,
    output wire [13:0] vram_a1,  input  wire [31:0] vram_q1,
    output wire [18:0] rom_a1,   input  wire [7:0]  d1_i07, d1_i09, d1_i11, d1_i13,
    input  wire        gfx0_ok, gfx1_ok,

    output wire [9:0]  pal_a,    input  wire [15:0] pal_q,
    output wire [12:0] palb_a,   input  wire [15:0] palb_q,

    output wire [10:0] spr_a,    input  wire [15:0] spr_q,
    output wire [18:0] srom_a,   input  wire [7:0]  sd_i07, sd_i09, sd_i11, sd_i13,
    input  wire        spr_gfx_ok,
    input  wire        spr_en,

    output wire [7:0]  vga_r, vga_g, vga_b,
    output wire        hsync, vsync, hblank, vblank, de,
    output wire        ce_pix_o,
    output wire        vblank_irq
);

    localparam integer GFXLEAD = 7;
    localparam LATV = 5 + GFXLEAD;

    wire [9:0] hpos; wire [8:0] vpos;
    wire hs_i, vs_i, hb_i, vb_i, de_i;
    wrally_video_timing u_timing (
        .clk(clk), .rst(rst), .ce_pix(ce_pix),
        .hpos(hpos), .vpos(vpos),
        .hsync(hs_i), .vsync(vs_i), .hblank(hb_i), .vblank(vb_i),
        .de(de_i), .vblank_irq(vblank_irq)
    );

    wire [7:0] r_tm, g_tm, b_tm;
    wire [2:0] tile_level;
    wire [9:0] tidx_pre;
    wrally_video u_video (
        .clk(clk), .ce(ce_pix), .hpos(hpos), .vpos(vpos),
        .vreg_l0y(vreg_l0y), .vreg_l0x(vreg_l0x), .vreg_l1y(vreg_l1y), .vreg_l1x(vreg_l1x),
        .vram_a0(vram_a0), .vram_q0(vram_q0), .rom_a0(rom_a0),
        .d0_i07(d0_i07), .d0_i09(d0_i09), .d0_i11(d0_i11), .d0_i13(d0_i13),
        .vram_a1(vram_a1), .vram_q1(vram_q1), .rom_a1(rom_a1),
        .d1_i07(d1_i07), .d1_i09(d1_i09), .d1_i11(d1_i11), .d1_i13(d1_i13),
        .gfx_ok0(gfx0_ok), .gfx_ok1(gfx1_ok),
        .pal_a(pal_a), .pal_q(pal_q),
        .r(r_tm), .g(g_tm), .b(b_tm), .tile_level(tile_level), .tidx_pre(tidx_pre)
    );

    wire [11:0] sp_lbq;
    wire       sp_lbq_high;

    wrally_sprite_layer #(.VVIS(232), .VTOTAL(250)) u_spr (
        .clk(clk), .rst(rst), .ce_pix(ce_pix), .vpos(vpos), .hpos(hpos),
        .spr_a(spr_a), .spr_q(spr_q),
        .rom_a(srom_a), .d_i07(sd_i07), .d_i09(sd_i09), .d_i11(sd_i11), .d_i13(sd_i13),
        .gfx_ok(spr_gfx_ok),
        .lb_q(sp_lbq), .lb_high(sp_lbq_high), .busy()
    );

    localparam integer SPN = 3 + SPADJ + GFXLEAD;
    reg [12:0] spr_sr [0:SPN+2];
    integer si;
    always @(posedge clk) if (ce_pix) begin
        spr_sr[0] <= {sp_lbq_high, sp_lbq};
        for (si = 1; si <= SPN+2; si = si + 1) spr_sr[si] <= spr_sr[si-1];
    end

    wire       spr_shadow_a = spr_sr[SPN][11];
    wire [2:0] spr_sl_a     = spr_sr[SPN][10:8];
    wire       spr_pen_a    = (spr_sr[SPN][3:0] != 4'd0);

    assign palb_a = (spr_shadow_a & spr_pen_a) ? {spr_sl_a, 2'b10, spr_sr[SPN][7:0]}
                  : spr_shadow_a               ? {spr_sl_a, tidx_pre}
                  :                              {3'b0, 2'b10, spr_sr[SPN][7:0]};
    wire [3:0] spr_pen    = spr_sr[SPN+1][3:0];
    wire       spr_high   = spr_sr[SPN+1][12];
    wire       spr_shadow = spr_sr[SPN+1][11];

    wire [7:0] r_sp, g_sp, b_sp;
    wrally_palette u_spal (.pal_word(palb_q), .r(r_sp), .g(g_sp), .b(b_sp));

    wire       spr_present = spr_shadow | (spr_pen != 4'd0);
    wire [2:0] spr_level = spr_present ? (spr_high ? 3'd7 : 3'd5) : 3'd0;
    wire       use_spr   = spr_en & (spr_level > tile_level);
    wire [7:0] mix_r = use_spr ? r_sp : r_tm;
    wire [7:0] mix_g = use_spr ? g_sp : g_tm;
    wire [7:0] mix_b = use_spr ? b_sp : b_tm;

    localparam integer SD = LATV + DEADJ;
    reg [SD-1:0] hs_sr, vs_sr, hb_sr, vb_sr, de_sr;
    always @(posedge clk) if (ce_pix) begin
        hs_sr <= {hs_sr[SD-2:0], hs_i};
        vs_sr <= {vs_sr[SD-2:0], vs_i};
        hb_sr <= {hb_sr[SD-2:0], hb_i};
        vb_sr <= {vb_sr[SD-2:0], vb_i};
        de_sr <= {de_sr[SD-2:0], de_i};
    end
    assign hsync  = hs_sr[SD-1];
    assign vsync  = vs_sr[SD-1];
    assign hblank = hb_sr[SD-1];
    assign vblank = vb_sr[SD-1];
    assign de     = de_sr[SD-1];

    assign vga_r = de ? mix_r : 8'd0;
    assign vga_g = de ? mix_g : 8'd0;
    assign vga_b = de ? mix_b : 8'd0;
    assign ce_pix_o = ce_pix;

endmodule

`default_nettype wire
