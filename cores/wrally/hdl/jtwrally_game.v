`default_nettype none

module jtwrally_game(
    `include "jtframe_game_ports.inc"
);

    wire clkg = clk48;

    reg [2:0] pxdiv = 3'd0;
    always @(posedge clkg) pxdiv <= (pxdiv==3'd5) ? 3'd0 : pxdiv + 3'd1;
    assign pxl_cen  = (pxdiv==3'd0);
    assign pxl2_cen = (pxdiv==3'd0) || (pxdiv==3'd3);
    wire ce_pix = (pxdiv==3'd0);

    reg [1:0] cdiv = 2'd0;
    reg [5:0] odiv = 6'd0;
    reg cpu_cen_phi1 = 1'b0, cpu_cen_phi2 = 1'b0, mcu_cen = 1'b0, oki_cen = 1'b0;

`ifdef WR_TESTPAUSE
    wire dip_pause_g = 1'b0;
`else
    wire dip_pause_g = dip_pause;
`endif
    always @(posedge clkg) begin
        cdiv         <= (cdiv==2'd3) ? 2'd0 : cdiv + 2'd1;
        cpu_cen_phi1 <= (cdiv==2'd0);
        cpu_cen_phi2 <= (cdiv==2'd2);

        mcu_cen      <= (cdiv==2'd0) & dip_pause_g;
        odiv         <= (odiv==6'd47) ? 6'd0 : odiv + 6'd1;
        oki_cen      <= (odiv==6'd0);
    end

    wire [14:0] mcurom_addr;
    wire        mcurom_en;
    assign wrdallas_addr = mcurom_addr;

    wire [ 7:0] mcurom_data = wrdallas_data;

`ifdef SIMULATION
    integer n_mcurd=0; reg [31:0] nz_wrdallas=0;
    always @(posedge clk) if (!rst) begin
        if (wrdallas_data!=8'd0) nz_wrdallas <= nz_wrdallas+1;
        if (mcurom_en && n_mcurd<16) begin
            n_mcurd = n_mcurd+1;
            $display("MCUROM #%0d addr=%h en=%b wrdallas=%h mcurom_data=%h nz=%0d",
                     n_mcurd, mcurom_addr, mcurom_en, wrdallas_data, mcurom_data, nz_wrdallas);
        end
    end
`endif

    wire        flip_screen, vblank_irq;
    wire [13:0] vmem_addr; wire vmem_uds, vmem_lds, vmem_we, vmem_cs_vram, vmem_cs_pal, vmem_cs_spr;
    wire [15:0] vmem_vram_wdata, vmem_io_wdata, vmem_vram_rdata, vmem_pal_rdata, vmem_spr_rdata;
    wire [15:0] vreg0, vreg1, vreg2, vreg3;
    wire [15:0] dbg_firma_w; wire [7:0] dbg_mcu_act_w;

    wire [15:0] dbg_mcu_pc_w, dbg_mcu_pcmax_w, dbg_mcu_fetch_w, dbg_mcu_oor_w, dbg_mcu_coll_w;
    wire [ 7:0] dbg_rd0_w, dbg_rd1_w, dbg_rd2_w, dbg_rd3_w, dbg_mcu_wrby_w, dbg_1a80_mcu_w, dbg_1a80_cpu_w;
    wire [13:0] dbg_mcu_wradr_w;
    wire [15:0] dbg_mcu_rdmax_w, dbg_mcu_rdadr_w, dbg_mcu_nrd_w;
    wire [ 7:0] dbg_mcu_rdby_w, dbg_68k_wrby_w;
    wire [13:0] dbg_68k_wradr_w;
    wire        dbg_68k_w01_w;
    wire [23:0] dbg_68k_fpc_w, dbg_68k_dacc_w;
    wire [15:0] dbg_68k_flow_w, dbg_68k_iack_w, dbg_68k_h400_w, dbg_68k_exc_w;
    wire [ 7:0] dbg_exc_num_w;  wire [23:0] dbg_fault_pc_w, dbg_fault_pcl_w, dbg_68k_fault1_w;
    wire [23:0] dbg_rst_sp_w, dbg_rst_pc_w, dbg_first_fetch_w;
    wire [19:1] rom68k_addr;
    wire [19:0] oki_rom_addr;
    wire [13:0] snd14;
    wire        snd_sample_w;

    wire [15:0] in_dsw, in_p1p2, in_wheel, in_system;

`ifdef WR_SCENE
    wire cpu_rst = 1'b1;
    reg [15:0] scene_vreg [0:3];
    initial $readmemh("scene_vregs.hex", scene_vreg);
    wire [15:0] vv0=scene_vreg[0], vv1=scene_vreg[1], vv2=scene_vreg[2], vv3=scene_vreg[3];
`else
    wire cpu_rst = rst;
    wire [15:0] vv0=vreg0, vv1=vreg1, vv2=vreg2, vv3=vreg3;
`endif

`ifdef SIMULATION
  `ifdef WRALLY_MCU_SLOW
    localparam MCU_FS = 1'b0;
  `else
    localparam MCU_FS = 1'b1;
  `endif
`else
    localparam MCU_FS = 1'b1;

`endif
    wrally_main #(.MCU_FULLSPEED(MCU_FS), .MCU_STUB(1'b0)) u_cpu (
        .clk(clkg), .rst(cpu_rst), .game_run(dip_pause_g),
        .cpu_cen_phi1(cpu_cen_phi1), .cpu_cen_phi2(cpu_cen_phi2),
        .mcu_cen(mcu_cen), .oki_cen(oki_cen),
        .vblank_irq(vblank_irq),
        .prog_addr(rom68k_addr), .prog_cs(cpu_main_cs), .prog_data(main_data), .prog_data_ok(main_ok),
        .mcurom_addr(mcurom_addr), .mcurom_en(mcurom_en), .mcurom_data(mcurom_data),
        .oki_rom_addr(oki_rom_addr), .oki_rom_data(oki_data), .oki_rom_ok(oki_ok),
        .in_dsw(in_dsw), .in_p1p2(in_p1p2), .in_wheel(in_wheel), .in_system(in_system),
        .flip_screen(flip_screen),
        .vmem_addr(vmem_addr), .vmem_uds(vmem_uds), .vmem_lds(vmem_lds), .vmem_we(vmem_we),
        .vmem_cs_vram(vmem_cs_vram), .vmem_cs_pal(vmem_cs_pal), .vmem_cs_spr(vmem_cs_spr),
        .vmem_vram_wdata(vmem_vram_wdata), .vmem_io_wdata(vmem_io_wdata),
        .vmem_vram_rdata(vmem_vram_rdata), .vmem_pal_rdata(vmem_pal_rdata), .vmem_spr_rdata(vmem_spr_rdata),
        .vreg0(vreg0), .vreg1(vreg1), .vreg2(vreg2), .vreg3(vreg3),
        .sound(snd14), .snd_sample(snd_sample_w),
        .dbg_firma(dbg_firma_w), .dbg_mcu_act(dbg_mcu_act_w),
        .dbg_mcu_pc(dbg_mcu_pc_w), .dbg_mcu_pcmax(dbg_mcu_pcmax_w), .dbg_mcu_fetch(dbg_mcu_fetch_w),
        .dbg_rd0(dbg_rd0_w), .dbg_rd1(dbg_rd1_w), .dbg_rd2(dbg_rd2_w), .dbg_rd3(dbg_rd3_w),
        .dbg_mcu_oor(dbg_mcu_oor_w), .dbg_mcu_wradr(dbg_mcu_wradr_w), .dbg_mcu_wrby(dbg_mcu_wrby_w),
        .dbg_mcu_coll(dbg_mcu_coll_w), .dbg_1a80_mcu(dbg_1a80_mcu_w), .dbg_1a80_cpu(dbg_1a80_cpu_w),
        .dbg_mcu_rdmax(dbg_mcu_rdmax_w), .dbg_mcu_rdadr(dbg_mcu_rdadr_w), .dbg_mcu_rdby(dbg_mcu_rdby_w),
        .dbg_mcu_nrd(dbg_mcu_nrd_w), .dbg_68k_wradr(dbg_68k_wradr_w), .dbg_68k_wrby(dbg_68k_wrby_w),
        .dbg_68k_w01(dbg_68k_w01_w),
        .dbg_68k_fpc(dbg_68k_fpc_w), .dbg_68k_dacc(dbg_68k_dacc_w), .dbg_68k_flow(dbg_68k_flow_w),
        .dbg_68k_iack(dbg_68k_iack_w), .dbg_68k_h400(dbg_68k_h400_w), .dbg_68k_exc(dbg_68k_exc_w),
        .dbg_exc_num(dbg_exc_num_w), .dbg_fault_pc(dbg_fault_pc_w), .dbg_fault_pcl(dbg_fault_pcl_w),
        .dbg_68k_fault1(dbg_68k_fault1_w),
        .dbg_rst_sp(dbg_rst_sp_w), .dbg_rst_pc(dbg_rst_pc_w), .dbg_first_fetch(dbg_first_fetch_w)
    );
    wire cpu_main_cs;

`ifdef WRALLY_CKS
    localparam        SDRAM_CKS  = 1'b1;
`else
    localparam        SDRAM_CKS  = 1'b0;
`endif
    localparam [31:0] CKS_GOLDEN = 32'h72E29C19;
    reg  [18:0] cks_addr = 19'd0;
    reg         cks_cs   = 1'b0;
    reg  [31:0] cks_sum  = 32'd0;
    reg         cks_done = 1'b0;
    reg         cks_st   = 1'b0;

    reg  [15:0] cks_w0=0, cks_w1=0, cks_w2=0, cks_w3=0, cks_w4=0, cks_w5=0, cks_w6=0, cks_w7=0;
    always @(posedge clk) begin
        if (rst) begin cks_addr<=0; cks_cs<=0; cks_sum<=0; cks_done<=0; cks_st<=0; end
        else if (SDRAM_CKS && !cks_done) case (cks_st)
            1'b0: begin cks_cs <= 1'b1; cks_st <= 1'b1; end
            1'b1: if (main_ok) begin
                      cks_sum <= {cks_sum[30:0], cks_sum[31]} + main_data;
                      cks_cs  <= 1'b0;
                      case (cks_addr[2:0])
                        3'd0: if(cks_addr==0) cks_w0<=main_data;
                        3'd1: if(cks_addr==1) cks_w1<=main_data;
                        3'd2: if(cks_addr==2) cks_w2<=main_data;
                        3'd3: if(cks_addr==3) cks_w3<=main_data;
                        3'd4: if(cks_addr==4) cks_w4<=main_data;
                        3'd5: if(cks_addr==5) cks_w5<=main_data;
                        3'd6: if(cks_addr==6) cks_w6<=main_data;
                        3'd7: if(cks_addr==7) cks_w7<=main_data;
                      endcase
                      if (cks_addr == 19'h7FFFF) cks_done <= 1'b1;
                      else begin cks_addr <= cks_addr + 1'b1; cks_st <= 1'b0; end
                  end
        endcase
    end
    wire cks_match = cks_done && (cks_sum == CKS_GOLDEN);
    wire cks_fail  = cks_done && (cks_sum != CKS_GOLDEN);

    reg  [19:0] c2_baddr = 20'd0;
    reg         c2_cs    = 1'b0;
    reg  [31:0] c2_sum   = 32'd0;
    reg         c2_done  = 1'b0;
    reg  [ 1:0] c2_st    = 2'd0;
    reg  [ 7:0] c2_lo    = 8'd0;
    reg  [127:0] c2_bytes = 128'd0;
    always @(posedge clk) begin
        if (rst) begin c2_baddr<=0; c2_cs<=0; c2_sum<=0; c2_done<=0; c2_st<=0; c2_lo<=0; end
        else if (SDRAM_CKS && !c2_done) case (c2_st)
            2'd0: begin c2_cs<=1'b1; c2_st<=2'd1; end
            2'd1: if (oki_ok) begin
                      c2_lo <= oki_data;
                      if (c2_baddr < 20'd16) c2_bytes[8*c2_baddr[3:0] +: 8] <= oki_data;
                      c2_cs <= 1'b0; c2_baddr <= c2_baddr + 1'b1; c2_st <= 2'd2;
                  end
            2'd2: begin c2_cs<=1'b1; c2_st<=2'd3; end
            2'd3: if (oki_ok) begin
                      if (c2_baddr < 20'd16) c2_bytes[8*c2_baddr[3:0] +: 8] <= oki_data;
                      c2_sum <= {c2_sum[30:0], c2_sum[31]} + {oki_data, c2_lo};
                      c2_cs <= 1'b0;
                      if (c2_baddr == 20'hFFFFF) c2_done <= 1'b1;
                      else begin c2_baddr <= c2_baddr + 1'b1; c2_st <= 2'd0; end
                  end
        endcase
    end
    wire c2_match = c2_done && (c2_sum == CKS_GOLDEN);

    assign main_addr = SDRAM_CKS ? cks_addr   : rom68k_addr;
    assign main_cs   = SDRAM_CKS ? cks_cs     : cpu_main_cs;

    wire [13:0] vram_a0, vram_a1; wire [31:0] vram_q0, vram_q1;
    wire [9:0]  pal_a;  wire [12:0] palb_a;
    wire [15:0] pal_q, palb_q;
    wire [10:0] spr_a;            wire [15:0] spr_q;

    wrally_vmem u_vmem (
        .clk(clkg), .ce_pix(ce_pix),
        .cpu_addr(vmem_addr), .cpu_uds(vmem_uds), .cpu_lds(vmem_lds), .cpu_we(vmem_we),
        .cs_vram(vmem_cs_vram), .cs_pal(vmem_cs_pal), .cs_spr(vmem_cs_spr),
        .vram_wdata(vmem_vram_wdata), .io_wdata(vmem_io_wdata),
        .cpu_vram_rdata(vmem_vram_rdata), .cpu_pal_rdata(vmem_pal_rdata), .cpu_spr_rdata(vmem_spr_rdata),
        .vram_a0(vram_a0), .vram_a1(vram_a1), .vram_q0(vram_q0), .vram_q1(vram_q1),
        .pal_a(pal_a), .palb_a(palb_a), .pal_q(pal_q), .palb_q(palb_q),
        .spr_a(spr_a), .spr_q(spr_q)
    );

    wire [18:0] rom_a0, rom_a1, srom_a;

    assign gfx0_addr = rom_a0;  assign gfx0_cs = SDRAM_CKS ? 1'b0 : 1'b1;
    assign gfx1_addr = rom_a1;  assign gfx1_cs = SDRAM_CKS ? 1'b0 : 1'b1;
    assign gfxs_addr = srom_a;  assign gfxs_cs = SDRAM_CKS ? 1'b0 : 1'b1;

    assign oki_addr = SDRAM_CKS ? c2_baddr : oki_rom_addr;
    assign oki_cs   = SDRAM_CKS ? c2_cs    : 1'b1;

    wire [7:0] d0_i07,d0_i09,d0_i11,d0_i13, d1_i07,d1_i09,d1_i11,d1_i13, sd_i07,sd_i09,sd_i11,sd_i13;
    assign {d0_i13,d0_i11,d0_i09,d0_i07} = gfx0_data;
    assign {d1_i13,d1_i11,d1_i09,d1_i07} = gfx1_data;
    assign {sd_i13,sd_i11,sd_i09,sd_i07} = gfxs_data;

    wire [7:0] r8, g8, b8;
    wire       hs_w, vs_w, hb_w, vb_w, de_w;
    wrally_video_top u_video (
        .clk(clkg), .clk96(clk96), .rst(rst), .ce_pix(ce_pix),
        .vreg_l0y(vv0), .vreg_l0x(vv1), .vreg_l1y(vv2), .vreg_l1x(vv3),
        .vram_a0(vram_a0), .vram_q0(vram_q0), .rom_a0(rom_a0),
        .d0_i07(d0_i07), .d0_i09(d0_i09), .d0_i11(d0_i11), .d0_i13(d0_i13),
        .vram_a1(vram_a1), .vram_q1(vram_q1), .rom_a1(rom_a1),
        .d1_i07(d1_i07), .d1_i09(d1_i09), .d1_i11(d1_i11), .d1_i13(d1_i13),
        .pal_a(pal_a), .pal_q(pal_q), .palb_a(palb_a), .palb_q(palb_q),
        .spr_a(spr_a), .spr_q(spr_q), .srom_a(srom_a),
        .sd_i07(sd_i07), .sd_i09(sd_i09), .sd_i11(sd_i11), .sd_i13(sd_i13),
        .gfx0_ok(gfx0_ok), .gfx1_ok(gfx1_ok),
        .spr_gfx_ok(gfxs_ok), .spr_en(1'b1),
        .vga_r(r8), .vga_g(g8), .vga_b(b8),
        .hsync(hs_w), .vsync(vs_w), .hblank(hb_w), .vblank(vb_w), .de(de_w),
        .ce_pix_o(), .vblank_irq(vblank_irq)
    );

    wire [3:0] cks_r = cks_fail  ? 4'hF : 4'h0;
    wire [3:0] cks_g = cks_match ? 4'hF : (cks_done ? 4'h0 : cks_addr[18:15]);
    wire [3:0] cks_b = cks_done  ? 4'h0 : 4'hF;
    assign red   = SDRAM_CKS ? cks_r : r8[7:4];
    assign green = SDRAM_CKS ? cks_g : g8[7:4];
    assign blue  = SDRAM_CKS ? cks_b : b8[7:4];
    assign HS    = hs_w;
    assign VS    = vs_w;
    assign LHBL  = ~hb_w;
    assign LVBL  = ~vb_w;

    wire signed [17:0] snd_g8 = $signed(snd14) * 18'sd12;
    assign snd = ( snd_g8 >  18'sd32767 ) ?  16'sd32767 :
                 ( snd_g8 < -18'sd32768 ) ? -16'sd32768 :
                                             snd_g8[15:0];

    assign sample = snd_sample_w;

    reg p1_gear_st=1'b0, p2_gear_st=1'b0, p1_gbtn_d=1'b0, p2_gbtn_d=1'b0;
    wire p1_gbtn = ~joystick1[5];
    wire p2_gbtn = ~joystick2[5];
    always @(posedge clkg) begin
        if (rst) begin p1_gear_st<=1'b0; p2_gear_st<=1'b0; p1_gbtn_d<=1'b0; p2_gbtn_d<=1'b0; end
        else begin
            p1_gbtn_d <= p1_gbtn; p2_gbtn_d <= p2_gbtn;
            if (p1_gbtn & ~p1_gbtn_d) p1_gear_st <= ~p1_gear_st;
            if (p2_gbtn & ~p2_gbtn_d) p2_gear_st <= ~p2_gear_st;
        end
    end

    wire coin1_base = ~coin[0];
`ifdef WR_INJECT_COIN

    wire coin1_inj = coin1_base | (tl_frame >= 24'd150 && tl_frame <= 24'd169);
`else
    wire coin1_inj = coin1_base;
`endif

    wrally_inputs u_inputs (
        .dsw   ( dipsw[15:0] ),
        .p1_up( ~joystick1[3] ), .p1_down( ~joystick1[2] ),
        .p1_left( ~joystick1[1] ), .p1_right( ~joystick1[0] ),
        .p1_btn1( ~joystick1[4] ), .p1_gear( p1_gear_st ),
        .p2_up( ~joystick2[3] ), .p2_down( ~joystick2[2] ),
        .p2_left( ~joystick2[1] ), .p2_right( ~joystick2[0] ),
        .p2_btn1( ~joystick2[4] ), .p2_gear( p2_gear_st ),

        .coin1( coin1_inj ), .coin2( ~coin[1] ),
        .start1( ~cab_1p[0] ), .start2( ~cab_1p[1] ),
        .service( ~service ), .test( ~dip_test ),
        .port_dsw( in_dsw ), .port_p1p2( in_p1p2 ),
        .port_wheel( in_wheel ), .port_system( in_system )
    );

`ifdef SIMULATION
    integer wr_vram=0, wr_pal=0, wr_spr=0, n_progrd=0, n_maincs=0, n_mainok=0, n_cen=0, n_clk=0, n_dist=0, n_okrise=0;
    reg [19:1] pcmax=0; reg vset=0; reg [19:1] last_pa=19'h7ffff; reg main_ok_prev=0;

    integer n_cepix=0, n_gfx0nr=0, n_gfx1nr=0;
    always @(posedge clkg) if (ce_pix) begin
        n_cepix <= n_cepix+1;
        if (!gfx0_ok) n_gfx0nr <= n_gfx0nr+1;
        if (!gfx1_ok) n_gfx1nr <= n_gfx1nr+1;
    end

    always @(posedge clk) begin
        main_ok_prev <= main_ok;
        if (main_cs & main_ok & ~main_ok_prev & (n_okrise < 16)) begin
            $display("OKRISE #%0d addr=%h data=%h", n_okrise, {rom68k_addr,1'b0}, main_data);
            n_okrise <= n_okrise + 1;
        end
    end
    reg [19:0] hb=0;
    always @(posedge clk) begin
        n_clk <= n_clk + 1;
        if (main_cs)            n_maincs<=n_maincs+1;
        if (main_ok)            n_mainok<=n_mainok+1;
        if (cpu_cen_phi1)       n_cen  <=n_cen +1;
        if (main_cs && main_ok) begin
            n_progrd<=n_progrd+1; if (rom68k_addr>pcmax) pcmax<=rom68k_addr;

            if (rom68k_addr != last_pa && n_dist < 24) begin
                $display("RD #%0d addr=%h data=%h", n_dist, {rom68k_addr,1'b0}, main_data);
                n_dist <= n_dist + 1;
            end
            last_pa <= rom68k_addr;
        end
        if (vmem_we && vmem_cs_vram) wr_vram<=wr_vram+1;
        if (vmem_we && vmem_cs_pal ) wr_pal <=wr_pal +1;
        if (vmem_we && vmem_cs_spr ) wr_spr <=wr_spr +1;
        if (|{vreg0,vreg1,vreg2,vreg3}) vset<=1'b1;
        hb<=hb+1'b1;
        if (hb==20'd0) $display("HB nclk=%0d pc=%h progrd=%0d PCmax=%h vram=%0d pal=%0d spr=%0d vset=%b mcuact=%h firma=%h | cepix=%0d gfx0nr=%0d gfx1nr=%0d",
                                n_clk, {rom68k_addr,1'b0}, n_progrd, {pcmax,1'b0}, wr_vram, wr_pal, wr_spr, vset, dbg_mcu_act_w, dbg_firma_w, n_cepix, n_gfx0nr, n_gfx1nr);
    end
`endif

`ifdef JTFRAME_GAME_UART
    localparam [23:0] SAT24 = 24'hFFFFFF;
    localparam [15:0] SAT16 = 16'hFFFF;
    reg [23:0] tl_frame=0, tl_vram=0, tl_gfxnr=0, tl_progrd=0;
    reg [19:1] tl_pamax=0;
    reg [15:0] tl_pal=0, tl_mainstall=0;
    reg        tl_vset=0, tl_vbl=0, tl_mokp=0;

    reg [23:0] frz_vsnap=0, frz_streak_start=0;
    reg [15:0] frz_static=0;
    always @(posedge clkg) begin
        if (rst) begin
            tl_frame<=0; tl_vram<=0; tl_gfxnr<=0; tl_progrd<=0; tl_pamax<=0;
            tl_pal<=0; tl_mainstall<=0; tl_vset<=0; tl_vbl<=0; tl_mokp<=0;
            frz_vsnap<=0; frz_streak_start<=0; frz_static<=0;
        end else begin
            if (vblank_irq) begin
                if (tl_vram == frz_vsnap) begin
                    if (frz_static != 16'hFFFF) frz_static <= frz_static + 1'b1;
                end else begin
                    frz_static <= 16'd0; frz_streak_start <= tl_frame;
                end
                frz_vsnap <= tl_vram;
            end
            if (vblank_irq)                      tl_frame <= tl_frame + 1'b1;
            if (vblank_irq)                      tl_vbl   <= 1'b1;
            if (rom68k_addr > tl_pamax)          tl_pamax <= rom68k_addr;
            if (vmem_we && vmem_cs_vram && tl_vram!=SAT24)      tl_vram  <= tl_vram + 1'b1;
            if (vmem_we && vmem_cs_pal  && tl_pal !=SAT16)      tl_pal   <= tl_pal  + 1'b1;
            if (ce_pix && (!gfx0_ok || !gfx1_ok) && tl_gfxnr!=SAT24) tl_gfxnr <= tl_gfxnr + 1'b1;
            tl_mokp <= (main_cs & main_ok);
            if (main_cs & main_ok & ~tl_mokp & (tl_progrd!=SAT24)) tl_progrd <= tl_progrd + 1'b1;
            if (main_cs & ~main_ok & (tl_mainstall!=SAT16))        tl_mainstall <= tl_mainstall + 1'b1;
            if (|{vreg0,vreg1,vreg2,vreg3})      tl_vset  <= 1'b1;
        end
    end
    wire [23:0] tl_palive = {4'd0, rom68k_addr, 1'b0};
    wire [23:0] tl_pamaxb = {4'd0, tl_pamax,    1'b0};
    wire [7:0]  tl_status = {3'b0, tl_vset, tl_vbl, main_ok, gfx0_ok, gfx1_ok};

    localparam NPAGE = 3'd7;
    wire tl_pkt_start;
    reg [2:0] tl_page = 0;
    always @(posedge clkg) if (rst) tl_page<=0; else if (tl_pkt_start) tl_page <= (tl_page==NPAGE-1)?3'd0:tl_page+1'b1;

    reg [3:0]  seen_coin=0, seen_cab=0;
    reg [5:0]  seen_joy1=0;
    reg        seen_serv=0, seen_test=0;
    reg [15:0] p1p2_anylow=16'hFFFF;
    always @(posedge clkg) if (rst) begin
        seen_coin<=0; seen_cab<=0; seen_joy1<=0; seen_serv<=0; seen_test<=0; p1p2_anylow<=16'hFFFF;
    end else begin
        seen_coin   <= seen_coin | ~coin;
        seen_cab    <= seen_cab  | ~cab_1p;
        seen_joy1   <= seen_joy1 | ~joystick1[5:0];
        seen_serv   <= seen_serv | ~service;
        seen_test   <= seen_test | ~dip_test;
        p1p2_anylow <= p1p2_anylow & in_p1p2;
    end

    wire [223:0] tl_pl0 = { 88'd0, frz_static, frz_streak_start, tl_gfxnr, tl_mainstall, tl_status, tl_progrd, tl_frame };

    wire [223:0] tl_pl1 = { 40'd0, dbg_68k_exc_w, dbg_68k_h400_w, dbg_68k_iack_w, dbg_68k_flow_w,
                            dbg_68k_dacc_w, dbg_68k_fpc_w, tl_progrd, tl_pamaxb, tl_palive };

    wire [223:0] tl_pl2 = { 112'd0, {7'd0,tl_vset}, vreg3, vreg2, vreg1, vreg0, tl_pal, tl_vram };

    wire [223:0] tl_pl3 = { 128'd0, dbg_rd3_w, dbg_rd2_w, dbg_rd1_w, dbg_rd0_w,
                            dbg_mcu_oor_w, dbg_mcu_fetch_w, dbg_mcu_pcmax_w, dbg_mcu_pc_w };

    wire [223:0] tl_pl4 = { 40'd0, {7'd0,dbg_68k_w01_w}, dipsw[15:0],
        dbg_68k_wrby_w, {2'd0,dbg_68k_wradr_w}, dbg_mcu_nrd_w, dbg_mcu_rdby_w, dbg_mcu_rdadr_w, dbg_mcu_rdmax_w,
        dbg_1a80_cpu_w, dbg_1a80_mcu_w, dbg_mcu_coll_w, dbg_mcu_wrby_w, {2'd0,dbg_mcu_wradr_w}, dbg_mcu_act_w, dbg_firma_w };

    wire [223:0] tl_pl5 = { 72'd0, dbg_first_fetch_w, dbg_rst_pc_w, dbg_rst_sp_w,
                            dbg_68k_fault1_w, dbg_fault_pcl_w, dbg_fault_pc_w, dbg_exc_num_w };

    wire [223:0] tl_pl6 = { 176'd0, p1p2_anylow[15:0], {2'd0,seen_joy1[5:0]},
                            {4'd0,seen_cab[3:0]}, {4'd0,seen_coin[3:0]}, {5'd0,dip_pause,seen_test,seen_serv} };

    reg [223:0] tl_payload;
    always @(*) case (tl_page)
        3'd0: tl_payload = tl_pl0;
        3'd1: tl_payload = tl_pl1;
        3'd2: tl_payload = tl_pl2;
        3'd3: tl_payload = tl_pl3;
        3'd4: tl_payload = tl_pl4;
        3'd5: tl_payload = tl_pl5;
        default: tl_payload = tl_pl6;
    endcase
`ifdef WRALLY_CKS

    wire [8*64-1:0] tl_data = {
        8'h0A,
        96'd0,
        c2_bytes,
        {7'd0,c2_done},
        {4'd0,c2_baddr},
        c2_sum,
        cks_w7, cks_w6, cks_w5, cks_w4, cks_w3, cks_w2, cks_w1, cks_w0,
        {7'd0,cks_done},
        {5'd0,cks_addr},
        cks_sum,
        8'd0,
        8'hAA, 8'h55 };
`else
    wire [8*32-1:0] tl_data = { 8'h0A, tl_payload, {5'd0,tl_page}, 8'hAA, 8'h55 };
`endif

`ifdef WRALLY_CKS
    localparam integer UART_NB = 64;
`else
    localparam integer UART_NB = 32;
`endif
    wrally_dbg_uart #(.NB(UART_NB), .DIV(5000)) u_dbg_uart (
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

    assign debug_view = 8'd0;
    assign dip_flip   = 1'b0;

endmodule

`default_nettype wire
