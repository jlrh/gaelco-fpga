// ============================================================================
//  Thunder Hoop (Gaelco, 1992) — jtbiomtoy_game.v: modulo de juego para jtframe.
//
//  jtcore (memgen, desde cfg/mem.yaml) AUTO-GENERA jtbiomtoy_game_sdram.v (GAMETOP) que
//  instancia este modulo + slots SDRAM + dwnld + board/OSD/video-out de jtframe.
//
//  Buses SDRAM por NOMBRE: main_* (prog 68k DW16), gfx0/gfx1/gfxs_* (gfx DW32),
//  oki_* (DW8). SIN BRAM/PROM (Tipo-1 no lleva DS5002).
//
//  ESTADO: FASE 2/3 — CPU + memoria + cifrado + I/O + timing de video. El MOTOR de
//  video Tipo-1 (tilemaps+sprites+mezcla) es FASE 4: aqui va en STUB (salida negra),
//  pero el timing genera vblank_irq -> el 68k corre su bucle por IRQ. Objetivo de esta
//  fase: validar en sim que el 68k arranca y escribe VRAM/paleta.
// ============================================================================
`default_nettype none

module jtbiomtoy_game(
    `include "jtframe_game_ports.inc"
);
    // ===================== RELOJES / CEN =====================
    // Logica del juego a clk48; SDRAM (slots) a clk=clk96 (JTFRAME_SDRAM96). Igual que WRally.
    wire clkg = clk48;

    // pxl_cen = clk48/6 = 8 MHz (par -> spacing limpio para el scaler). pxl2_cen = clk48/3 = 16 MHz.
    reg [2:0] pxdiv = 3'd0;
    always @(posedge clkg) pxdiv <= (pxdiv==3'd5) ? 3'd0 : pxdiv + 3'd1;
    assign pxl_cen  = (pxdiv==3'd0);
    assign pxl2_cen = (pxdiv==3'd0) || (pxdiv==3'd3);
    wire ce_pix = (pxdiv==3'd0);

    // OKI ~1 MHz = clk48/48.
    reg [5:0] odiv = 6'd0;
    reg oki_cen = 1'b0;
    always @(posedge clkg) begin
        odiv    <= (odiv==6'd47) ? 6'd0 : odiv + 6'd1;
        oki_cen <= (odiv==6'd0);
    end

    // ===================== TIMING DE VIDEO (dentro de biomtoy_video_top) =====================
    wire vblank_irq;
    wire hs_w, vs_w, hb_w, vb_w, de_w;

    // ===================== ENTRADAS =====================
    wire [15:0] in_dsw2, in_dsw1, in_p1, in_p2;
    biomtoy_inputs u_inputs (
        .dipsw(dipsw[15:0]),
        .joystick1(joystick1[5:0]), .joystick2(joystick2[5:0]),
        .coin(coin[1:0]),         // jtframe coin ya activo-bajo; biomtoy_inputs espera activo-bajo -> DIRECTO
        .start(cab_1p[1:0]),      // start (cabina) jtframe activo-bajo -> DIRECTO
        .service(service),        // boton de servicio activo-bajo -> DIRECTO
        .port_dsw2(in_dsw2), .port_dsw1(in_dsw1), .port_p1(in_p1), .port_p2(in_p2)
    );
    // POLARIDAD (mismo fix que squash, probado vs MAME 2026-06-22): jtframe entrega joystick/coin/cab/service
    // ACTIVO-BAJO y biomtoy_inputs trabaja activo-bajo -> TODO DIRECTO. El `~service` previo metia DSW2 bit7=0
    // = MODO SERVICIO permanente (el juego no arrancaba). Ver squash + research/BITACORA_BIOMTOY.md.

    // ===================== CPU + memoria (biomtoy_main) =====================
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

    // ===================== SNAPSHOT de escena (BIOMTOY_SCENE) — iteracion rapida del video =====================
    // BIOMTOY_SCENE_DUMP=N : corre normal y al frame N vuelca VRAM/paleta/spriteRAM/vregs a scene_*.hex.
    // BIOMTOY_SCENE        : mantiene la CPU en RESET y precarga la escena -> renderiza sin bootear (segundos).
    wire        scene_dump;
    reg  [15:0] scene_vreg_dump [0:3];
`ifdef BIOMTOY_SCENE
    wire cpu_rst = 1'b1;                       // CPU congelada: la VRAM precargada NO se sobreescribe
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
  `ifdef BIOMTOY_SCENE_DUMP
    assign scene_dump = (scene_fcnt==`BIOMTOY_SCENE_DUMP) & vblank_irq & ~vbi_sd;
    always @(posedge clkg) if (scene_dump) begin
        scene_vreg_dump[0]=vreg0; scene_vreg_dump[1]=vreg1; scene_vreg_dump[2]=vreg2; scene_vreg_dump[3]=vreg3;
        $writememh("scene_vregs.hex", scene_vreg_dump);   // blocking: $writememh ve los valores actuales
    end
  `else
    assign scene_dump = 1'b0;
  `endif
`else
    assign scene_dump = 1'b0;
`endif

    biomtoy_main u_main (
        .clk(clkg), .rst(cpu_rst), .oki_cen(oki_cen),
        .vblank_irq(vblank_irq),
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
        .sound(snd14), .snd_sample(snd_sample_w)
    );
    assign main_addr = rom68k_addr;

    // ===================== memorias de video (biomtoy_vmem) =====================
    wire [10:0] tile_a0, tile_a1; wire [31:0] tile_q0, tile_q1;
    wire [9:0]  pal_a;  wire [15:0] pal_q;
    wire [9:0]  palb_a; wire [15:0] palb_q;
    wire [10:0] spr_a;  wire [15:0] spr_q;
    wire [19:0] srom_a;
    biomtoy_vmem u_vmem (
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

    // ===================== VIDEO (FASE 4d — TILEMAPS; sprites = fase 4c pendiente) =====================
    wire [19:0] rom_a0, rom_a1;
    wire [4:0]  r5, g5, b5;
    biomtoy_video_top u_video (
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

    // gfx tilemap + sprites SDRAM (DW32, 4 planos).
    assign gfx0_addr = rom_a0; assign gfx0_cs = 1'b1;
    assign gfx1_addr = rom_a1; assign gfx1_cs = 1'b1;
    assign gfxs_addr = srom_a; assign gfxs_cs = 1'b1;
    assign oki_addr  = oki_rom_addr; assign oki_cs = 1'b1;

    assign red   = r5;
    assign green = g5;
    assign blue  = b5;
    assign HS    = hs_w;
    assign VS    = vs_w;
    assign LHBL  = ~hb_w;
    assign LVBL  = ~vb_w;

    // ===================== AUDIO =====================
    // OKI 14-bit signed -> 16-bit con ganancia x12 + clamp (igual criterio que WRally V.067).
    wire signed [17:0] snd_g = $signed(snd14) * 18'sd12;
    assign snd = ( snd_g >  18'sd32767 ) ?  16'sd32767 :
                 ( snd_g < -18'sd32768 ) ? -16'sd32768 : snd_g[15:0];
    assign sample = snd_sample_w;

    // ===================== sin usar de momento =====================
    assign debug_view = 8'd0;
    assign dip_flip   = 1'b0;

    // ===================== TRAZA DE SIM =====================
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
