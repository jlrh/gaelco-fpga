`default_nettype none

module aligator_video_top #(
    parameter integer LAT      = 14,
    parameter integer DEADJ    = 0,
    parameter integer SPR_HDLY = 15
)(
    input  wire        clk,
    input  wire        clk96,
    input  wire        rst,
    input  wire        ce_pix,

    input  wire [15:0] vreg0, vreg1, vreg2,

    output wire [13:0] tp0_idx, input wire [31:0] tp0_q,
    output wire [13:0] tp1_idx, input wire [31:0] tp1_q,
    output wire [14:0] wrd_a,   input wire [15:0] wrd_q,
    output wire [14:0] spr_a,   input wire [15:0] spr_q,
    output wire [11:0] pal_a,   input wire [15:0] pal_q,

    output wire [21:0] rom_a0,  input wire [31:0] gfx0_data, input wire gfx0_ok,
    output wire [21:0] rom_a1,  input wire [31:0] gfx1_data, input wire gfx1_ok,
    output wire [21:0] rom_as,  input wire [31:0] gfxs_data, input wire gfxs_ok,

    output wire [4:0]  vga_r, vga_g, vga_b,
    output wire        hsync, vsync, hblank, vblank, de,
    output wire        vblank_irq
);

    wire [9:0] hpos; wire [8:0] vpos; wire frame_end;
    wire hs_i, vs_i, hb_i, vb_i, de_i;
    aligator_video_timing u_timing (
        .clk(clk), .rst(rst), .ce_pix(ce_pix),
        .hpos(hpos), .vpos(vpos), .frame_end(frame_end),
        .hsync(hs_i), .vsync(vs_i), .hblank(hb_i), .vblank(vb_i),
        .de(de_i), .vblank_irq(vblank_irq)
    );

    wire [7:0] d0_p0=gfx0_data[15:8], d0_p1=gfx0_data[7:0], d0_p2=gfx0_data[31:24], d0_p3=gfx0_data[23:16];
    wire [7:0] d1_p0=gfx1_data[15:8], d1_p1=gfx1_data[7:0], d1_p2=gfx1_data[31:24], d1_p3=gfx1_data[23:16];
    wire [7:0] ds_p0=gfxs_data[15:8], ds_p1=gfxs_data[7:0], ds_p2=gfxs_data[31:24], ds_p3=gfxs_data[23:16];

    wire [11:0] pal_index; wire opaque;
    aligator_gae1_video u_video (
        .clk(clk), .ce(ce_pix), .hpos(hpos), .vpos(vpos), .frame_end(frame_end),
        .vreg0(vreg0), .vreg1(vreg1),
        .wrd_a(wrd_a), .wrd_q(wrd_q),
        .tp0_idx(tp0_idx), .tp0_q(tp0_q),
        .rom_a0(rom_a0), .d0_p0(d0_p0), .d0_p1(d0_p1), .d0_p2(d0_p2), .d0_p3(d0_p3), .gfx0_ok(gfx0_ok),
        .tp1_idx(tp1_idx), .tp1_q(tp1_q),
        .rom_a1(rom_a1), .d1_p0(d1_p0), .d1_p1(d1_p1), .d1_p2(d1_p2), .d1_p3(d1_p3), .gfx1_ok(gfx1_ok),
        .pal_index(pal_index), .opaque(opaque)
    );

    reg [8:0] vpos_d;
    always @(posedge clk) vpos_d <= vpos;
    wire line_change = (vpos != vpos_d);
    wire rbank = vpos[0];

    wire boot_skip;
`ifdef ALIGATOR_SCENE
    assign boot_skip = 1'b0;
`elsif SIMULATION
    reg [15:0] frm = 0;
    always @(posedge clk) if (line_change && vpos==9'd0) frm <= frm + 16'd1;
    assign boot_skip = (frm < 16'd150);
`else
    assign boot_skip = 1'b0;
`endif

    reg [8:0] vpos96, vpos96_d; reg fe96;
    always @(posedge clk96) begin vpos96 <= vpos; vpos96_d <= vpos96; fe96 <= frame_end; end
    wire       line_change96 = (vpos96 != vpos96_d);

    wire [8:0] next_vpos96   = fe96 ? 9'd0 : vpos96 + 9'd1;
    wire [8:0] render_line   = next_vpos96 + 9'd16;
    wire       wbank         = next_vpos96[0];

    reg spr_start;
    always @(posedge clk96 or posedge rst) begin
        if (rst) spr_start <= 1'b0; else spr_start <= line_change96 & ~boot_skip;
    end

    reg [9:0] hd [0:31];
    integer hh;
    always @(posedge clk) if (ce_pix) begin
        hd[0] <= hpos;
        for (hh=1; hh<32; hh=hh+1) hd[hh] <= hd[hh-1];
    end
    wire [9:0] hpos_lb = hd[SPR_HDLY-1];
    wire [16:0] lb_q;
    aligator_gae1_sprite u_spr (
        .clk(clk96), .ce(1'b1), .start(spr_start), .line(render_line),
        .vreg0(vreg0), .vreg1(vreg1), .busy(),
        .spr_a(spr_a), .spr_q(spr_q),
        .rom_a(rom_as), .d_p0(ds_p0), .d_p1(ds_p1), .d_p2(ds_p2), .d_p3(ds_p3), .gfx_ok(gfxs_ok),
        .lb_x(hpos_lb[8:0]), .lb_q(lb_q),
        .wbank(wbank), .rbank(rbank)
    );

    wire        spr_v   = lb_q[16];
    wire [3:0]  spr_var = lb_q[15:12];
    wire [11:0] spr_idx = lb_q[11:0];
    wire [11:0] base_idx = (spr_v && spr_idx!=12'd0) ? spr_idx : pal_index;
    wire [3:0]  variant  = spr_v ? spr_var : 4'd0;

    assign pal_a = base_idx;
    wire [4:0] r5, g5, b5;
    aligator_gae1_palette u_pal (.pal_word(pal_q), .variant(variant), .r(r5), .g(g5), .b(b5));

    localparam integer SD = LAT + DEADJ;
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

    assign vga_r = de ? r5 : 5'd0;
    assign vga_g = de ? g5 : 5'd0;
    assign vga_b = de ? b5 : 5'd0;

`ifdef ALIGATOR_GFXTRACE
    integer dbgn=0;
    always @(posedge clk) if (ce_pix && gfx0_ok && rom_a0!=22'd0 && dbgn<10) begin
        $display("GFXTRACE rom_a0=%h gfx0_data=%h", rom_a0, gfx0_data);
        dbgn <= dbgn + 1;
    end
`endif
endmodule

`default_nettype wire
