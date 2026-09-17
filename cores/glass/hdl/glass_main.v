`default_nettype none

module glass_main (
    input  wire        clk,
    input  wire        rst,
    input  wire        game_run,
    input  wire        oki_cen,
    input  wire        vblank_irq,

    output wire [19:1] prog_addr,
    output wire        prog_cs,
    input  wire [15:0] prog_data,
    input  wire        prog_data_ok,

    output wire [19:0] oki_rom_addr,
    input  wire [7:0]  oki_rom_data,
    input  wire        oki_rom_ok,

    input  wire [15:0] in_dsw2, in_dsw1, in_p1, in_p2,

    output wire        flip_screen,
    output wire [13:0] vmem_addr,
    output wire        vmem_uds, vmem_lds,
    output wire        vmem_we,
    output wire        vmem_cs_vram,
    output wire        vmem_cs_scrram,
    output wire        vmem_cs_pal,
    output wire        vmem_cs_spr,
    output wire [15:0] vmem_dec_wdata,
    output wire [15:0] vmem_io_wdata,
    input  wire [15:0] vmem_vram_rdata,
    input  wire [15:0] vmem_scrram_rdata,
    input  wire [15:0] vmem_pal_rdata,
    input  wire [15:0] vmem_spr_rdata,
    output wire [15:0] vreg0, vreg1, vreg2, vreg3,

    output wire signed [13:0] sound,
    output wire        snd_sample,

    output wire [19:0] blit_base,
    output wire        blit_active,

    input  wire        mcu_cen,
    output wire [14:0] mcurom_addr,
    output wire        mcurom_en,
    input  wire [ 7:0] mcurom_data,

    input  wire        scr_dl_clk,
    input  wire [14:0] scr_dl_addr,
    input  wire [ 7:0] scr_dl_data,
    input  wire        scr_dl_we,

    output wire [15:0] dbg_mcu_pcmax,
    output wire [15:0] dbg_mcu_fetch,
    output wire [15:0] dbg_mcuw,
    output wire [15:0] dbg_mcu_scrw,
    output wire [ 7:0] dbg_key,

    output wire [15:0] dbg_mcu_pc_live,
    output wire [ 7:0] dbg_de04_live,
    output wire [ 7:0] dbg_de04_68k,
    output wire [ 7:0] dbg_de04_mcu,
    output wire [ 7:0] dbg_de03_live,
    output wire [ 7:0] dbg_de06_live,
    output wire [ 7:0] dbg_de07_live,

    output wire [ 7:0] dbg_de06_in,
    output wire [ 7:0] dbg_de06_out,
    output wire [ 7:0] dbg_de07_in,
    output wire [ 7:0] dbg_de07_out,
    output wire [ 7:0] dbg_fec076,
    output wire [ 7:0] dbg_fec06e,
    output wire [ 7:0] dbg_fec06f,
    output wire [15:0] dbg_fec078,

    output wire [ 7:0] dbg_fede98,
    output wire [ 7:0] dbg_fede9a,
    output wire [15:0] dbg_fec070,
    output wire [ 7:0] dbg_fec072,
    output wire [15:0] dbg_fec074,
    output wire [ 7:0] dbg_fec077,
    output wire [ 7:0] dbg_fed5c0,
    output wire [ 7:0] dbg_fed5c2,
    output wire [ 7:0] dbg_fed5c4,
    output wire [ 7:0] dbg_fed5c6
);

    wire [23:1] eab;
    wire        ASn, LDSn, UDSn, eRWn;
    wire [15:0] oEdb;
    reg  [15:0] iEdb;
    wire        DTACKn;
    reg         VPAn;
    wire        FC0, FC1, FC2;
    reg         IPL_n;
    wire [2:0]  fc = {FC2, FC1, FC0};
    wire        cpu_cen, cpu_cenb;

    fx68k u_cpu (
        .clk(clk), .HALTn(1'b1),
        .extReset(rst), .pwrUp(rst),
        .enPhi1(cpu_cen), .enPhi2(cpu_cenb),
        .eRWn(eRWn), .ASn(ASn), .LDSn(LDSn), .UDSn(UDSn),
        .E(), .VMAn(), .FC0(FC0), .FC1(FC1), .FC2(FC2),
        .BGn(), .oRESETn(), .oHALTEDn(),
        .DTACKn(DTACKn), .VPAn(VPAn), .BERRn(1'b1),
        .BRn(1'b1), .BGACKn(1'b1),

        .IPL0n(1'b1), .IPL1n(IPL_n), .IPL2n(IPL_n),
        .iEdb(iEdb), .oEdb(oEdb), .eab(eab)
    );

    wire [23:0] addr  = {eab, 1'b0};
    wire        uds   = ~UDSn;
    wire        lds   = ~LDSn;
    wire        rw_rd = eRWn;

    wire cs_rom, cs_vram, cs_scrram, cs_vregs, cs_clrint, cs_pal, cs_spr,
         cs_dsw2, cs_dsw1, cs_p1, cs_p2, cs_outlatch, cs_okibank, cs_oki, cs_blit, cs_shram;
    glass_addr_decode u_dec (
        .addr(addr), .as(~ASn),
        .cs_rom(cs_rom), .cs_vram(cs_vram), .cs_scrram(cs_scrram), .cs_vregs(cs_vregs),
        .cs_clrint(cs_clrint), .cs_pal(cs_pal), .cs_spr(cs_spr),
        .cs_dsw2(cs_dsw2), .cs_dsw1(cs_dsw1), .cs_p1(cs_p1), .cs_p2(cs_p2),
        .cs_outlatch(cs_outlatch), .cs_okibank(cs_okibank), .cs_oki(cs_oki), .cs_blit(cs_blit), .cs_shram(cs_shram)
    );

    assign prog_addr = eab[19:1];
    assign prog_cs   = cs_rom & rw_rd;
    wire [15:0] rom_word = prog_data;

    wire bus_busy  = cs_rom & rw_rd & ~prog_data_ok;
    wire bus_cs_dt = cs_rom & rw_rd;
    wire dtack_raw;
    glass_68kdtack #(.W(8)) u_dtack (
        .rst(rst), .clk(clk),
        .cpu_cen(cpu_cen), .cpu_cenb(cpu_cenb),
        .bus_cs(bus_cs_dt), .bus_busy(bus_busy), .bus_legit(1'b0), .bus_ack(1'b0),
        .ASn(ASn), .DSn({UDSn,LDSn}),
        .num(7'd1), .den(8'd4),
        .wait2(1'b0), .wait3(1'b0),
        .DTACKn(dtack_raw)
    );

    assign DTACKn = (fc == 3'd7) ? 1'b1 : dtack_raw;

    reg [15:0] vregs[0:3];
    assign vreg0 = vregs[0]; assign vreg1 = vregs[1];
    assign vreg2 = vregs[2]; assign vreg3 = vregs[3];

    assign vmem_addr      = addr[13:0];
    assign vmem_uds       = uds;
    assign vmem_lds       = lds;
    assign vmem_cs_vram   = cs_vram;
    assign vmem_cs_scrram = cs_scrram;
    assign vmem_cs_pal    = cs_pal;
    assign vmem_cs_spr    = cs_spr;
    assign vmem_we        = wr_ack & ~rw_rd & (cs_vram | cs_scrram | cs_pal | cs_spr);

    assign vmem_dec_wdata = oEdb;
    assign vmem_io_wdata  = oEdb;

    wire [15:0] dec_word;
    reg  [15:0] vdec_last_enc, vdec_last_dec;
    reg  [12:0] vdec_prev_woff;
    reg         vdec_prev_wr;
    wire [12:0] cur_woff = addr[13:1];
    wire        is2nd = vdec_prev_wr & (vdec_prev_woff == (cur_woff - 13'd1));

    reg  [12:0] pend_woff;
    reg  [15:0] pend_enc, pend_dec;
    reg         pend_vramwr;
    glass_vram_decrypt u_decrypt (
        .enc_prev(is2nd ? vdec_last_enc : 16'd0),
        .dec_prev(is2nd ? vdec_last_dec : 16'd0),
        .enc(oEdb),
        .dec(dec_word)
    );

    always @(*) begin
        iEdb = 16'hFFFF;
        case (1'b1)
            cs_rom:    iEdb = rom_word;
            cs_vram:   iEdb = vmem_vram_rdata;
            cs_scrram: iEdb = vmem_scrram_rdata;
            cs_pal:    iEdb = vmem_pal_rdata;
            cs_spr:    iEdb = vmem_spr_rdata;
            cs_vregs:  iEdb = vregs[addr[2:1]];
            cs_shram:  iEdb = shram_q;
            cs_dsw2:   iEdb = in_dsw2;
            cs_dsw1:   iEdb = in_dsw1;
            cs_p1:     iEdb = in_p1;
            cs_p2:     iEdb = in_p2;
            cs_oki:    iEdb = {8'hFF, oki_dout};
            default:   iEdb = 16'hFFFF;
        endcase
    end

    reg  asn_d;
    wire as_rising  = ASn & (~asn_d);
    wire wr_ack     = (~ASn) & (~asn_d);

    reg irq_pending;
    reg outlatch_stb, okibank_stb, oki_wr_stb;
    reg [7:0] bus_lo;

    reg blit_cyc, blit_stb, blit_d0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            asn_d         <= 1'b1;
            VPAn          <= 1'b1;
            irq_pending   <= 1'b0;
            IPL_n         <= 1'b1;
            vdec_prev_wr  <= 1'b0;
            vdec_prev_woff<= 13'd0;
            vdec_last_enc <= 16'd0;
            vdec_last_dec <= 16'd0;
            pend_woff     <= 13'd0;
            pend_enc      <= 16'd0;
            pend_dec      <= 16'd0;
            pend_vramwr   <= 1'b0;
            outlatch_stb  <= 1'b0;
            okibank_stb   <= 1'b0;
            oki_wr_stb    <= 1'b0;
            blit_cyc      <= 1'b0;
            blit_stb      <= 1'b0;
            blit_d0       <= 1'b0;
        end else begin
            asn_d        <= ASn;
            outlatch_stb <= 1'b0;
            okibank_stb  <= 1'b0;
            oki_wr_stb   <= 1'b0;
            blit_stb     <= 1'b0;

            if (vblank_irq) irq_pending <= 1'b1;
            IPL_n <= ~irq_pending;

            if (~ASn) VPAn <= (fc == 3'd7) ? 1'b0 : 1'b1;
            else      VPAn <= 1'b1;

            if (wr_ack) begin
                if (fc == 3'd7) begin
                    irq_pending <= 1'b0;
                end else if (~rw_rd) begin
                    if (cs_vregs) begin
                        if (uds) vregs[addr[2:1]][15:8] <= oEdb[15:8];
                        if (lds) vregs[addr[2:1]][7:0]  <= oEdb[7:0];
                    end
                    if (cs_clrint)   irq_pending <= 1'b0;
                    if (cs_outlatch) outlatch_stb <= 1'b1;
                    if (cs_okibank)  okibank_stb  <= 1'b1;
                    if (cs_oki)      oki_wr_stb   <= 1'b1;
                    if (cs_blit) begin blit_cyc <= 1'b1; blit_d0 <= oEdb[0]; end
                    bus_lo <= oEdb[7:0];
                end
            end

            if (as_rising) begin
                if (blit_cyc) blit_stb <= 1'b1;
                blit_cyc <= 1'b0;
            end

            if (~ASn) begin
                pend_woff   <= cur_woff;
                pend_enc    <= oEdb;
                pend_dec    <= dec_word;
                pend_vramwr <= (~rw_rd) & (cs_vram | cs_scrram);
            end
            if (as_rising) begin
                if (pend_vramwr) begin
                    vdec_prev_wr   <= 1'b1;
                    vdec_prev_woff <= pend_woff;
                    vdec_last_enc  <= pend_enc;
                    vdec_last_dec  <= pend_dec;
                end else begin
                    vdec_prev_wr <= 1'b0;
                end
            end
        end
    end

    wire        mcu_xrd, mcu_xwr; wire [15:0] mcu_xaddr; wire [7:0] mcu_xdout; wire [7:0] mcu_xdin;
    wire [15:0] mcu_rom_addr; wire mcu_rom_en;
    glass_mcu u_mcu (
        .clk(clk), .rst(rst), .cen(mcu_cen),
        .rom_addr(mcu_rom_addr), .rom_en(mcu_rom_en), .rom_byte(mcurom_data),
        .xdata_rd(mcu_xrd), .xdata_wr(mcu_xwr), .xdata_addr(mcu_xaddr),
        .xdata_dout(mcu_xdout), .xdata_din(mcu_xdin)
    );
    assign mcurom_addr = mcu_rom_addr[14:0];
    assign mcurom_en   = mcu_rom_en;

    wire        mcu_sh    = mcu_xaddr[15];

    wire [12:0] mcu_shidx = mcu_xaddr[13:1];
    wire        mcu_scr   = ~mcu_xaddr[15];

    wire [12:0] shidx = addr[13:1];
    wire        sw_hi = wr_ack & ~rw_rd & cs_shram & uds;
    wire        sw_lo = wr_ack & ~rw_rd & cs_shram & lds;

    wire        mcu_sh_wr_hi = mcu_xwr & mcu_sh & ~mcu_xaddr[0];
    wire        mcu_sh_wr_lo = mcu_xwr & mcu_sh &  mcu_xaddr[0];
    wire [7:0]  shram_hi_q, shram_lo_q;
    wire [7:0]  shram_mcu_hi_q, shram_mcu_lo_q;
    wire [15:0] shram_q = {shram_hi_q, shram_lo_q};
    jtframe_dual_ram #(.AW(13),.DW(8)) u_shram_hi (
        .clk0(clk), .data0(oEdb[15:8]), .addr0(shidx),     .we0(sw_hi),        .q0(shram_hi_q),
        .clk1(clk), .data1(mcu_xdout),  .addr1(mcu_shidx), .we1(mcu_sh_wr_hi), .q1(shram_mcu_hi_q)
    );
    jtframe_dual_ram #(.AW(13),.DW(8)) u_shram_lo (
        .clk0(clk), .data0(oEdb[7:0]),  .addr0(shidx),     .we0(sw_lo),        .q0(shram_lo_q),
        .clk1(clk), .data1(mcu_xdout),  .addr1(mcu_shidx), .we1(mcu_sh_wr_lo), .q1(shram_mcu_lo_q)
    );

    wire [14:0] scridx = mcu_xaddr[14:0];
    wire [7:0]  scratch_q;
    jtframe_dual_ram #(.AW(15),.DW(8),.SIMFILE("dallas.bin")) u_scratch (
        .clk0(clk),        .data0(mcu_xdout),   .addr0(scridx),      .we0(mcu_xwr & mcu_scr), .q0(scratch_q),
        .clk1(scr_dl_clk), .data1(scr_dl_data), .addr1(scr_dl_addr), .we1(scr_dl_we),         .q1()
    );

    assign mcu_xdin = mcu_scr ? scratch_q :
                      (mcu_xaddr[0] ? shram_mcu_lo_q : shram_mcu_hi_q);

    wire [3:0] okibank;
    glass_iolatch u_iolatch (
        .clk(clk), .reset(rst),
        .cs_outlatch(outlatch_stb), .outlatch_a(addr[6:4]), .outlatch_d0(bus_lo[0]),
        .outlatch(),
        .cs_okibank(okibank_stb), .okibank_in(bus_lo[3:0]), .okibank(okibank),
        .flip_screen(flip_screen)
    );

    glass_blitter u_blitter (
        .clk(clk), .rst(rst),
        .stb(blit_stb), .d0(blit_d0),
        .blit_base(blit_base), .blit_active(blit_active)
    );

    wire [7:0] oki_dout;
    glass_oki u_oki (
        .clk(clk), .rst(rst), .cen(oki_cen),
        .cs_oki(oki_wr_stb), .rwn(1'b0), .din(bus_lo), .dout(oki_dout),
        .okibank(okibank),
        .sample_addr(oki_rom_addr), .sample_data(oki_rom_data), .sample_ok(oki_rom_ok),
        .sound(sound), .sample_tick(snd_sample)
    );

    localparam [15:0] T_SAT16 = 16'hFFFF;
    reg [14:0] tl_mcu_pcmax = 0, tl_mcu_prev = 0;
    reg [15:0] tl_mcu_fetch = 0, tl_mcuw = 0, tl_mcu_scrw = 0;
    reg [ 7:0] tl_key = 0;
    reg tl_mcuw_prev = 0, tl_scrw_prev = 0;
    wire tl_mcuw_lvl = mcu_xwr & mcu_sh;
    wire tl_scrw_lvl = mcu_xwr & mcu_scr;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tl_mcu_prev<=0; tl_mcu_pcmax<=0; tl_mcu_fetch<=0; tl_mcuw<=0; tl_mcu_scrw<=0; tl_key<=0;
            tl_mcuw_prev<=0; tl_scrw_prev<=0;
        end else begin
            tl_mcu_prev <= mcurom_addr;
            if (mcurom_addr != tl_mcu_prev && tl_mcu_fetch != T_SAT16) tl_mcu_fetch <= tl_mcu_fetch + 1'b1;
            if (mcurom_addr > tl_mcu_pcmax) tl_mcu_pcmax <= mcurom_addr;
            tl_mcuw_prev <= tl_mcuw_lvl;
            if (tl_mcuw_lvl & ~tl_mcuw_prev & (tl_mcuw != T_SAT16)) tl_mcuw <= tl_mcuw + 1'b1;
            tl_scrw_prev <= tl_scrw_lvl;
            if (tl_scrw_lvl & ~tl_scrw_prev & (tl_mcu_scrw != T_SAT16)) tl_mcu_scrw <= tl_mcu_scrw + 1'b1;

            if (sw_hi & (shidx == 13'h0F01)) tl_key <= oEdb[15:8];
        end
    end
    assign dbg_mcu_pcmax = {1'b0, tl_mcu_pcmax};
    assign dbg_mcu_fetch = tl_mcu_fetch;
    assign dbg_mcuw      = tl_mcuw;
    assign dbg_mcu_scrw  = tl_mcu_scrw;
    assign dbg_key       = tl_key;

    reg [14:0] tl_pc_live = 0;
    reg [ 7:0] tl_de04=0, tl_de03=0, tl_de06=0, tl_de07=0, tl_de04_68k=0, tl_de04_mcu=0;
    always @(posedge clk) begin
        tl_pc_live <= mcurom_addr;

        if (sw_hi        & (shidx    ==13'h0F02)) tl_de04 <= oEdb[15:8];
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0F02)) tl_de04 <= mcu_xdout;
        if (sw_lo        & (shidx    ==13'h0F01)) tl_de03 <= oEdb[7:0];
        if (mcu_sh_wr_lo & (mcu_shidx==13'h0F01)) tl_de03 <= mcu_xdout;
        if (sw_hi        & (shidx    ==13'h0F03)) tl_de06 <= oEdb[15:8];
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0F03)) tl_de06 <= mcu_xdout;
        if (sw_lo        & (shidx    ==13'h0F03)) tl_de07 <= oEdb[7:0];
        if (mcu_sh_wr_lo & (mcu_shidx==13'h0F03)) tl_de07 <= mcu_xdout;

        if (cs_shram & rw_rd & uds & (shidx==13'h0F02))                   tl_de04_68k <= shram_hi_q;
        if (mcu_xrd & mcu_sh & ~mcu_xaddr[0] & (mcu_shidx==13'h0F02))     tl_de04_mcu <= shram_mcu_hi_q;
    end
    assign dbg_mcu_pc_live = {1'b0, tl_pc_live};
    assign dbg_de04_live   = tl_de04;
    assign dbg_de04_68k    = tl_de04_68k;
    assign dbg_de04_mcu    = tl_de04_mcu;
    assign dbg_de03_live   = tl_de03;
    assign dbg_de06_live   = tl_de06;
    assign dbg_de07_live   = tl_de07;

    reg [7:0] tl_d6in=0, tl_d6out=0, tl_d7in=0, tl_d7out=0, tl_fc76=0, tl_fc6e=0, tl_fc6f=0;
    reg [15:0] tl_fc78=0;
    always @(posedge clk) begin
        if (sw_hi        & (shidx    ==13'h0F03)) tl_d6in  <= oEdb[15:8];
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0F03)) tl_d6out <= mcu_xdout;
        if (sw_lo        & (shidx    ==13'h0F03)) tl_d7in  <= oEdb[7:0];
        if (mcu_sh_wr_lo & (mcu_shidx==13'h0F03)) tl_d7out <= mcu_xdout;
        if (sw_hi        & (shidx    ==13'h003B)) tl_fc76 <= oEdb[15:8];
        if (sw_hi        & (shidx    ==13'h0037)) tl_fc6e <= oEdb[15:8];
        if (sw_lo        & (shidx    ==13'h0037)) tl_fc6f <= oEdb[7:0];
        if (sw_hi        & (shidx    ==13'h003C)) tl_fc78[15:8] <= oEdb[15:8];
        if (sw_lo        & (shidx    ==13'h003C)) tl_fc78[7:0]  <= oEdb[7:0];
    end
    assign dbg_de06_in=tl_d6in; assign dbg_de06_out=tl_d6out;
    assign dbg_de07_in=tl_d7in; assign dbg_de07_out=tl_d7out;
    assign dbg_fec076=tl_fc76;  assign dbg_fec06e=tl_fc6e;  assign dbg_fec06f=tl_fc6f;
    assign dbg_fec078=tl_fc78;

    reg [7:0] tl_de98=0, tl_de9a=0, tl_c0=0, tl_c2=0, tl_c4=0, tl_c6=0;
    reg [15:0] tl_c070=0;

    reg [7:0] tl_c072=0, tl_c077=0; reg [15:0] tl_c074=0;
    always @(posedge clk) begin
        if (sw_hi        & (shidx    ==13'h0F4C)) tl_de98 <= oEdb[15:8];
        if (sw_hi        & (shidx    ==13'h0F4D)) tl_de9a <= oEdb[15:8];
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0F4D)) tl_de9a <= mcu_xdout;
        if (sw_hi        & (shidx    ==13'h0038)) tl_c070[15:8] <= oEdb[15:8];
        if (sw_lo        & (shidx    ==13'h0038)) tl_c070[7:0]  <= oEdb[7:0];
        if (sw_hi        & (shidx    ==13'h0039)) tl_c072 <= oEdb[15:8];
        if (sw_hi        & (shidx    ==13'h003A)) tl_c074[15:8] <= oEdb[15:8];
        if (sw_lo        & (shidx    ==13'h003A)) tl_c074[7:0]  <= oEdb[7:0];
        if (sw_lo        & (shidx    ==13'h003B)) tl_c077 <= oEdb[7:0];
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0AE0)) tl_c0 <= mcu_xdout;
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0AE1)) tl_c2 <= mcu_xdout;
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0AE2)) tl_c4 <= mcu_xdout;
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0AE3)) tl_c6 <= mcu_xdout;
    end
    assign dbg_fede98=tl_de98; assign dbg_fede9a=tl_de9a; assign dbg_fec070=tl_c070;
    assign dbg_fed5c0=tl_c0; assign dbg_fed5c2=tl_c2; assign dbg_fed5c4=tl_c4; assign dbg_fed5c6=tl_c6;
    assign dbg_fec072=tl_c072; assign dbg_fec074=tl_c074; assign dbg_fec077=tl_c077;

`ifdef SIMULATION

    reg [31:0] dc=0; integer n_iack=0, n_vbl=0, n_irqset=0; reg ip_d=0, asn_dd=1;
    reg [14:0] mcupcmax=0, mcupc_prev=0; integer mcufetch=0, mcuw=0, shw68k=0, mcurd=0;
    reg mcuw_d=0, mcurd_d=0; reg [19:1] pc68kmax=0;

    wire [3:0] cs_id = cs_rom?4'd1 : cs_shram?4'd2 : cs_vram?4'd3 : cs_scrram?4'd4 :
                       cs_pal?4'd5 : cs_spr?4'd6 : cs_vregs?4'd7 : cs_oki?4'd8 :
                       cs_dsw2?4'd9 : cs_dsw1?4'd10 : cs_p1?4'd11 : cs_p2?4'd12 : 4'd0;

    reg sw_hi_idx_d = 0, mcurd_hi_d = 0;
    integer n_hsw = 0;
    wire hs_idx_68k = (shidx == 13'h0F01);
    wire hs_idx_mcu = (mcu_shidx == 13'h0F01) & ~mcu_xaddr[0];
    wire sw_hi_idx  = sw_hi & hs_idx_68k;
    always @(posedge clk) begin
        sw_hi_idx_d <= sw_hi_idx;
        if (sw_hi_idx & ~sw_hi_idx_d) begin
            n_hsw <= n_hsw + 1;
            if (n_hsw < 40)
                $display("HSW 68k W 0xFEDE02 = %02h   prog=%h dc=%0d", oEdb[15:8], {prog_addr,1'b0}, dc);
        end
        mcurd_hi_d <= (mcu_xrd & mcu_sh & hs_idx_mcu);
        if ((mcu_xrd & mcu_sh & hs_idx_mcu) & ~mcurd_hi_d & (shram_mcu_hi_q != 8'h00))
            $display("HSR MCU R 0xDE02 = %02h  <<< NON-ZERO (breakout)  dc=%0d", shram_mcu_hi_q, dc);
    end

    reg pf46e=0, pf3ad2=0, pf3b18=0, pf4a0=0, pf179c=0;
    integer m46e=0, m3ad2=0, m3b18=0, m4a0=0, m179c=0;
    wire pcsR = prog_cs & prog_data_ok;
    wire [19:1] pa = prog_addr;
    always @(posedge clk) begin
        pf46e  <= pcsR & (pa==(20'h0046e>>1));
        pf3ad2 <= pcsR & (pa==(20'h03ad2>>1));
        pf3b18 <= pcsR & (pa==(20'h03b18>>1));
        pf4a0  <= pcsR & (pa==(20'h004a0>>1));
        pf179c <= pcsR & (pa==(20'h0179c>>1));
        if (pcsR & (pa==(20'h0046e>>1)) & ~pf46e)  m46e  <= m46e+1;
        if (pcsR & (pa==(20'h03ad2>>1)) & ~pf3ad2) m3ad2 <= m3ad2+1;
        if (pcsR & (pa==(20'h03b18>>1)) & ~pf3b18) m3b18 <= m3b18+1;
        if (pcsR & (pa==(20'h004a0>>1)) & ~pf4a0)  m4a0  <= m4a0+1;
        if (pcsR & (pa==(20'h0179c>>1)) & ~pf179c) m179c <= m179c+1;
        if (dc[17:0]==0)
            $display("HITOS dc=%0d : reset46e=%0d sub3ad2=%0d go3b18=%0d ret4a0=%0d err179c=%0d", dc, m46e, m3ad2, m3b18, m4a0, m179c);
    end

    reg [255:0] seen = 0;
    wire in_rng = prog_cs & prog_data_ok & (pa >= 19'h230) & (pa <= 19'h252);
    wire [7:0] sidx = pa - 19'h230;
    always @(posedge clk) begin
        if (in_rng & ~seen[sidx]) begin
            seen[sidx] <= 1'b1;
            $display("PROGMAP %05h data=%04h dc=%0d", {pa,1'b0}, prog_data, dc);
        end
    end
    always @(posedge clk) begin
        dc <= dc + 1; asn_dd <= ASn; ip_d <= irq_pending;
        if (vblank_irq)            n_vbl    <= n_vbl + 1;
        if (irq_pending & ~ip_d)   n_irqset <= n_irqset + 1;
        if ((~ASn) & asn_dd & (fc==3'd7)) n_iack <= n_iack + 1;
        if (prog_cs & prog_data_ok & (prog_addr>pc68kmax)) pc68kmax <= prog_addr;

        mcupc_prev <= mcurom_addr;
        if (mcurom_addr != mcupc_prev) mcufetch <= mcufetch + 1;
        if (mcurom_addr > mcupcmax)    mcupcmax <= mcurom_addr;
        mcuw_d <= (mcu_xwr & mcu_sh);
        if ((mcu_xwr & mcu_sh) & ~mcuw_d) mcuw <= mcuw + 1;
        mcurd_d <= (mcu_xrd & mcu_sh);
        if ((mcu_xrd & mcu_sh) & ~mcurd_d) mcurd <= mcurd + 1;
        if ((sw_hi|sw_lo))                shw68k <= shw68k + 1;

        if (dc[17:0]==0) $display("BOOTDBG pc=%h PCmax=%h cs=%0d a=%h iack=%0d vbl=%0d | mcupc=%h mcupcmax=%h fetch=%0d mcuRd=%0d mcuW=%0d shW68k=%0d mcuXa=%h",
                                  {prog_addr,1'b0}, {pc68kmax,1'b0}, cs_id, addr, n_iack, n_vbl,
                                  {1'b0,mcurom_addr}, {1'b0,mcupcmax}, mcufetch, mcurd, mcuw, shw68k, mcu_xaddr);
    end
`endif

endmodule

`default_nettype wire
