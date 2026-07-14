// ============================================================================
//  Thunder Hoop (Gaelco, 1992) — jtglass_game.v: modulo de juego para jtframe.
//
//  jtcore (memgen, desde cfg/mem.yaml) AUTO-GENERA jtglass_game_sdram.v (GAMETOP) que
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

module jtglass_game(
    `include "jtframe_game_ports.inc"
    // --- descarga (RUNTIME, desde la .mra) del SCRATCH del DS5002 (mismo download que el PROM) ---
    //  El wrapper generado las cablea a dallas_waddr/dallas_dd/dallas_we (patch_scratch_runtime.py).
    ,input  wire        scr_dl_clk
    ,input  wire [14:0] scr_dl_addr
    ,input  wire [ 7:0] scr_dl_data
    ,input  wire        scr_dl_we
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

    // mcu_cen = clk48/4 = 12 MHz (cristal del DS5002; el wrapper lo divide /12 -> ~1 MIPS real).
    // PAUSA: dip_pause (jtframe, activo-bajo: 1=corre, 0=pausa) congela el DS5002 a la vez que el 68k
    // -> el handshake de RAM compartida queda coherente. El vídeo (ce_pix) sigue.
    reg [1:0] mcudiv = 2'd0;
    always @(posedge clkg) mcudiv <= mcudiv + 2'd1;
    wire mcu_cen = (mcudiv==2'd0) & dip_pause;

    // ===================== TIMING DE VIDEO (dentro de glass_video_top) =====================
    wire vblank_irq;
    wire hs_w, vs_w, hb_w, vb_w, de_w;

    // ===================== ENTRADAS =====================
    wire [15:0] in_dsw2, in_dsw1, in_p1, in_p2;
    glass_inputs u_inputs (
        .dipsw(dipsw[15:0]),
        .joystick1(joystick1[5:0]), .joystick2(joystick2[5:0]),
        .coin(coin[1:0]),         // jtframe coin ya activo-bajo; glass_inputs espera activo-bajo -> DIRECTO
        .start(cab_1p[1:0]),      // start (cabina) jtframe activo-bajo -> DIRECTO
        .service(service),        // boton de servicio activo-bajo -> DIRECTO
        .port_dsw2(in_dsw2), .port_dsw1(in_dsw1), .port_p1(in_p1), .port_p2(in_p2)
    );
    // POLARIDAD (mismo fix que squash, probado vs MAME 2026-06-22): jtframe entrega joystick/coin/cab/service
    // ACTIVO-BAJO y glass_inputs trabaja activo-bajo -> TODO DIRECTO. El `~service` previo metia DSW2 bit7=0
    // = MODO SERVICIO permanente (el juego no arrancaba). Ver squash + research/BITACORA_GLASS.md.

    // ===================== CPU + memoria (glass_main) =====================
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

    // ===================== SNAPSHOT de escena (GLASS_SCENE) — iteracion rapida del video =====================
    // GLASS_SCENE_DUMP=N : corre normal y al frame N vuelca VRAM/paleta/spriteRAM/vregs a scene_*.hex.
    // GLASS_SCENE        : mantiene la CPU en RESET y precarga la escena -> renderiza sin bootear (segundos).
    wire        scene_dump;
    reg  [15:0] scene_vreg_dump [0:3];
`ifdef GLASS_SCENE
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
  `ifdef GLASS_SCENE_DUMP
    assign scene_dump = (scene_fcnt==`GLASS_SCENE_DUMP) & vblank_irq & ~vbi_sd;
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

    // TELEMETRIA DS5002 (HW): wires de los counters del handshake (de glass_main)
    wire [15:0] dbg_mcu_pcmax, dbg_mcu_fetch, dbg_mcuw, dbg_mcu_scrw;
    wire [ 7:0] dbg_key;
    // TELEMETRIA v2 (valores VIVOS del cuelgue cmd-1)
    wire [15:0] dbg_mcu_pc_live;
    wire [ 7:0] dbg_de04_live, dbg_de04_68k, dbg_de04_mcu, dbg_de03_live, dbg_de06_live, dbg_de07_live;
    // TELEMETRIA v3 (traduccion in/out + estado del reveal)
    wire [ 7:0] dbg_de06_in, dbg_de06_out, dbg_de07_in, dbg_de07_out, dbg_fec076, dbg_fec06e, dbg_fec06f;
    wire [15:0] dbg_fec078;
    // TELEMETRIA v4 (causa raiz: FEC070=tabla478c[FEDE98])
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
        // DS5002: firmware servido por el PROM 'dallas' (runtime desde la .mra) + descarga del scratch
        .mcu_cen(mcu_cen), .mcurom_addr(dallas_addr), .mcurom_en(), .mcurom_data(dallas_data),
        .scr_dl_clk(scr_dl_clk), .scr_dl_addr(scr_dl_addr), .scr_dl_data(scr_dl_data), .scr_dl_we(scr_dl_we)
    );
    assign main_addr = rom68k_addr;

    // ===================== TELEMETRIA UART DS5002 (HW, sintetizable) =====================
    //  Diagnostico EN PLACA del boot/DS5002 (clon de wrally2). Saca por uart_tx (game UART -> /dev/ttyS1,
    //  UART activo en el OSD) un paquete de 16 bytes 8N1 9600 baud, repetido. Parser: mister/parse_uart_dbg.py.
    //    ¿corre el MCU? -> mcu_fetch sube + mcu_pcmax avanza.   ¿corre firmware REAL? -> mcu_scrw>0.
    //    ¿68k escribe el go-signal? -> key=0x05(fase1)/0x02(fase2).   ¿MCU responde/heartbeat? -> mcuw>0.
    //    ¿68k progresa? -> 68k_pcmax (byte addr; >0x3b18 = paso el handshake; ~0x64758 = corre el juego).
    //  El bloque compila bajo SIMULATION (vuelca lineas PKT para validar SIN build) o JTFRAME_GAME_UART (HW).
`ifdef SIMULATION
    `define GLASS_HAS_UART
`endif
`ifdef JTFRAME_GAME_UART
    `define GLASS_HAS_UART
`endif
`ifdef GLASS_HAS_UART
    localparam [15:0] U_SAT16 = 16'hFFFF;
    // PC VIVO del 68k: latch de la ultima direccion de FETCH real (main_cs=cs_rom). Cuando el 68k
    //  esta atascado en 0xf5dc (tst.b DE04; beq) los fetches son ~0xf5dc/0xf5e2 -> low16 lo delata.
    reg [15:0] tl_pc68k_live = 16'd0;
    wire [19:0] pc68k_byte = {rom68k_addr, 1'b0};
    always @(posedge clkg) if (main_cs && main_ok) tl_pc68k_live <= pc68k_byte[15:0];
    // Paquete v4 de 16 bytes (CAUSA RAIZ: FEC070 = tabla478c[FEDE98], tabla valida solo 0..3):
    //  [0]=55 [1]=AA [2]=FEDE98 [3:4]=FEC070(LE) [5]=FED5C0 [6]=FED5C2 [7]=FED5C4 [8]=FED5C6
    //  [9]=FEC076(state) [10:11]=FEC078(LE) [12:13]=68k_pc_live(LE) [14]=FEDE9A [15]=0A
    //  VEREDICTO HW: si FEDE98>=4 o FEC070 enorme (golden MAME: FEDE98=0 -> FEC070=0x0046) -> confirmado:
    //    el MCU deja mal FED5C0/C6 al fin de mision -> selector calcula FEDE98 malo -> contador basura -> cuelgue.
    wire        tl_pkt_start;
    wire        tl_txd;
    // Paquete v6 (V008) — TRAYECTORIA del reveal (el cuelgue = DESINCRONIA c070/c078, NO el DS5002).
    //  Golden (lock-step): en c070=0x12 -> c072=0x34, c074=0x97, c078=0x138. FPGA: c078 adelantado.
    //  Se comparan estos contadores del cuelgue contra GOLDEN_glass_reveal_trajectory.txt (parse_glass_v6.py).
    //  [0]=55 [1]=AA [2:3]=FEC070(LE) [4]=FEC072 [5:6]=FEC074(LE) [7]=FEC076(state) [8:9]=FEC078(LE)
    //  [10]=FEC077 [11:12]=68k_PC(LE) [13]=cursor_x(FEC06E) [14]=cursor_y(FEC06F) [15]=0A
    wire [8*16-1:0] tl_data = {
        8'h0A,               // [15]
        dbg_fec06f,          // [14] cursor y
        dbg_fec06e,          // [13] cursor x
        tl_pc68k_live,       // [11:12] PC 68k (LE)
        dbg_fec077,          // [10] FEC077 sub-contador render
        dbg_fec078,          // [8:9] FEC078 (LE)  render (golden capa en 0x168)
        dbg_fec076,          // [7]  state (1/2)
        dbg_fec074,          // [5:6] FEC074 (LE)
        dbg_fec072,          // [4]  FEC072
        dbg_fec070,          // [2:3] FEC070 (LE)  bucle principal
        8'hAA, 8'h55 };      // [1][0] sync
    glass_dbg_uart #(.NB(16), .DIV(5000)) u_dbg_uart (   // clkg=clk48 / 9600 = 5000
        .clk(clkg), .rst(rst), .data(tl_data), .pkt_start(tl_pkt_start), .txd(tl_txd)
    );
  `ifdef JTFRAME_GAME_UART
    assign uart_tx = tl_txd;     // a la placa (sólo si el game expone el pin del UART)
  `endif
  `ifdef SIMULATION
    // VOLCADO del paquete en sim (valida empaquetado->parser SIN build): grep "^PKT" | parse_uart_dbg.py
    integer tlk;
    always @(posedge clkg) if (!rst && tl_pkt_start) begin
        $write("PKT");
        for (tlk=0; tlk<16; tlk=tlk+1) $write(" %02x", tl_data[8*tlk +: 8]);
        $write("\n");
    end
  `endif
`endif

    // ===================== memorias de video (glass_vmem) =====================
    wire [10:0] tile_a0, tile_a1; wire [31:0] tile_q0, tile_q1;
    wire [9:0]  pal_a;  wire [15:0] pal_q;
    wire [9:0]  palb_a; wire [15:0] palb_q;
    wire [9:0]  palc_a; wire [15:0] palc_q;
    wire [10:0] spr_a;  wire [15:0] spr_q;
    wire [19:0] srom_a;
    wire [19:0] bmap_addr_w; wire bmap_cs_w;

    // ----- comando del BLITTER (base en H9 + enable de la capa bitmap) -----
    wire [19:0] main_blit_base; wire main_blit_active;   // de glass_blitter (captura CPU) — para HW/boot
`ifdef GLASS_SCENE
    // REPLAY: la CPU esta congelada -> precarga base+active de la escena (scene_blit.hex: l0=base, l1=active).
    reg [19:0] scene_blit [0:1];
    initial $readmemh("scene_blit.hex", scene_blit);
    wire [19:0] blit_base_w   = scene_blit[0];
    wire        blit_active_w = scene_blit[1][0];
`else
    // HW/boot: el comando serie capturado del bus (0x700008) por glass_blitter dentro de glass_main.
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

    // ===================== VIDEO (FASE 4d — TILEMAPS; sprites = fase 4c pendiente) =====================
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

    // gfx tilemap + sprites SDRAM (DW32, 4 planos).
    assign gfx0_addr = rom_a0; assign gfx0_cs = 1'b1;
    assign gfx1_addr = rom_a1; assign gfx1_cs = 1'b1;
    assign gfxs_addr = srom_a; assign gfxs_cs = 1'b1;
    assign oki_addr  = oki_rom_addr; assign oki_cs = 1'b1;
    assign bmap_addr = bmap_addr_w;  assign bmap_cs = bmap_cs_w;   // bitmap H9 (bank3, DW8, handshake)

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
