`default_nettype none

module jtbigkarnk_game(
    `include "jtframe_game_ports.inc"
);

    wire clkg = clk48;

    reg [2:0] pxdiv = 3'd0;
    always @(posedge clkg) pxdiv <= (pxdiv==3'd7) ? 3'd0 : pxdiv + 3'd1;
    assign pxl_cen  = (pxdiv==3'd0);
    assign pxl2_cen = (pxdiv==3'd0) || (pxdiv==3'd4);
    wire ce_pix = (pxdiv==3'd0);

    reg [5:0] sdiv = 6'd0;
    reg cen_cpu=1'b0, cen_fm=1'b0, cen_oki=1'b0;
    always @(posedge clkg) begin
        sdiv    <= (sdiv==6'd47) ? 6'd0 : sdiv + 6'd1;
        cen_cpu <= (sdiv==6'd0) || (sdiv==6'd24);
        cen_fm  <= (sdiv==6'd0) || (sdiv==6'd12) || (sdiv==6'd24) || (sdiv==6'd36);
        cen_oki <= (sdiv==6'd0);
    end

    wire vblank_irq;
    wire hs_w, vs_w, hb_w, vb_w, de_w;

    wire [15:0] in_dsw2, in_dsw1, in_p1, in_p2, in_service;
    bigkarnk_inputs u_inputs (
        .dipsw(dipsw[15:0]),
        .joystick1(joystick1[5:0]), .joystick2(joystick2[5:0]),
        .coin(coin[1:0]),
        .start(cab_1p[1:0]),
        .service(service),
        .port_dsw1(in_dsw1), .port_dsw2(in_dsw2), .port_p1(in_p1), .port_p2(in_p2),
        .port_service(in_service)
    );

    wire        flip_screen;
    wire [13:0] vmem_addr; wire vmem_uds, vmem_lds, vmem_we;
    wire        vmem_cs_vram, vmem_cs_scrram, vmem_cs_pal, vmem_cs_spr;
    wire [15:0] vmem_dec_wdata, vmem_io_wdata;
    wire [15:0] cpu_vram_rd, cpu_scrram_rd, cpu_pal_rd, cpu_spr_rd;
    wire [15:0] vreg0, vreg1, vreg2, vreg3;
    wire [19:1] rom68k_addr;
    wire [7:0]  snd_latch_w;
    wire        snd_irq_w;

    wire        scene_dump;
    reg  [15:0] scene_vreg_dump [0:3];
`ifdef BIGKARNK_SCENE
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
  `ifdef BIGKARNK_SCENE_DUMP
    assign scene_dump = (scene_fcnt==`BIGKARNK_SCENE_DUMP) & vblank_irq & ~vbi_sd;
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

    bigkarnk_main u_main (
        .clk(clkg), .rst(cpu_rst),
        .vblank_irq(vblank_irq),
        .prog_addr(rom68k_addr), .prog_cs(main_cs), .prog_data(main_data), .prog_data_ok(main_ok),
        .in_dsw1(in_dsw1), .in_dsw2(in_dsw2), .in_p1(in_p1), .in_p2(in_p2), .in_service(in_service),
        .flip_screen(flip_screen),
        .vmem_addr(vmem_addr), .vmem_uds(vmem_uds), .vmem_lds(vmem_lds), .vmem_we(vmem_we),
        .vmem_cs_vram(vmem_cs_vram), .vmem_cs_scrram(vmem_cs_scrram),
        .vmem_cs_pal(vmem_cs_pal), .vmem_cs_spr(vmem_cs_spr),
        .vmem_dec_wdata(vmem_dec_wdata), .vmem_io_wdata(vmem_io_wdata),
        .vmem_vram_rdata(cpu_vram_rd), .vmem_scrram_rdata(cpu_scrram_rd),
        .vmem_pal_rdata(cpu_pal_rd), .vmem_spr_rdata(cpu_spr_rd),
        .vreg0(vreg0), .vreg1(vreg1), .vreg2(vreg2), .vreg3(vreg3),
        .snd_latch(snd_latch_w), .snd_irq(snd_irq_w)
    );
    assign main_addr = rom68k_addr;

    wire [10:0] tile_a0, tile_a1; wire [31:0] tile_q0, tile_q1;
    wire [9:0]  pal_a;  wire [15:0] pal_q;
    wire [9:0]  palb_a; wire [15:0] palb_q;
    wire [10:0] spr_a;  wire [15:0] spr_q;
    wire [19:0] srom_a;
    bigkarnk_vmem u_vmem (
        .clk(clkg), .ce_pix(ce_pix),
        .cpu_addr(vmem_addr), .cpu_uds(vmem_uds), .cpu_lds(vmem_lds), .cpu_we(vmem_we),
        .cs_vram(vmem_cs_vram), .cs_scrram(vmem_cs_scrram), .cs_pal(vmem_cs_pal), .cs_spr(vmem_cs_spr),
        .dec_wdata(vmem_dec_wdata), .io_wdata(vmem_io_wdata),
        .cpu_vram_rdata(cpu_vram_rd), .cpu_scrram_rdata(cpu_scrram_rd),
        .cpu_pal_rdata(cpu_pal_rd), .cpu_spr_rdata(cpu_spr_rd),
        .tile_a0(tile_a0), .tile_q0(tile_q0), .tile_a1(tile_a1), .tile_q1(tile_q1),
        .pal_a(pal_a), .pal_q(pal_q), .palb_a(palb_a), .palb_q(palb_q),
        .spr_a(spr_a), .spr_q(spr_q),
        .scene_dump(scene_dump)
    );

    wire [19:0] rom_a0, rom_a1;
    wire [4:0]  r5, g5, b5;
    bigkarnk_video_top u_video (
        .clk(clkg), .rst(rst), .ce_pix(ce_pix),
        .vreg_l0y(vv0), .vreg_l0x(vv1), .vreg_l1y(vv2), .vreg_l1x(vv3),
        .tile_a0(tile_a0), .tile_q0(tile_q0), .rom_a0(rom_a0), .gfx0_data(gfx0_data), .gfx0_ok(gfx0_ok),
        .tile_a1(tile_a1), .tile_q1(tile_q1), .rom_a1(rom_a1), .gfx1_data(gfx1_data), .gfx1_ok(gfx1_ok),
        .pal_a(pal_a), .pal_q(pal_q), .palb_a(palb_a), .palb_q(palb_q),
        .spr_a(spr_a), .spr_q(spr_q), .srom_a(srom_a), .gfxs_data(gfxs_data), .spr_gfx_ok(gfxs_ok),
        .vga_r(r5), .vga_g(g5), .vga_b(b5),
        .hsync(hs_w), .vsync(vs_w), .hblank(hb_w), .vblank(vb_w), .de(de_w),
        .vblank_irq(vblank_irq)
    );

    assign gfx0_addr = rom_a0; assign gfx0_cs = 1'b1;
    assign gfx1_addr = rom_a1; assign gfx1_cs = 1'b1;
    assign gfxs_addr = srom_a; assign gfxs_cs = 1'b1;

    assign red   = r5;
    assign green = g5;
    assign blue  = b5;
    assign HS    = hs_w;
    assign VS    = vs_w;
    assign LHBL  = ~hb_w;
    assign LVBL  = ~vb_w;

    wire signed [15:0] fm_w;
    wire signed [13:0] pcm_w;
    wire        sample_w;
    wire [15:0] snd0_rom_addr;
    wire        snd0_rom_cs;
    wire [17:0] pcm_rom_addr;
    wire        pcm_rom_cs;

    bigkarnk_sound u_sound (
        .clk(clkg), .rst(rst),
        .cen_cpu(cen_cpu), .cen_fm(cen_fm), .cen_oki(cen_oki),
        .snd_irq(snd_irq_w), .snd_latch(snd_latch_w),

        .rom_addr(snd0_rom_addr), .rom_cs(snd0_rom_cs), .rom_data(snd0_data), .rom_ok(snd0_ok),

        .pcm_addr(pcm_rom_addr), .pcm_cs(pcm_rom_cs), .pcm_data(oki_data), .pcm_ok(oki_ok),
        .pcm(pcm_w), .fm(fm_w), .sample(sample_w)
    );
    assign snd0_addr = snd0_rom_addr; assign snd0_cs = snd0_rom_cs;
    assign oki_addr  = pcm_rom_addr;  assign oki_cs  = pcm_rom_cs;

    wire signed [17:0] mix = $signed(fm_w) + ($signed(pcm_w) <<< 2);
    assign snd = ( mix >  18'sd32767 ) ?  16'sd32767 :
                 ( mix < -18'sd32768 ) ? -16'sd32768 : mix[15:0];
    assign sample = sample_w;

    assign debug_view = 8'd0;
    assign dip_flip   = 1'b0;

`ifdef SIMULATION
    integer wr_vram=0, wr_scr=0, wr_pal=0, wr_spr=0, n_progrd=0;
    reg [19:1] pcmax=0; reg [19:0] hb=0; reg [19:1] pctr_prev=0;
    always @(posedge clkg) begin
        if (main_cs && main_ok) begin n_progrd<=n_progrd+1; if (rom68k_addr>pcmax) pcmax<=rom68k_addr; end
        if (vmem_we && vmem_cs_vram)   wr_vram<=wr_vram+1;
        if (vmem_we && vmem_cs_scrram) wr_scr <=wr_scr +1;
        if (vmem_we && vmem_cs_pal )   wr_pal <=wr_pal +1;
        if (vmem_we && vmem_cs_spr )   wr_spr <=wr_spr +1;
        hb<=hb+1'b1;
`ifdef BIGKARNK_PCTRACE

        if (main_cs && main_ok && rom68k_addr!=pctr_prev) begin
            $display("PCRD %h data=%h", {rom68k_addr,1'b0}, main_data); pctr_prev<=rom68k_addr;
        end
`endif
        if (hb==20'd0) $display("HB pc=%h PCmax=%h progrd=%0d vram=%0d scr=%0d pal=%0d spr=%0d vregs=%h,%h,%h,%h",
                                {rom68k_addr,1'b0}, {pcmax,1'b0}, n_progrd, wr_vram, wr_scr, wr_pal, wr_spr,
                                vreg0, vreg1, vreg2, vreg3);
    end
`endif

endmodule

`default_nettype wire
