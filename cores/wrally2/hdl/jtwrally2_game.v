`default_nettype none

module jtwrally2_game(
    `include "jtframe_game_ports.inc"

    ,input  wire        scr_dl_clk
    ,input  wire [14:0] scr_dl_addr
    ,input  wire [ 7:0] scr_dl_data
    ,input  wire        scr_dl_we
);

    wire clkg = clk48;

`ifdef WRALLY2_TWIN
    wire disp_twin = 1'b1;  wire disp_index = 1'b0;
`elsif WRALLY2_RIGHT
    wire disp_twin = 1'b0;  wire disp_index = 1'b1;
`else
    wire disp_twin  = status[14];
    wire disp_index = status[13];
`endif

    reg [2:0] pxdiv = 3'd0;
    wire [2:0] pxmax = disp_twin ? 3'd2 : 3'd5;
    always @(posedge clkg) pxdiv <= (pxdiv>=pxmax) ? 3'd0 : pxdiv + 3'd1;
    assign pxl_cen  = (pxdiv==3'd0);

    assign pxl2_cen = disp_twin ? (pxdiv==3'd1) : ((pxdiv==3'd0) || (pxdiv==3'd3));
    wire ce_pix = (pxdiv==3'd0);

`ifdef WR2_CEN_FRAC
    reg [5:0] mcuacc = 6'd0;
    reg       mcu_cen_r = 1'b0;
    always @(posedge clkg) begin
        if (mcuacc >= 6'd35) begin mcuacc <= mcuacc + 6'd13 - 6'd48; mcu_cen_r <= 1'b1; end
        else                 begin mcuacc <= mcuacc + 6'd13;        mcu_cen_r <= 1'b0; end
    end
    wire mcu_cen = mcu_cen_r & dip_pause;
`else
    reg [1:0] mcudiv = 2'd0;
    always @(posedge clkg) mcudiv <= mcudiv + 2'd1;

    wire mcu_cen = (mcudiv==2'd0) & dip_pause;
`endif

    wire [15:0] in0, in1, in2, in3;
    wrally2_inputs u_inputs (
        .clk(clkg),
        .dipsw(dipsw[15:0]),
        .joystick1(joystick1[5:0]), .joystick2(joystick2[5:0]),
        .coin(coin[1:0]),
        .start(cab_1p[1:0]),
        .service(service),
        .test(dip_test),
        .port_in0(in0), .port_in1(in1), .port_in2(in2), .port_in3(in3)
    );

    wire        flip_screen;
    wire [15:0] vmem_addr; wire vmem_uds, vmem_lds, vmem_we;
    wire        vmem_cs_vram, vmem_cs_pal;
    wire [15:0] vmem_wdata;
    wire [15:0] cpu_vram_rd, cpu_pal_rd;
    wire [15:0] vreg0, vreg1, vreg2;
    wire [19:1] rom68k_addr;
    wire        sndreg_cs, sndreg_we; wire [15:0] snd_rdata;

    wire [15:0] dbg_mcu_pcmax, dbg_mcu_fetch, dbg_mcuw, dbg_mcu_scrw;
    wire [ 7:0] dbg_key;
    wire signed [15:0] snd_l, snd_r; wire snd_sample_w;

`ifdef WRALLY2_SCENE
    wire cpu_rst = 1'b1;
    reg [15:0] scene_vreg [0:7];
    initial $readmemh("scene_vregs.hex", scene_vreg);
    wire [15:0] vv0 = scene_vreg[2], vv1 = scene_vreg[3], vv2 = scene_vreg[4];
`else
    wire cpu_rst = rst;
    wire [15:0] vv0 = vreg0, vv1 = vreg1, vv2 = vreg2;
`endif

    wrally2_main u_main (
        .clk(clkg), .rst(cpu_rst), .game_run(dip_pause),
        .vblank_irq(vblank_irq),
        .prog_addr(rom68k_addr), .prog_cs(main_cs), .prog_data(main_data), .prog_data_ok(main_ok),
        .in0(in0), .in1(in1), .in2(in2), .in3(in3),

        .paddle0({~joyana_l1[7], joyana_l1[6:0]}),
        .paddle1({~joyana_l2[7], joyana_l2[6:0]}),
        .flip_screen(flip_screen),
        .vmem_addr(vmem_addr), .vmem_uds(vmem_uds), .vmem_lds(vmem_lds), .vmem_we(vmem_we),
        .vmem_cs_vram(vmem_cs_vram), .vmem_cs_pal(vmem_cs_pal),
        .vmem_wdata(vmem_wdata),
        .vmem_vram_rdata(cpu_vram_rd), .vmem_pal_rdata(cpu_pal_rd),
        .vreg0(vreg0), .vreg1(vreg1), .vreg2(vreg2),
        .sndreg_cs(sndreg_cs), .sndreg_we(sndreg_we), .snd_rdata(snd_rdata),
        .mcu_cen(mcu_cen), .mcurom_addr(dallas_addr), .mcurom_en(), .mcurom_data(dallas_data),

        .dbg_mcu_pcmax(dbg_mcu_pcmax), .dbg_mcu_fetch(dbg_mcu_fetch),
        .dbg_mcuw(dbg_mcuw), .dbg_mcu_scrw(dbg_mcu_scrw), .dbg_key(dbg_key),

        .scr_dl_clk(scr_dl_clk), .scr_dl_addr(scr_dl_addr), .scr_dl_data(scr_dl_data), .scr_dl_we(scr_dl_we)
    );
    assign main_addr = rom68k_addr;

    wire [21:0] rom_asnd;
    wrally2_gae1_sound u_snd (
        .clk(clkg), .rst(rst),
        .cs_sound(sndreg_cs), .cpu_aw(vmem_addr[7:1]), .cpu_we(sndreg_we),
        .cpu_uds(vmem_uds), .cpu_lds(vmem_lds), .cpu_wdata(vmem_wdata), .cpu_rdata(snd_rdata),
        .rom_addr(rom_asnd), .rom_cs(snd_cs), .rom_data(snd_data), .rom_ok(snd_ok),
        .snd_l(snd_l), .snd_r(snd_r), .sample(snd_sample_w)
    );
    assign snd_addr = rom_asnd;

    wire [13:0] tp0_idx, tp1_idx; wire [31:0] tp0_q, tp1_q;
    wire [14:0] wrd_a;  wire [15:0] wrd_q;
    wire [14:0] spr_a;  wire [15:0] spr_q;
    wire [14:0] spr2_a; wire [15:0] spr2_q;
    wire [11:0] pal_a;  wire [15:0] pal_q;
    wrally2_vmem u_vmem (
        .clk(clkg), .clk96(clk96),
        .cpu_addr(vmem_addr), .cpu_uds(vmem_uds), .cpu_lds(vmem_lds), .cpu_we(vmem_we),
        .cs_vram(vmem_cs_vram), .cs_pal(vmem_cs_pal),
        .cpu_wdata(vmem_wdata),
        .cpu_vram_rdata(cpu_vram_rd), .cpu_pal_rdata(cpu_pal_rd),
        .tp0_idx(tp0_idx), .tp0_q(tp0_q), .tp1_idx(tp1_idx), .tp1_q(tp1_q),
        .wrd_a(wrd_a), .wrd_q(wrd_q), .spr_a(spr_a), .spr_q(spr_q),
        .spr2_a(spr2_a), .spr2_q(spr2_q),
        .pal_a(pal_a), .pal_q(pal_q)
    );

    wire vblank_irq;
    wire hs_w, vs_w, hb_w, vb_w, de_w;
    wire [21:0] rom_a0, rom_a1, rom_as, rom_as2;
    wire [4:0] r5, g5, b5;

    wrally2_video_top u_video (
        .clk(clkg), .clk96(clk96), .rst(rst), .ce_pix(ce_pix),
        .index(disp_index), .twin(disp_twin),
        .vreg0(vv0), .vreg1(vv1), .vreg2(vv2),
        .tp0_idx(tp0_idx), .tp0_q(tp0_q), .tp1_idx(tp1_idx), .tp1_q(tp1_q),
        .wrd_a(wrd_a), .wrd_q(wrd_q), .spr_a(spr_a), .spr_q(spr_q),
        .spr2_a(spr2_a), .spr2_q(spr2_q), .pal_a(pal_a), .pal_q(pal_q),
        .rom_a0(rom_a0), .gfx0_data(gfx0_data), .gfx0_ok(gfx0_ok),
        .rom_a1(rom_a1), .gfx1_data(gfx1_data), .gfx1_ok(gfx1_ok),
        .rom_as(rom_as), .gfxs_data(gfxs_data), .gfxs_ok(gfxs_ok),
        .rom_as2(rom_as2), .gfxs2_data(gfxs2_data), .gfxs2_ok(gfxs2_ok),
        .vga_r(r5), .vga_g(g5), .vga_b(b5),
        .hsync(hs_w), .vsync(vs_w), .hblank(hb_w), .vblank(vb_w), .de(de_w),
        .vblank_irq(vblank_irq),

        .cpu_vwe(vmem_we & vmem_cs_vram), .cpu_vaddr(vmem_addr[14:0])
    );

    assign gfx0_addr = rom_a0;
    assign gfx1_addr = rom_a1;

`ifdef WRALLY2_L0ONLY
    assign gfx0_cs = 1'b1;
    assign gfx1_cs = 1'b0;
`else
    assign gfx0_cs = disp_twin | ~disp_index;
    assign gfx1_cs = disp_twin |  disp_index;
`endif
    assign gfxs_addr = rom_as; assign gfxs_cs = 1'b1;

    assign gfxs2_addr = rom_as2; assign gfxs2_cs = disp_twin | disp_index;

    assign red   = r5;
    assign green = g5;
    assign blue  = b5;
    assign HS    = hs_w;
    assign VS    = vs_w;
    assign LHBL  = ~hb_w;
    assign LVBL  = ~vb_w;

    assign snd_left  = snd_l;
    assign snd_right = snd_r;
    assign sample    = snd_sample_w;

    assign debug_view = 8'd0;
    assign dip_flip   = 1'b0;

`ifdef JTFRAME_GAME_UART
    localparam [23:0] U_SAT24 = 24'hFFFFFF;

    reg [19:1] tl_pamax = 19'd0;
    always @(posedge clkg) begin
        if (rst)                        tl_pamax <= 19'd0;
        else if (rom68k_addr > tl_pamax) tl_pamax <= rom68k_addr;
    end
    wire [23:0] dbg_68k_pcmax = {4'd0, tl_pamax, 1'b0};

    wire tl_pkt_start;
    wire [8*16-1:0] tl_data = {
        8'h0A,
        8'd0,
        dbg_mcu_scrw,
        dbg_68k_pcmax,
        dbg_key,
        dbg_mcuw,
        dbg_mcu_fetch,
        dbg_mcu_pcmax,
        8'hAA, 8'h55 };
    localparam integer UART_NB = 16;
    wrally2_dbg_uart #(.NB(UART_NB), .DIV(5000)) u_dbg_uart (
        .clk(clkg), .rst(rst), .data(tl_data), .pkt_start(tl_pkt_start), .txd(uart_tx)
    );
`ifdef SIMULATION

    integer tlk;
    always @(posedge clkg) if (!rst && tl_pkt_start) begin
        $write("PKT");
        for (tlk=0; tlk<UART_NB; tlk=tlk+1) $write(" %02x", tl_data[8*tlk +: 8]);
        $write("\n");
    end
`endif
`endif

`ifdef SIMULATION
    integer wr_vram=0, wr_pal=0, n_progrd=0, mcu_fetch=0, mcu_shwr=0, mcu_rst=0;
    reg [19:1] pcmax=0; reg [19:0] hb=0; reg [14:0] dallas_prev=0, mcu_pcmax=0;
    reg mcuw_prev=0, rdw_prev=0;
    integer mcu_rdn=0;

    integer k68w=0, n68log=0, key_seen=0;
    reg sw_prev=0;
    reg seen_2f9e=0, seen_3330=0, seen_ff12=0;

    integer nwr=0, nwrlog=0; reg wrcyc_prev=0;

    integer nwrbus=0; reg wrbus_prev=0;

    reg [19:1] pc_last=0; integer npc=0;

    integer nlatch=0, nlatchlog=0; reg latch_prev=0;
    always @(posedge clkg) begin
        latch_prev <= u_main.latch_we;
        if (u_main.latch_we & ~latch_prev) begin
            nlatch <= nlatch+1;
            if (nlatchlog<20) begin nlatchlog <= nlatchlog+1;
                $display("LS259 wr#%0d sel=%0d dat=%b%s", nlatch, u_main.latch_sel, u_main.oEdb[0],
                         (u_main.latch_sel==3'd5)?" (ADC clk)":(u_main.latch_sel==3'd6)?" (ADC cs)":""); end
        end
        if (main_cs && main_ok) begin n_progrd<=n_progrd+1; if (rom68k_addr>pcmax) pcmax<=rom68k_addr; end
        if (vmem_we && vmem_cs_vram) wr_vram<=wr_vram+1;
        if (vmem_we && vmem_cs_pal ) wr_pal <=wr_pal +1;
        dallas_prev <= dallas_addr;
        if (dallas_addr != dallas_prev) mcu_fetch <= mcu_fetch+1;
        if (dallas_addr > mcu_pcmax) mcu_pcmax <= dallas_addr;
        if (dallas_addr<15'd8 && dallas_prev>=15'd8) mcu_rst <= mcu_rst+1;

        mcuw_prev <= (u_main.mcu_xwr & u_main.mcu_sh);
        if ((u_main.mcu_xwr & u_main.mcu_sh) & ~mcuw_prev) begin
            mcu_shwr <= mcu_shwr+1;
            if (mcu_shwr<24) $display("RTLMCUW#%0d [%04x]=%02x mcuPC=%h", mcu_shwr, u_main.mcu_xaddr, u_main.mcu_xdout, dallas_addr);
        end

        sw_prev <= (u_main.sw_hi | u_main.sw_lo);
        if ((u_main.sw_hi | u_main.sw_lo) & ~sw_prev) begin
            k68w <= k68w+1;
            if (n68log<60) begin
                n68log <= n68log+1;
                $display("RTL68kSHW#%0d shidx=%h hi=%b lo=%b data=%04x 68kPC=%h", k68w, u_main.shidx, u_main.sw_hi, u_main.sw_lo, u_main.oEdb, {rom68k_addr,1'b0});
            end

            if (u_main.shidx==14'h3e02) begin
                key_seen <= key_seen+1;
                $display(">>> RTL KEY fefc04 WRITE #%0d hi=%b lo=%b data=%04x 68kPC=%h", key_seen, u_main.sw_hi, u_main.sw_lo, u_main.oEdb, {rom68k_addr,1'b0});
            end
        end

        if (main_cs && main_ok && rom68k_addr!=pc_last && npc<80) begin
            pc_last <= rom68k_addr; npc <= npc+1;
            $display("RTLPC#%0d addr=%h data=%04x", npc, {rom68k_addr,1'b0}, main_data);
        end

        wrbus_prev <= (~u_main.ASn & ~u_main.rw_rd & (u_main.uds|u_main.lds));
        if ((~u_main.ASn & ~u_main.rw_rd & (u_main.uds|u_main.lds)) & ~wrbus_prev) nwrbus <= nwrbus+1;

        wrcyc_prev <= (u_main.wr_ack & ~u_main.rw_rd);
        if ((u_main.wr_ack & ~u_main.rw_rd) & ~wrcyc_prev) begin
            nwr <= nwr+1;
            if (nwrlog<40) begin
                nwrlog <= nwrlog+1;
                $display("RTL68kWR#%0d addr=%h uds=%b lds=%b data=%04x | rom=%b vram=%b pal=%b vreg=%b wram=%b shram=%b snd=%b",
                    nwr, u_main.addr, u_main.uds, u_main.lds, u_main.oEdb,
                    u_main.cs_rom, u_main.cs_vram, u_main.cs_pal, u_main.cs_vregs, u_main.cs_wram, u_main.cs_shram, u_main.cs_sound);
            end
        end

        if (main_cs && main_ok) begin
            if (rom68k_addr==19'h7f89 && !seen_ff12) begin seen_ff12<=1; $display(">>> 68k @ 0xff12 (clear-loop) hb=%0d", hb); end
            if (rom68k_addr==19'h17cf && !seen_2f9e) begin seen_2f9e<=1; $display(">>> 68k @ 0x2f9e (KEY code) hb=%0d", hb); end
            if (rom68k_addr==19'h1998 && !seen_3330) begin seen_3330<=1; $display(">>> 68k @ 0x3330 (post-key)  hb=%0d", hb); end
        end
        hb<=hb+1'b1;
        if (hb==20'd0) $display("HB 68kpc=%h pcmax=%h | MCU pc=%h pcmax=%h fetch=%0d mcuW=%0d | WRbus=%0d SHW=%0d KEY=%0d LS259=%0d @ff12=%0d @2f9e=%0d @3330=%0d",
                                {rom68k_addr,1'b0}, {pcmax,1'b0}, dallas_addr, mcu_pcmax, mcu_fetch, mcu_shwr, nwrbus, k68w, key_seen, nlatch, seen_ff12, seen_2f9e, seen_3330);

        if (hb==20'd0) $display("  BUS addr=%h ASn=%b rw_rd=%b uds=%b lds=%b | rom=%b vram=%b pal=%b vreg=%b wram=%b shram=%b snd=%b | wr_ack=%b main_cs=%b main_ok=%b",
                                u_main.addr, u_main.ASn, u_main.rw_rd, u_main.uds, u_main.lds,
                                u_main.cs_rom, u_main.cs_vram, u_main.cs_pal, u_main.cs_vregs, u_main.cs_wram, u_main.cs_shram, u_main.cs_sound,
                                u_main.wr_ack, main_cs, main_ok);
    end
`endif

endmodule

`default_nettype wire
