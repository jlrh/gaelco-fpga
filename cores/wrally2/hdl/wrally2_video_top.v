`default_nettype none

module wrally2_video_top #(
    parameter integer LAT      = 14,
    parameter integer DEADJ    = 0,
    parameter integer SPR_HDLY = 15
)(
    input  wire        clk,
    input  wire        clk96,
    input  wire        rst,
    input  wire        ce_pix,
    input  wire        index,
    input  wire        twin,

    input  wire [15:0] vreg0, vreg1, vreg2,

    output wire [13:0] tp0_idx, input wire [31:0] tp0_q,
    output wire [13:0] tp1_idx, input wire [31:0] tp1_q,
    output wire [14:0] wrd_a,   input wire [15:0] wrd_q,
    output wire [14:0] spr_a,   input wire [15:0] spr_q,
    output wire [14:0] spr2_a,  input wire [15:0] spr2_q,
    output wire [11:0] pal_a,   input wire [15:0] pal_q,

    output wire [21:0] rom_a0,  input wire [31:0] gfx0_data, input wire gfx0_ok,
    output wire [21:0] rom_a1,  input wire [31:0] gfx1_data, input wire gfx1_ok,
    output wire [21:0] rom_as,  input wire [31:0] gfxs_data, input wire gfxs_ok,
    output wire [21:0] rom_as2, input wire [31:0] gfxs2_data, input wire gfxs2_ok,

    output wire [4:0]  vga_r, vga_g, vga_b,
    output wire        hsync, vsync, hblank, vblank, de,
    output wire        vblank_irq,

    input  wire        cpu_vwe,
    input  wire [14:0] cpu_vaddr
);

    wire [9:0] hpos; wire [8:0] vpos; wire frame_end;
    wire hs_i, vs_i, hb_i, vb_i, de_i;
    wrally2_video_timing u_timing (
        .clk(clk), .rst(rst), .ce_pix(ce_pix), .twin(twin),
        .hpos(hpos), .vpos(vpos), .frame_end(frame_end),
        .hsync(hs_i), .vsync(vs_i), .hblank(hb_i), .vblank(vb_i),
        .de(de_i), .vblank_irq(vblank_irq)
    );

    wire [7:0] d0_p0=gfx0_data[15:8], d0_p1=gfx0_data[7:0], d0_p2=gfx0_data[31:24], d0_p3=gfx0_data[23:16];
    wire [7:0] d1_p0=gfx1_data[15:8], d1_p1=gfx1_data[7:0], d1_p2=gfx1_data[31:24], d1_p3=gfx1_data[23:16];
    wire [7:0] ds_p0=gfxs_data[15:8], ds_p1=gfxs_data[7:0], ds_p2=gfxs_data[31:24], ds_p3=gfxs_data[23:16];
    wire [7:0] ds2_p0=gfxs2_data[15:8], ds2_p1=gfxs2_data[7:0], ds2_p2=gfxs2_data[31:24], ds2_p3=gfxs2_data[23:16];

    wire [11:0] pal_index; wire opaque;
    wire        tm_ovr_w;
    wrally2_gae1_video u_video (
        .clk(clk), .ce(ce_pix), .hpos(hpos), .vpos(vpos), .frame_end(frame_end),
        .index(index), .twin(twin),
        .vreg0(vreg0), .vreg1(vreg1),
        .wrd_a(wrd_a), .wrd_q(wrd_q),
        .tp0_idx(tp0_idx), .tp0_q(tp0_q),
        .rom_a0(rom_a0), .d0_p0(d0_p0), .d0_p1(d0_p1), .d0_p2(d0_p2), .d0_p3(d0_p3), .gfx0_ok(gfx0_ok),
        .tp1_idx(tp1_idx), .tp1_q(tp1_q),
        .rom_a1(rom_a1), .d1_p0(d1_p0), .d1_p1(d1_p1), .d1_p2(d1_p2), .d1_p3(d1_p3), .gfx1_ok(gfx1_ok),
        .pal_index(pal_index), .opaque(opaque), .tm_ovr(tm_ovr_w)
    );

    reg [8:0] vpos_d;
    always @(posedge clk) vpos_d <= vpos;
    wire line_change = (vpos != vpos_d);
    wire rbank = vpos[0];

    wire boot_skip;
`ifdef WRALLY2_SCENE
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

    wire start_l = line_change96 & ~boot_skip & (twin | ~index);
    wire start_r = line_change96 & ~boot_skip & (twin |  index);
    wire spr_busy_w;
    reg spr_start_l, spr_start_r;
    always @(posedge clk96 or posedge rst) begin
        if (rst) begin spr_start_l <= 1'b0; spr_start_r <= 1'b0; end
        else     begin spr_start_l <= start_l; spr_start_r <= start_r; end
    end

    reg [9:0] hd [0:31];
    integer hh;
    always @(posedge clk) if (ce_pix) begin
        hd[0] <= hpos;
        for (hh=1; hh<32; hh=hh+1) hd[hh] <= hd[hh-1];
    end
    wire [9:0] hpos_lb = hd[SPR_HDLY-1];

    wire [9:0] lb_x_l = hpos_lb;
    wire [9:0] lb_x_r = twin ? (hpos_lb - 10'd384) : hpos_lb;
    wire [16:0] lb_q_l, lb_q_r, lb_q;
`ifndef WRALLY2_DUAL_SPR

    wrally2_gae1_sprite #(.LBDEPTH(1024)) u_spr_l (
        .clk(clk96), .ce(1'b1), .start(spr_start_l | spr_start_r), .line(render_line),
        .index(index), .twin(twin),
        .vreg0(vreg0), .vreg1(vreg1), .busy(spr_busy_w),
        .spr_a(spr_a), .spr_q(spr_q),
        .rom_a(rom_as), .d_p0(ds_p0), .d_p1(ds_p1), .d_p2(ds_p2), .d_p3(ds_p3), .gfx_ok(gfxs_ok),
        .lb_x(hpos_lb), .lb_q(lb_q_l),
        .wbank(wbank), .rbank(rbank)
    );
    assign lb_q_r  = 17'd0;
    assign rom_as2 = 22'd0;
    assign spr2_a  = 15'd0;
    assign lb_q    = lb_q_l;
`else

    wrally2_gae1_sprite u_spr_l (
        .clk(clk96), .ce(1'b1), .start(spr_start_l), .line(render_line),
        .index(1'b0), .twin(1'b0),
        .vreg0(vreg0), .vreg1(vreg1), .busy(),
        .spr_a(spr_a), .spr_q(spr_q),
        .rom_a(rom_as), .d_p0(ds_p0), .d_p1(ds_p1), .d_p2(ds_p2), .d_p3(ds_p3), .gfx_ok(gfxs_ok),
        .lb_x(lb_x_l), .lb_q(lb_q_l),
        .wbank(wbank), .rbank(rbank)
    );
    wrally2_gae1_sprite u_spr_r (
        .clk(clk96), .ce(1'b1), .start(spr_start_r), .line(render_line),
        .index(1'b1), .twin(1'b0),
        .vreg0(vreg0), .vreg1(vreg1), .busy(),
        .spr_a(spr2_a), .spr_q(spr2_q),
        .rom_a(rom_as2), .d_p0(ds2_p0), .d_p1(ds2_p1), .d_p2(ds2_p2), .d_p3(ds2_p3), .gfx_ok(gfxs2_ok),
        .lb_x(lb_x_r), .lb_q(lb_q_r),
        .wbank(wbank), .rbank(rbank)
    );

    wire        rsel = twin ? (hpos_lb >= 10'd384) : index;
    assign lb_q = rsel ? lb_q_r : lb_q_l;
`endif

    wire        spr_v   = lb_q[16];
    wire [3:0]  spr_var = lb_q[15:12];
    wire [11:0] spr_idx = lb_q[11:0];
    wire [11:0] base_idx = (spr_v && spr_idx!=12'd0) ? spr_idx : pal_index;
    wire [3:0]  variant  = spr_v ? spr_var : 4'd0;

`ifdef WRALLY2_DBGBAND

    integer nmag=0;
    always @(posedge clk) if (ce_pix && r5==5'd31 && g5==5'd0 && b5==5'd31 && hpos<10'd384 && nmag<20) begin
        nmag <= nmag+1;
        $display("MAG vpos=%0d hpos=%0d spr_v=%b base=%h pal_q=%h", vpos, hpos, spr_v, base_idx, pal_q);
    end
`endif

    assign pal_a = base_idx;
    wire [4:0] r5, g5, b5;
    wrally2_gae1_palette u_pal (.pal_word(pal_q), .variant(variant), .r(r5), .g(g5), .b(b5));

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

`ifdef WRALLY2_OVRDBG
    wire active_i = ~vb_i;
    reg  vwe_d = 1'b0;
    always @(posedge clk) vwe_d <= cpu_vwe;
    wire vwe_rise = cpu_vwe & ~vwe_d;

    wire mf_ls = vwe_rise & active_i & (cpu_vaddr[14:11]==4'd4);
    wire mf_bs = vwe_rise & active_i & (cpu_vaddr[14:3]==12'h500);
    reg [9:0] ls_cnt=10'd0, ls_lat=10'd0, bs_cnt=10'd0, bs_lat=10'd0; reg fe_d=1'b0;
    always @(posedge clk) begin
        fe_d <= frame_end;
        if (frame_end & ~fe_d) begin ls_lat<=ls_cnt; ls_cnt<=10'd0; bs_lat<=bs_cnt; bs_cnt<=10'd0; end
        else begin
            if (mf_ls && ls_cnt<10'd1023) ls_cnt <= ls_cnt + 10'd1;
            if (mf_bs && bs_cnt<10'd1023) bs_cnt <= bs_cnt + 10'd1;
        end
    end

    reg [9:0] dxo=10'd0; reg [8:0] dyo=9'd0; reg de_d2=1'b0;
    always @(posedge clk) if (ce_pix) begin
        de_d2 <= de;
        if (de) dxo <= dxo + 10'd1; else dxo <= 10'd0;
        if (vblank) dyo <= 9'd0; else if (de & ~de_d2) dyo <= dyo + 9'd1;
    end
    wire lsbar = (dyo>=9'd4  && dyo<9'd8)  && (dxo < ls_lat);
    wire bsbar = (dyo>=9'd10 && dyo<9'd14) && (dxo < bs_lat);
    assign vga_r = ~de ? 5'd0 : lsbar ? 5'd31 : bsbar ? 5'd31 : r5;
    assign vga_g = ~de ? 5'd0 : lsbar ? 5'd0  : bsbar ? 5'd31 : g5;
    assign vga_b = ~de ? 5'd0 : lsbar ? 5'd0  : bsbar ? 5'd0  : b5;
`else

    assign vga_r = de ? r5 : 5'd0;
    assign vga_g = de ? g5 : 5'd0;
    assign vga_b = de ? b5 : 5'd0;
`endif

`ifdef WRALLY2_GFXTRACE
    integer dbgn=0;
    always @(posedge clk) if (ce_pix && gfx0_ok && rom_a0!=22'd0 && dbgn<10) begin
        $display("GFXTRACE rom_a0=%h gfx0_data=%h", rom_a0, gfx0_data);
        dbgn <= dbgn + 1;
    end
`endif
endmodule

`default_nettype wire
