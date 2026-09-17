`default_nettype none

module jtglass_game(
    `include "jtframe_game_ports.inc"

    ,input  wire        scr_dl_clk
    ,input  wire [14:0] scr_dl_addr
    ,input  wire [ 7:0] scr_dl_data
    ,input  wire        scr_dl_we
);

    wire clkg = clk48;

    reg [2:0] pxdiv = 3'd0;
    always @(posedge clkg) pxdiv <= (pxdiv==3'd5) ? 3'd0 : pxdiv + 3'd1;
    assign pxl_cen  = (pxdiv==3'd0);
    assign pxl2_cen = (pxdiv==3'd0) || (pxdiv==3'd3);
    wire ce_pix = (pxdiv==3'd0);

    reg [5:0] odiv = 6'd0;
    reg oki_cen = 1'b0;
    always @(posedge clkg) begin
        odiv    <= (odiv==6'd47) ? 6'd0 : odiv + 6'd1;
        oki_cen <= (odiv==6'd0);
    end

    reg [1:0] mcudiv = 2'd0;
    always @(posedge clkg) mcudiv <= mcudiv + 2'd1;
    wire mcu_cen = (mcudiv==2'd0) & dip_pause;

    wire vblank_irq;
    wire hs_w, vs_w, hb_w, vb_w, de_w;

    wire [15:0] in_dsw2, in_dsw1, in_p1, in_p2;
    glass_inputs u_inputs (
        .dipsw(dipsw[15:0]),
        .joystick1(joystick1[5:0]), .joystick2(joystick2[5:0]),
        .coin(coin[1:0]),
        .start(cab_1p[1:0]),
        .service(service),
        .port_dsw2(in_dsw2), .port_dsw1(in_dsw1), .port_p1(in_p1), .port_p2(in_p2)
    );

    wire        flip_screen;
    wire [13:0] vmem_addr; wire vmem_uds, vmem_lds, vmem_we;
    wire        vmem_cs_vram, vmem_cs_scrram, vmem_cs_pal, vmem_cs_spr;
    wire [15:0] vmem_dec_wdata, vmem_io_wdata;
    wire [15:0] cpu_vram_rd, cpu_scrram_rd, cpu_pal_rd, cpu_spr_rd;
    wire [15:0] vreg0, vreg1, vreg2, vreg3;
    wire [19:1] rom68k_addr;
    wire [19:0] oki_rom_addr;
    wire signed [13:0] snd14;
    wire        snd_sample_w;

    wire        scene_dump;
    reg  [15:0] scene_vreg_dump [0:3];
`ifdef GLASS_SCENE
    wire cpu_rst = 1'b1;
    reg [15:0] scene_vreg [0:3];
    initial $readmemh("scene_vregs.hex", scene_vreg);
    wire [15:0] vv0=scene_vreg[0], vv1=scene_vreg[1], vv2=scene_vreg[2], vv3=scene_vreg[3];
`else
    wire cpu_rst = rst;
    wire [15:0] vv0=vreg0, vv1=vreg1, vv2=vreg2, vv3=vreg3;
`endif
`ifdef SIMULATION
    reg [15:0] scene_fcnt=0; reg vbi_sd=0;
    always @(posedge clkg) begin vbi_sd<=vblank_irq; if (vblank_irq & ~vbi_sd) scene_fcnt<=scene_fcnt+1'b1; end
  `ifdef GLASS_SCENE_DUMP
    assign scene_dump = (scene_fcnt==`GLASS_SCENE_DUMP) & vblank_irq & ~vbi_sd;
    always @(posedge clkg) if (scene_dump) begin
        scene_vreg_dump[0]=vreg0; scene_vreg_dump[1]=vreg1; scene_vreg_dump[2]=vreg2; scene_vreg_dump[3]=vreg3;
        $writememh("scene_vregs.hex", scene_vreg_dump);
    end
  `else
    assign scene_dump = 1'b0;
  `endif
`else
    assign scene_dump = 1'b0;
`endif

    wire [15:0] dbg_mcu_pcmax, dbg_mcu_fetch, dbg_mcuw, dbg_mcu_scrw;
    wire [ 7:0] dbg_key;

    wire [15:0] dbg_mcu_pc_live;
    wire [ 7:0] dbg_de04_live, dbg_de04_68k, dbg_de04_mcu, dbg_de03_live, dbg_de06_live, dbg_de07_live;

    wire [ 7:0] dbg_de06_in, dbg_de06_out, dbg_de07_in, dbg_de07_out, dbg_fec076, dbg_fec06e, dbg_fec06f;
    wire [15:0] dbg_fec078;

    wire [ 7:0] dbg_fede98, dbg_fede9a, dbg_fed5c0, dbg_fed5c2, dbg_fed5c4, dbg_fed5c6;
    wire [15:0] dbg_fec070, dbg_fec074;
    wire [ 7:0] dbg_fec072, dbg_fec077;

    glass_main u_main (
        .clk(clkg), .rst(cpu_rst), .game_run(dip_pause), .oki_cen(oki_cen),
        .vblank_irq(vblank_irq),
        .dbg_mcu_pcmax(dbg_mcu_pcmax), .dbg_mcu_fetch(dbg_mcu_fetch), .dbg_mcuw(dbg_mcuw),
        .dbg_mcu_scrw(dbg_mcu_scrw), .dbg_key(dbg_key),
        .dbg_mcu_pc_live(dbg_mcu_pc_live), .dbg_de04_live(dbg_de04_live),
        .dbg_de04_68k(dbg_de04_68k), .dbg_de04_mcu(dbg_de04_mcu), .dbg_de03_live(dbg_de03_live),
        .dbg_de06_live(dbg_de06_live), .dbg_de07_live(dbg_de07_live),
        .dbg_de06_in(dbg_de06_in), .dbg_de06_out(dbg_de06_out), .dbg_de07_in(dbg_de07_in), .dbg_de07_out(dbg_de07_out),
        .dbg_fec076(dbg_fec076), .dbg_fec06e(dbg_fec06e), .dbg_fec06f(dbg_fec06f), .dbg_fec078(dbg_fec078),
        .dbg_fede98(dbg_fede98), .dbg_fede9a(dbg_fede9a), .dbg_fec070(dbg_fec070),
        .dbg_fec072(dbg_fec072), .dbg_fec074(dbg_fec074), .dbg_fec077(dbg_fec077),
        .dbg_fed5c0(dbg_fed5c0), .dbg_fed5c2(dbg_fed5c2), .dbg_fed5c4(dbg_fed5c4), .dbg_fed5c6(dbg_fed5c6),
        .prog_addr(rom68k_addr), .prog_cs(main_cs), .prog_data(main_data), .prog_data_ok(main_ok),
        .oki_rom_addr(oki_rom_addr), .oki_rom_data(oki_data), .oki_rom_ok(oki_ok),
        .in_dsw2(in_dsw2), .in_dsw1(in_dsw1), .in_p1(in_p1), .in_p2(in_p2),
        .flip_screen(flip_screen),
        .vmem_addr(vmem_addr), .vmem_uds(vmem_uds), .vmem_lds(vmem_lds), .vmem_we(vmem_we),
        .vmem_cs_vram(vmem_cs_vram), .vmem_cs_scrram(vmem_cs_scrram),
        .vmem_cs_pal(vmem_cs_pal), .vmem_cs_spr(vmem_cs_spr),
        .vmem_dec_wdata(vmem_dec_wdata), .vmem_io_wdata(vmem_io_wdata),
        .vmem_vram_rdata(cpu_vram_rd), .vmem_scrram_rdata(cpu_scrram_rd),
        .vmem_pal_rdata(cpu_pal_rd), .vmem_spr_rdata(cpu_spr_rd),
        .vreg0(vreg0), .vreg1(vreg1), .vreg2(vreg2), .vreg3(vreg3),
        .sound(snd14), .snd_sample(snd_sample_w),
        .blit_base(main_blit_base), .blit_active(main_blit_active),

        .mcu_cen(mcu_cen), .mcurom_addr(dallas_addr), .mcurom_en(), .mcurom_data(dallas_data),
        .scr_dl_clk(scr_dl_clk), .scr_dl_addr(scr_dl_addr), .scr_dl_data(scr_dl_data), .scr_dl_we(scr_dl_we)
    );
    assign main_addr = rom68k_addr;

`ifdef SIMULATION
    `define GLASS_HAS_UART
`endif
`ifdef JTFRAME_GAME_UART
    `define GLASS_HAS_UART
`endif
`ifdef GLASS_HAS_UART
    localparam [15:0] U_SAT16 = 16'hFFFF;

    reg [15:0] tl_pc68k_live = 16'd0;
    wire [19:0] pc68k_byte = {rom68k_addr, 1'b0};
    always @(posedge clkg) if (main_cs && main_ok) tl_pc68k_live <= pc68k_byte[15:0];

    wire        tl_pkt_start;
    wire        tl_txd;

    wire [8*16-1:0] tl_data = {
        8'h0A,
        dbg_fec06f,
        dbg_fec06e,
        tl_pc68k_live,
        dbg_fec077,
        dbg_fec078,
        dbg_fec076,
        dbg_fec074,
        dbg_fec072,
        dbg_fec070,
        8'hAA, 8'h55 };
    glass_dbg_uart #(.NB(16), .DIV(5000)) u_dbg_uart (
        .clk(clkg), .rst(rst), .data(tl_data), .pkt_start(tl_pkt_start), .txd(tl_txd)
    );
  `ifdef JTFRAME_GAME_UART
    assign uart_tx = tl_txd;
  `endif
  `ifdef SIMULATION

    integer tlk;
    always @(posedge clkg) if (!rst && tl_pkt_start) begin
        $write("PKT");
        for (tlk=0; tlk<16; tlk=tlk+1) $write(" %02x", tl_data[8*tlk +: 8]);
        $write("\n");
    end
  `endif
`endif

    wire [10:0] tile_a0, tile_a1; wire [31:0] tile_q0, tile_q1;
    wire [9:0]  pal_a;  wire [15:0] pal_q;
    wire [9:0]  palb_a; wire [15:0] palb_q;
    wire [9:0]  palc_a; wire [15:0] palc_q;
    wire [10:0] spr_a;  wire [15:0] spr_q;
    wire [19:0] srom_a;
    wire [19:0] bmap_addr_w; wire bmap_cs_w;

    wire [19:0] main_blit_base; wire main_blit_active;
`ifdef GLASS_SCENE

    reg [19:0] scene_blit [0:1];
    initial $readmemh("scene_blit.hex", scene_blit);
    wire [19:0] blit_base_w   = scene_blit[0];
    wire        blit_active_w = scene_blit[1][0];
`else

    wire [19:0] blit_base_w   = main_blit_base;
    wire        blit_active_w = main_blit_active;
`endif
    glass_vmem u_vmem (
        .clk(clkg), .ce_pix(ce_pix),
        .cpu_addr(vmem_addr), .cpu_uds(vmem_uds), .cpu_lds(vmem_lds), .cpu_we(vmem_we),
        .cs_vram(vmem_cs_vram), .cs_scrram(vmem_cs_scrram), .cs_pal(vmem_cs_pal), .cs_spr(vmem_cs_spr),
        .dec_wdata(vmem_dec_wdata), .io_wdata(vmem_io_wdata),
        .cpu_vram_rdata(cpu_vram_rd), .cpu_scrram_rdata(cpu_scrram_rd),
        .cpu_pal_rdata(cpu_pal_rd), .cpu_spr_rdata(cpu_spr_rd),
        .tile_a0(tile_a0), .tile_q0(tile_q0), .tile_a1(tile_a1), .tile_q1(tile_q1),
        .pal_a(pal_a), .pal_q(pal_q), .palb_a(palb_a), .palb_q(palb_q), .palc_a(palc_a), .palc_q(palc_q),
        .spr_a(spr_a), .spr_q(spr_q),
        .scene_dump(scene_dump)
    );

    wire [19:0] rom_a0, rom_a1;
    wire [4:0]  r5, g5, b5;
    glass_video_top u_video (
        .clk(clkg), .rst(rst), .ce_pix(ce_pix),
        .vreg_l0y(vv0), .vreg_l0x(vv1), .vreg_l1y(vv2), .vreg_l1x(vv3),
        .blit_base(blit_base_w), .blit_active(blit_active_w),
        .tile_a0(tile_a0), .tile_q0(tile_q0), .rom_a0(rom_a0), .gfx0_data(gfx0_data), .gfx0_ok(gfx0_ok),
        .tile_a1(tile_a1), .tile_q1(tile_q1), .rom_a1(rom_a1), .gfx1_data(gfx1_data), .gfx1_ok(gfx1_ok),
        .pal_a(pal_a), .pal_q(pal_q), .palb_a(palb_a), .palb_q(palb_q), .palc_a(palc_a), .palc_q(palc_q),
        .spr_a(spr_a), .spr_q(spr_q), .srom_a(srom_a), .gfxs_data(gfxs_data), .spr_gfx_ok(gfxs_ok),
        .bmap_addr(bmap_addr_w), .bmap_cs(bmap_cs_w), .bmap_data(bmap_data), .bmap_ok(bmap_ok),
        .vga_r(r5), .vga_g(g5), .vga_b(b5),
        .hsync(hs_w), .vsync(vs_w), .hblank(hb_w), .vblank(vb_w), .de(de_w),
        .vblank_irq(vblank_irq)
    );

    assign gfx0_addr = rom_a0; assign gfx0_cs = 1'b1;
    assign gfx1_addr = rom_a1; assign gfx1_cs = 1'b1;
    assign gfxs_addr = srom_a; assign gfxs_cs = 1'b1;
    assign oki_addr  = oki_rom_addr; assign oki_cs = 1'b1;
    assign bmap_addr = bmap_addr_w;  assign bmap_cs = bmap_cs_w;

    assign red   = r5;
    assign green = g5;
    assign blue  = b5;
    assign HS    = hs_w;
    assign VS    = vs_w;
    assign LHBL  = ~hb_w;
    assign LVBL  = ~vb_w;

    wire signed [17:0] snd_g = $signed(snd14) * 18'sd12;
    assign snd = ( snd_g >  18'sd32767 ) ?  16'sd32767 :
                 ( snd_g < -18'sd32768 ) ? -16'sd32768 : snd_g[15:0];
    assign sample = snd_sample_w;

    assign debug_view = 8'd0;
    assign dip_flip   = 1'b0;

`ifdef SIMULATION
    integer wr_vram=0, wr_scr=0, wr_pal=0, wr_spr=0, n_progrd=0;
    reg [19:1] pcmax=0; reg [19:0] hb=0;
    always @(posedge clkg) begin
        if (main_cs && main_ok) begin n_progrd<=n_progrd+1; if (rom68k_addr>pcmax) pcmax<=rom68k_addr; end
        if (vmem_we && vmem_cs_vram)   wr_vram<=wr_vram+1;
        if (vmem_we && vmem_cs_scrram) wr_scr <=wr_scr +1;
        if (vmem_we && vmem_cs_pal )   wr_pal <=wr_pal +1;
        if (vmem_we && vmem_cs_spr )   wr_spr <=wr_spr +1;
        hb<=hb+1'b1;
        if (hb==20'd0) $display("HB pc=%h PCmax=%h progrd=%0d vram=%0d scr=%0d pal=%0d spr=%0d vregs=%h,%h,%h,%h",
                                {rom68k_addr,1'b0}, {pcmax,1'b0}, n_progrd, wr_vram, wr_scr, wr_pal, wr_spr,
                                vreg0, vreg1, vreg2, vreg3);
    end
`endif

endmodule

`default_nettype wire
