`default_nettype none

module wrally_main #(

    parameter MCU_FULLSPEED = 1'b1,

    parameter MCU_STUB = 1'b0
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        game_run,
    input  wire        cpu_cen_phi1,
    input  wire        cpu_cen_phi2,
    input  wire        mcu_cen,
    input  wire        oki_cen,

    input  wire        vblank_irq,

    output wire [19:1] prog_addr,
    output wire        prog_cs,
    input  wire [15:0] prog_data,
    input  wire        prog_data_ok,

    output wire [14:0] mcurom_addr,
    output wire        mcurom_en,
    input  wire [7:0]  mcurom_data,

    output wire [19:0] oki_rom_addr,
    input  wire [7:0]  oki_rom_data,
    input  wire        oki_rom_ok,

    input  wire [15:0] in_dsw,
    input  wire [15:0] in_p1p2,
    input  wire [15:0] in_wheel,
    input  wire [15:0] in_system,

    output wire        flip_screen,
    output wire [13:0] vmem_addr,
    output wire        vmem_uds, vmem_lds,
    output wire        vmem_we,
    output wire        vmem_cs_vram, vmem_cs_pal, vmem_cs_spr,
    output wire [15:0] vmem_vram_wdata,
    output wire [15:0] vmem_io_wdata,
    input  wire [15:0] vmem_vram_rdata,
    input  wire [15:0] vmem_pal_rdata,
    input  wire [15:0] vmem_spr_rdata,
    output wire [15:0] vreg0, vreg1, vreg2, vreg3,

    output wire signed [13:0] sound,
    output wire        snd_sample,

    output wire [15:0] dbg_firma,
    output wire [7:0]  dbg_mcu_act,

    output wire [15:0] dbg_mcu_pc,
    output wire [15:0] dbg_mcu_pcmax,
    output wire [15:0] dbg_mcu_fetch,
    output wire [ 7:0] dbg_rd0, dbg_rd1, dbg_rd2, dbg_rd3,
    output wire [15:0] dbg_mcu_oor,
    output wire [13:0] dbg_mcu_wradr,
    output wire [ 7:0] dbg_mcu_wrby,
    output wire [15:0] dbg_mcu_coll,
    output wire [ 7:0] dbg_1a80_mcu,
    output wire [ 7:0] dbg_1a80_cpu,

    output wire [15:0] dbg_mcu_rdmax,
    output wire [15:0] dbg_mcu_rdadr,
    output wire [ 7:0] dbg_mcu_rdby,
    output wire [15:0] dbg_mcu_nrd,
    output wire [13:0] dbg_68k_wradr,
    output wire [ 7:0] dbg_68k_wrby,
    output wire        dbg_68k_w01,

    output wire [23:0] dbg_68k_fpc,
    output wire [23:0] dbg_68k_dacc,
    output wire [15:0] dbg_68k_flow,
    output wire [15:0] dbg_68k_iack,
    output wire [15:0] dbg_68k_h400,
    output wire [15:0] dbg_68k_exc,

    output wire [ 7:0] dbg_exc_num,
    output wire [23:0] dbg_fault_pc,
    output wire [23:0] dbg_fault_pcl,
    output wire [23:0] dbg_68k_fault1,

    output wire [23:0] dbg_rst_sp,
    output wire [23:0] dbg_rst_pc,
    output wire [23:0] dbg_first_fetch
);

    wire [23:1] eab;
    wire        ASn, LDSn, UDSn, eRWn;
    wire [15:0] oEdb;
    reg  [15:0] iEdb;
    wire        DTACKn;
    reg         VPAn;
    wire        FC0, FC1, FC2;
    reg         IPL2n;
    wire [2:0]  fc = {FC2, FC1, FC0};

    fx68k u_cpu (
        .clk(clk), .HALTn(1'b1),
        .extReset(rst), .pwrUp(rst),
        .enPhi1(cpu_cen), .enPhi2(cpu_cenb),
        .eRWn(eRWn), .ASn(ASn), .LDSn(LDSn), .UDSn(UDSn),
        .E(), .VMAn(), .FC0(FC0), .FC1(FC1), .FC2(FC2),
        .BGn(), .oRESETn(), .oHALTEDn(),
        .DTACKn(DTACKn), .VPAn(VPAn), .BERRn(1'b1),
        .BRn(1'b1), .BGACKn(1'b1),

        .IPL0n(1'b1), .IPL1n(IPL2n), .IPL2n(IPL2n),
        .iEdb(iEdb), .oEdb(oEdb), .eab(eab)
    );

    wire [23:0] addr = {eab, 1'b0};
    wire        uds  = ~UDSn;
    wire        lds  = ~LDSn;
    wire        rw_rd = eRWn;

    wire cs_rom, cs_vram, cs_vregs, cs_clrint, cs_pal, cs_spr,
         cs_dsw, cs_p1p2, cs_wheel, cs_system, cs_outlatch, cs_okibank, cs_oki, cs_wram;
    wrally_addr_decode u_dec (
        .addr(addr), .as(~ASn),
        .cs_rom(cs_rom), .cs_vram(cs_vram), .cs_vregs(cs_vregs), .cs_clrint(cs_clrint),
        .cs_pal(cs_pal), .cs_spr(cs_spr), .cs_dsw(cs_dsw), .cs_p1p2(cs_p1p2),
        .cs_wheel(cs_wheel), .cs_system(cs_system), .cs_outlatch(cs_outlatch),
        .cs_okibank(cs_okibank), .cs_oki(cs_oki), .cs_wram(cs_wram)
    );

    reg [15:0] vregs[0:3];

    reg  [7:0]  mcu_dram [0:255];
    wire [15:0] wram_cpu_q;
    wire [15:0] wram_mcu_q16;
    wire [15:0] wram_cpu_q_raw;
    wire [15:0] wram_mcu_q16_raw;

    assign prog_addr = eab[19:1];
    assign prog_cs   = cs_rom & rw_rd;
    wire [15:0] rom_word = prog_data;

    wire cpu_cen, cpu_cenb;
    wire bus_busy  = cs_rom & rw_rd & ~prog_data_ok;
    wire bus_cs_dt = cs_rom & rw_rd;
    wire dtack_raw;
    wrally_68kdtack #(.W(8)) u_dtack (
        .rst(rst), .clk(clk), .cen_en(game_run),
        .cpu_cen(cpu_cen), .cpu_cenb(cpu_cenb),
        .bus_cs(bus_cs_dt), .bus_busy(bus_busy), .bus_legit(1'b0), .bus_ack(1'b0),
        .ASn(ASn), .DSn({UDSn,LDSn}),
        .num(7'd1), .den(8'd4),
        .wait2(1'b0), .wait3(1'b0),
        .DTACKn(dtack_raw)
    );

    assign DTACKn = (fc == 3'd7) ? 1'b1 : dtack_raw;

`ifdef SIMULATION

    integer dbgc=0; reg started=0, rst_was_high=0;
    always @(posedge clk) begin
        if (rst) rst_was_high <= 1'b1;

        if (!started && rst_was_high && ~rst && cs_rom && rw_rd) started <= 1'b1;
        if (started && dbgc < 60) begin
            $display("T%0d rst=%b ASn=%b fc=%0d cs=%b paddr=%h pok=%b pdata=%h busy=%b buscs=%b draw=%b DTACKn=%b cen=%b",
                     dbgc, rst, ASn, fc, cs_rom&rw_rd, {prog_addr,1'b0}, prog_data_ok, prog_data, bus_busy, bus_cs_dt, dtack_raw, DTACKn, cpu_cen);
            dbgc <= dbgc + 1;
        end
    end
`endif

    assign vreg0 = vregs[0]; assign vreg1 = vregs[1];
    assign vreg2 = vregs[2]; assign vreg3 = vregs[3];

    assign vmem_addr       = addr[13:0];
    assign vmem_uds        = uds;
    assign vmem_lds        = lds;
    assign vmem_cs_vram    = cs_vram;
    assign vmem_cs_pal     = cs_pal;
    assign vmem_cs_spr     = cs_spr;
    assign vmem_we         = wr_ack & ~rw_rd & (cs_vram | cs_pal | cs_spr);
    assign vmem_vram_wdata = dec_word;
    assign vmem_io_wdata   = oEdb;

    wire [15:0] dec_word;
    reg  [15:0] vdec_last_enc, vdec_last_dec;
    reg  [12:0] vdec_prev_woff;
    reg         vdec_prev_wr;

    reg  [12:0] pend_woff;
    reg  [15:0] pend_enc, pend_dec;
    reg         pend_is2nd, pend_vramwr;
    wire [12:0] cur_woff = addr[13:1];
    wire        is2nd = vdec_prev_wr & (vdec_prev_woff == (cur_woff - 13'd1));

    reg         is2nd_lat = 1'b0;
    wrally_vram_decrypt u_decrypt (
        .enc_prev(is2nd ? vdec_last_enc : 16'd0),
        .dec_prev(is2nd ? vdec_last_dec : 16'd0),
        .enc(oEdb),
        .dec(dec_word)
    );
`ifdef SIMULATION

    integer ndec=0;
    always @(posedge clk) if (!rst) begin
        if (wr_ack && cs_vram && ~rw_rd) begin ndec = ndec + 1;
            if (ndec<60) $display("DEC #%0d woff=%h enc=%h is2nd=%b prevwoff=%h prevwr=%b -> dec=%h",
                                  ndec, cur_woff, oEdb, is2nd, vdec_prev_woff, vdec_prev_wr, dec_word); end
    end
`endif

    always @(*) begin
        iEdb = 16'hFFFF;
        case (1'b1)
            cs_rom:   iEdb = rom_word;
            cs_vram:  iEdb = vmem_vram_rdata;
            cs_pal:   iEdb = vmem_pal_rdata;
            cs_spr:   iEdb = vmem_spr_rdata;
            cs_vregs: iEdb = vregs[addr[2:1]];
            cs_wram:  iEdb = wram_cpu_q;
            cs_dsw:   iEdb = in_dsw;
            cs_p1p2:  iEdb = in_p1p2;
            cs_wheel: iEdb = in_wheel;
            cs_system:iEdb = in_system;
            cs_oki:   iEdb = {8'hFF, oki_dout};
            default:  iEdb = 16'hFFFF;
        endcase
    end

    // synthesis translate_off
    reg csp_d=0, cso_d=0;
    always @(posedge clk) begin
        csp_d <= cs_p1p2;
        if (cs_p1p2 & ~csp_d)
            $display("[CTRL rd P1_P2] in_p1p2=%04X  coin1(b6)=%b coin2(b7)=%b start1(b14)=%b  (0=pulsado)",
                     in_p1p2, in_p1p2[6], in_p1p2[7], in_p1p2[14]);
        cso_d <= cs_outlatch;
        if (cs_outlatch & ~cso_d)
            $display("[CTRL wr OUTLATCH] addr=%06X data=%04X  <- el 68k ACTUO sobre la I/O (coin counter/lockout)",
                     {addr,1'b0}, oEdb);
    end
    // synthesis translate_on

    reg asn_d, asn_dd;
    wire as_falling = (~ASn) & asn_d;
    wire as_rising  = ASn & (~asn_d);

    wire wr_ack = (~ASn) & (~asn_d);

    reg irq_pending;

    reg outlatch_stb, okibank_stb, oki_wr_stb;
    reg [7:0] bus_lo;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            asn_d         <= 1'b1;
            asn_dd        <= 1'b1;
            is2nd_lat     <= 1'b0;
            VPAn          <= 1'b1;
            irq_pending   <= 1'b0;
            IPL2n         <= 1'b1;
            vdec_prev_wr  <= 1'b0;
            vdec_prev_woff<= 13'd0;
            vdec_last_enc <= 16'd0;
            vdec_last_dec <= 16'd0;
            pend_woff     <= 13'd0;
            pend_enc      <= 16'd0;
            pend_dec      <= 16'd0;
            pend_is2nd    <= 1'b0;
            pend_vramwr   <= 1'b0;
            outlatch_stb  <= 1'b0;
            okibank_stb   <= 1'b0;
            oki_wr_stb    <= 1'b0;
        end else begin
            asn_d        <= ASn;
            asn_dd       <= asn_d;
            if (as_falling) is2nd_lat <= is2nd;
            outlatch_stb <= 1'b0;
            okibank_stb  <= 1'b0;
            oki_wr_stb   <= 1'b0;

`ifdef DBG_NOIRQ
            if (1'b0) irq_pending <= 1'b1;
`else
            if (vblank_irq) irq_pending <= 1'b1;
`endif
            IPL2n <= ~irq_pending;

            if (~ASn) begin
                if (fc == 3'd7) VPAn <= 1'b0;
                else            VPAn <= 1'b1;
            end else begin
                VPAn <= 1'b1;
            end

            if (wr_ack) begin
                if (fc == 3'd7) begin
                    irq_pending <= 1'b0;
                end else if (~rw_rd) begin
                    if (cs_vregs) begin
                        if (uds) vregs[addr[2:1]][15:8] <= oEdb[15:8];
                        if (lds) vregs[addr[2:1]][7:0]  <= oEdb[7:0];
                    end
                    if (cs_clrint) irq_pending <= 1'b0;
                    if (cs_outlatch) outlatch_stb <= 1'b1;
                    if (cs_okibank)  okibank_stb  <= 1'b1;
                    if (cs_oki)      oki_wr_stb   <= 1'b1;
                    bus_lo <= oEdb[7:0];
                end
            end

            if (~ASn) begin
                pend_woff   <= cur_woff;
                pend_enc    <= oEdb;
                pend_dec    <= dec_word;
                pend_is2nd  <= is2nd;
                pend_vramwr <= (~rw_rd) & cs_vram;
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

    wire [3:0] okibank;
    wrally_iolatch u_iolatch (
        .clk(clk), .reset(rst),
        .cs_outlatch(outlatch_stb), .outlatch_a(addr[6:4]), .outlatch_d0(bus_lo[0]),
        .outlatch(),
        .cs_okibank(okibank_stb), .okibank_in(bus_lo[3:0]), .okibank(okibank),
        .flip_screen(flip_screen)
    );

    wire [7:0] oki_dout;
    wrally_oki u_oki (
        .clk(clk), .rst(rst), .cen(oki_cen),
        .cs_oki(oki_wr_stb), .rwn(1'b0), .din(bus_lo), .dout(oki_dout),
        .okibank(okibank),
        .sample_addr(oki_rom_addr), .sample_data(oki_rom_data), .sample_ok(oki_rom_ok),
        .sound(sound), .sample_tick(snd_sample)
    );

`ifdef SIMULATION

    reg [31:0] dbg_clkn=0; reg vbi_d=0, irqp_d=0, fc7_d=0; reg [18:0] pamax=0;
    integer n_vbi=0, n_irqarm=0, n_iack=0, n_ckrst=0;
    always @(posedge clk) if (!rst) begin
        dbg_clkn <= dbg_clkn + 1;
        vbi_d <= vblank_irq; irqp_d <= irq_pending; fc7_d <= (fc==3'd7);
        if (vblank_irq & ~vbi_d)   begin n_vbi=n_vbi+1;       if(n_vbi<=12)   $display("IRQDBG vblank_irq #%0d clk=%0d", n_vbi, dbg_clkn); end
        if (irq_pending & ~irqp_d) begin n_irqarm=n_irqarm+1; if(n_irqarm<=12)$display("IRQDBG irq_ARM   #%0d clk=%0d", n_irqarm, dbg_clkn); end
        if ((fc==3'd7) & ~fc7_d)   begin n_iack=n_iack+1;     if(n_iack<=20)  $display("IRQDBG IACK(fc7) #%0d clk=%0d pa=%h", n_iack, dbg_clkn, {prog_addr,1'b0}); end

        if (prog_addr > pamax) pamax <= prog_addr;
        if (pamax > 19'h70000 && prog_addr < 19'h800) begin n_ckrst=n_ckrst+1; if(n_ckrst<=12) $display("IRQDBG CKRST #%0d clk=%0d (pamax llego a %h)", n_ckrst, dbg_clkn, {pamax,1'b0}); pamax<=0; end
    end
`endif

    wire        mcu_rom_en, mcu_rd_data, mcu_rd_sfr, mcu_rd_xdata;
    wire        mcu_dbg_work_en, mcu_dbg_rom_wait, mcu_dbg_rd_wait;
    reg  [15:0] mcu_stall_cnt = 16'd0;
    wire [15:0] mcu_rom_addr, mcu_rd_addr, mcu_wr_addr;
    wire        mcu_wr_data, mcu_wr_sfr, mcu_wr_xdata;
    wire [7:0]  mcu_wr_byte;
    reg  [7:0]  mcu_rd_byte;

    assign mcurom_addr = mcu_rom_addr[14:0];

    assign mcurom_en   = mcu_rom_en;

    reg mcurom_vld;
    always @(posedge clk) mcurom_vld <= mcu_rom_en;

    function [7:0] mcu_sfr_read(input [15:0] a);
        case (a[7:0])
            8'h80, 8'h90, 8'hA0, 8'hB0: mcu_sfr_read = 8'hFF;
            default:                    mcu_sfr_read = 8'h00;
        endcase
    endfunction

    wire       mcu_rd_any = mcu_rd_data | mcu_rd_sfr | mcu_rd_xdata;
    reg        mcu_rd_addr0_q;
    always @(posedge clk) mcu_rd_addr0_q <= mcu_rd_addr[0];

    wire [7:0] wram_mcu_q = mcu_rd_addr0_q ? wram_mcu_q16[7:0]
                                           : wram_mcu_q16[15:8];
    reg [7:0] mcu_nonram_q;
    reg       mcu_sel_xdata;
    always @(posedge clk) if (mcu_rd_any) begin
        mcu_sel_xdata <= mcu_rd_xdata & ~mcu_rd_sfr;
        if (mcu_rd_sfr)       mcu_nonram_q <= mcu_sfr_read(mcu_rd_addr);
        else if (mcu_rd_data) mcu_nonram_q <= mcu_dram[mcu_rd_addr[7:0]];
        else                  mcu_nonram_q <= mcurom_data;
    end
    always @(*) mcu_rd_byte = mcu_sel_xdata ? wram_mcu_q : mcu_nonram_q;

    wire        wr68_wram = wr_ack & ~rw_rd & cs_wram & (fc != 3'd7);

    wire       stub_wake = wr68_wram & (addr[13:1]==13'h1A80) & lds & (oEdb[7:0]==8'h01);
    reg [1:0]  stub_st  = 2'd0;
    reg [3:0]  stub_dly = 4'd0;
    reg        stub_we  = 1'b0;
    always @(posedge clk) begin
        stub_we <= 1'b0;
        if (rst) begin stub_st <= 2'd0; stub_dly <= 4'd0; end
        else if (MCU_STUB) case (stub_st)
            2'd0: if (stub_wake) begin stub_dly <= 4'd8; stub_st <= 2'd1; end
            2'd1: if (stub_dly == 4'd0) begin stub_we <= 1'b1; stub_st <= 2'd2; end
                  else stub_dly <= stub_dly - 1'b1;
            2'd2: stub_st <= 2'd0;
        endcase
    end

    wire        mcu_src_we  = MCU_STUB ? stub_we   : mcu_wr_xdata;
    wire [12:0] mcu_src_adr = MCU_STUB ? 13'h1A80  : mcu_wr_addr[13:1];
    wire [15:0] mcu_src_dat = MCU_STUB ? 16'hA53E  : {mcu_wr_byte, mcu_wr_byte};
    wire        mcu_src_whi = MCU_STUB ? 1'b1      : ~mcu_wr_addr[0];
    wire        mcu_src_wlo = MCU_STUB ? 1'b1      :  mcu_wr_addr[0];

    jtframe_dual_ram16 #(.AW(13)) u_wram (
        .clk0 ( clk ),
        .data0( oEdb ),
        .addr0( addr[13:1] ),
        .we0  ( {uds, lds} & {2{wr68_wram}} ),
        .q0   ( wram_cpu_q_raw ),
        .clk1 ( clk ),
        .data1( mcu_src_dat ),
        .addr1( mcu_src_we ? mcu_src_adr : mcu_rd_addr[13:1] ),
        .we1  ( {mcu_src_whi, mcu_src_wlo} & {2{mcu_src_we}} ),
        .q1   ( wram_mcu_q16_raw )
    );

    reg  [12:0] fwd_w68_adr, fwd_mcuw_adr, fwd_cpurd_adr, fwd_mcurd_adr;
    reg  [15:0] fwd_w68_dat, fwd_mcuw_dat;
    reg  [ 1:0] fwd_w68_we,  fwd_mcuw_we;
    reg         fwd_cpu_rd,  fwd_mcu_rd;
    wire [ 1:0] w68_we_now  = {uds, lds} & {2{wr68_wram}};
    wire [ 1:0] mcuw_we_now = {mcu_src_whi, mcu_src_wlo} & {2{mcu_src_we}};
    always @(posedge clk) begin
        fwd_w68_adr   <= addr[13:1];        fwd_w68_dat <= oEdb;        fwd_w68_we  <= w68_we_now;
        fwd_mcuw_adr  <= mcu_src_adr;       fwd_mcuw_dat<= mcu_src_dat; fwd_mcuw_we <= mcuw_we_now;
        fwd_cpurd_adr <= addr[13:1];        fwd_cpu_rd  <= ~(|w68_we_now);
        fwd_mcurd_adr <= mcu_rd_addr[13:1]; fwd_mcu_rd  <= ~mcu_src_we;
    end

    wire mcu_fwd_hit = fwd_mcu_rd & (fwd_w68_adr == fwd_mcurd_adr);
    assign wram_mcu_q16 = {
        (mcu_fwd_hit & fwd_w68_we[1]) ? fwd_w68_dat[15:8] : wram_mcu_q16_raw[15:8],
        (mcu_fwd_hit & fwd_w68_we[0]) ? fwd_w68_dat[ 7:0] : wram_mcu_q16_raw[ 7:0] };

    wire cpu_fwd_hit = fwd_cpu_rd & (fwd_mcuw_adr == fwd_cpurd_adr);
    assign wram_cpu_q = {
        (cpu_fwd_hit & fwd_mcuw_we[1]) ? fwd_mcuw_dat[15:8] : wram_cpu_q_raw[15:8],
        (cpu_fwd_hit & fwd_mcuw_we[0]) ? fwd_mcuw_dat[ 7:0] : wram_cpu_q_raw[ 7:0] };

    reg [7:0] dbg_firma_hi = 8'd0, dbg_firma_lo = 8'd0, dbg_mcu_act_r = 8'd0;
    always @(posedge clk) begin

        if (wr68_wram && addr[13:1]==13'h1A80) begin
            if (uds) dbg_firma_hi <= oEdb[15:8];
            if (lds) dbg_firma_lo <= oEdb[7:0];
        end
        if (mcu_src_we && mcu_src_adr==13'h1A80) begin
            if (mcu_src_whi) dbg_firma_hi <= mcu_src_dat[15:8];
            if (mcu_src_wlo) dbg_firma_lo <= mcu_src_dat[7:0];
        end
        if (mcu_wr_xdata && dbg_mcu_act_r != 8'hFF) dbg_mcu_act_r <= dbg_mcu_act_r + 1'b1;
    end
    assign dbg_firma   = {dbg_firma_hi, dbg_firma_lo};
    assign dbg_mcu_act = dbg_mcu_act_r;

    // synthesis translate_off
    reg dbg_hs_done = 1'b0;
    always @(posedge clk) begin
        if (!dbg_hs_done && dbg_firma == 16'hA53E) begin
            dbg_hs_done <= 1'b1;
            $display("[HANDSHAKE OK] t=%0t  firma wram[0x1A80]=A53E (Coprocessor OK) -- MCU completa el handshake", $time);
        end
    end
    // synthesis translate_on

    reg [15:0] dbg_pcmax_r=0, dbg_oor_r=0, dbg_fetch_r=0, dbg_coll_r=0;
    reg [ 7:0] dbg_rd0_r=0, dbg_rd1_r=0, dbg_rd2_r=0, dbg_rd3_r=0, dbg_wrby_r=0;
    reg [13:0] dbg_wradr_r=0;
    reg [ 7:0] dbg_1a80_mcu_r=0, dbg_1a80_cpu_r=0;
    reg        dbg_w01_r=0;
    reg [14:0] rdaddr_d1=0;
    always @(posedge clk) if (!rst) begin
        if (mcu_rom_en && mcu_rom_addr > dbg_pcmax_r)              dbg_pcmax_r <= mcu_rom_addr;

        if (wr68_wram && addr[13:1]==13'h80)                       dbg_oor_r   <= oEdb;
        if (mcu_rom_en && mcurom_vld && dbg_fetch_r!=16'hFFFF)     dbg_fetch_r <= dbg_fetch_r + 1'b1;

        rdaddr_d1 <= mcu_rom_addr[14:0];
        if (rdaddr_d1==15'd0) dbg_rd0_r <= mcurom_data;
        if (rdaddr_d1==15'd1) dbg_rd1_r <= mcurom_data;
        if (rdaddr_d1==15'd2) dbg_rd2_r <= mcurom_data;
        if (rdaddr_d1==15'd3) dbg_rd3_r <= mcurom_data;

        if (mcu_dbg_work_en)                                mcu_stall_cnt <= 16'd0;
        else if (mcu_stall_cnt != 16'hFFFF)                mcu_stall_cnt <= mcu_stall_cnt + 1'b1;
        if (~mcu_dbg_work_en && mcu_stall_cnt > 16'd2000)
            dbg_coll_r <= { mcu_stall_cnt[15:8], 3'd0, mcu_rd_data, mcu_rd_sfr, mcu_rd_xdata,
                            mcu_dbg_rd_wait, mcu_dbg_rom_wait };
        if (mcu_wr_xdata) begin dbg_wradr_r <= mcu_wr_addr[14:1]; dbg_wrby_r <= mcu_wr_byte; end

        if (mcu_src_we && mcu_src_adr==13'h1A80 && mcu_src_wlo) dbg_1a80_mcu_r <= mcu_src_dat[7:0];
        if (wr68_wram  && addr[13:1]==13'h1A80 && lds)         dbg_1a80_cpu_r <= oEdb[7:0];
        if (wr68_wram  && addr[13:1]==13'h1A80 && lds && oEdb[7:0]==8'h01) dbg_w01_r <= 1'b1;
    end
    assign dbg_mcu_pc    = mcu_rom_addr;
    assign dbg_mcu_pcmax = dbg_pcmax_r;
    assign dbg_mcu_fetch = dbg_fetch_r;
    assign dbg_rd0 = dbg_rd0_r;  assign dbg_rd1 = dbg_rd1_r;  assign dbg_rd2 = dbg_rd2_r;  assign dbg_rd3 = dbg_rd3_r;
    assign dbg_mcu_oor   = dbg_oor_r;
    assign dbg_mcu_wradr = dbg_wradr_r;
    assign dbg_mcu_wrby  = dbg_wrby_r;
    assign dbg_mcu_coll  = dbg_coll_r;
    assign dbg_1a80_mcu  = dbg_1a80_mcu_r;
    assign dbg_1a80_cpu  = dbg_1a80_cpu_r;
    assign dbg_68k_w01   = dbg_w01_r;

    wire [23:0] eab_byte_d = {eab,1'b0};
    reg [23:0] dbg_fpc_r=0, dbg_dacc_r=0;
    reg [15:0] dbg_flow_r=0, dbg_iack_r=0, dbg_h400_r=0, dbg_exc_r=0;
    reg [23:0] dbg_lastcode_r=0, dbg_fault1_r=0;
    reg        dbg_faulted1=0;
    always @(posedge clk) if (!rst) begin
        if (as_falling) begin
            if (fc==3'd2 || fc==3'd6) begin
                dbg_fpc_r <= eab_byte_d;
                if (eab_byte_d>=24'h000600) dbg_lastcode_r <= eab_byte_d;
                if (eab_byte_d>=24'h000040 && eab_byte_d<=24'h000070 && dbg_flow_r!=16'hFFFF) dbg_flow_r<=dbg_flow_r+1'b1;

                if (eab_byte_d==24'h008E0C && dbg_h400_r!=16'hFFFF) dbg_h400_r<=dbg_h400_r+1'b1;
                if (eab_byte_d==24'h00B294 && dbg_exc_r !=16'hFFFF) dbg_exc_r <=dbg_exc_r +1'b1;

                if (eab_byte_d>=24'h000530 && eab_byte_d<=24'h000590 && !dbg_faulted1) begin
                    dbg_fault1_r <= dbg_lastcode_r; dbg_faulted1 <= 1'b1;
                end
            end
            if (fc==3'd1 || fc==3'd5) dbg_dacc_r <= eab_byte_d;
            if (fc==3'd7 && dbg_iack_r!=16'hFFFF) dbg_iack_r <= dbg_iack_r+1'b1;
        end
    end
    assign dbg_68k_fpc=dbg_fpc_r; assign dbg_68k_dacc=dbg_dacc_r; assign dbg_68k_flow=dbg_flow_r;
    assign dbg_68k_iack=dbg_iack_r; assign dbg_68k_h400=dbg_h400_r; assign dbg_68k_exc=dbg_exc_r;
    assign dbg_68k_fault1 = dbg_fault1_r;

    reg [ 7:0] dbg_excn_r=0;
    reg [23:0] dbg_fpc1_r=0, dbg_fpcL_r=0;
    reg dbg_excseen=0, dbg_armpc=0;
    wire excn_valid = (oEdb[15:0]>=16'd2 && oEdb[15:0]<=16'd15);
    always @(posedge clk) if (!rst) begin

        if (wr68_wram && addr[13:1]==13'h26 && excn_valid) begin
            if (!dbg_excseen) dbg_excn_r <= oEdb[7:0];
            dbg_armpc <= 1'b1;
        end

        if (dbg_armpc && wr68_wram && addr[13:1]==13'h24) dbg_fpcL_r[23:16] <= oEdb[7:0];
        if (dbg_armpc && wr68_wram && addr[13:1]==13'h25) begin
            dbg_fpcL_r[15:0] <= oEdb[15:0];
            dbg_armpc <= 1'b0;
            if (!dbg_excseen) begin dbg_fpc1_r <= {dbg_fpcL_r[23:16], oEdb[15:0]}; dbg_excseen <= 1'b1; end
        end
    end
    assign dbg_exc_num=dbg_excn_r; assign dbg_fault_pc=dbg_fpc1_r; assign dbg_fault_pcl=dbg_fpcL_r;

    reg [15:0] rv0=0, rv1=0, rv2=0, rv3=0;
    reg rvg0=0, rvg1=0, rvg2=0, rvg3=0;
    reg [23:0] dbg_ff_r=0; reg dbg_ffg=0;
    always @(posedge clk) if (!rst) begin
        if (prog_cs && prog_data_ok) begin
            if (prog_addr==19'd0 && !rvg0) begin rv0<=prog_data; rvg0<=1'b1; end
            if (prog_addr==19'd1 && !rvg1) begin rv1<=prog_data; rvg1<=1'b1; end
            if (prog_addr==19'd2 && !rvg2) begin rv2<=prog_data; rvg2<=1'b1; end
            if (prog_addr==19'd3 && !rvg3) begin rv3<=prog_data; rvg3<=1'b1; end
        end
        if (as_falling && (fc==3'd2 || fc==3'd6) && !dbg_ffg) begin dbg_ff_r<=eab_byte_d; dbg_ffg<=1'b1; end
    end
    assign dbg_rst_sp    = {rv0[7:0], rv1};
    assign dbg_rst_pc    = {rv2[7:0], rv3};
    assign dbg_first_fetch = dbg_ff_r;

    reg [15:0] dbg_rdmax_r=0, dbg_rdadr_r=0, dbg_nrd_r=0;
    reg [ 7:0] dbg_rdby_r=0, dbg_68wrby_r=0;
    reg [13:0] dbg_68wradr_r=0;
    always @(posedge clk) if (!rst) begin
        if (mcu_rd_xdata) begin
            dbg_rdadr_r <= mcu_rd_addr;

            if (!mcu_rd_addr[15] && mcu_rd_addr > dbg_rdmax_r) dbg_rdmax_r <= mcu_rd_addr;
            if (dbg_nrd_r != 16'hFFFF)       dbg_nrd_r   <= dbg_nrd_r + 1'b1;
        end
        if (mcu_rd_any)  dbg_rdby_r   <= mcu_rd_byte;
        if (wr68_wram) begin dbg_68wradr_r <= addr[13:1]; dbg_68wrby_r <= oEdb[7:0]; end
    end
    assign dbg_mcu_rdmax = dbg_rdmax_r;
    assign dbg_mcu_rdadr = dbg_rdadr_r;
    assign dbg_mcu_rdby  = dbg_rdby_r;
    assign dbg_mcu_nrd   = dbg_nrd_r;
    assign dbg_68k_wradr = dbg_68wradr_r;
    assign dbg_68k_wrby  = dbg_68wrby_r;

    always @(posedge clk) begin
        if (mcu_wr_data)  mcu_dram[mcu_wr_addr[7:0]] <= mcu_wr_byte;
    end

`ifdef SIMULATION
    integer dbg_mwx=0, dbg_mrx=0, dbg_w68=0; reg [31:0] dbg_hbc=0;
    always @(posedge clk) if (!rst) begin
        dbg_hbc <= dbg_hbc + 1;

        if (dbg_hbc>32'd3000000 && mcu_rd_xdata && mcu_rd_addr[13:1]==13'h1A80 && dbg_mrx<30) begin dbg_mrx=dbg_mrx+1;
            $display("MCUrdWK #%0d xaddr=%h byte=%h | mcu_lo[1A80]=%h cpu_lo[1A80]=%h", dbg_mrx,
                     mcu_rd_addr, mcu_rd_byte, dbg_1a80_mcu_r, dbg_1a80_cpu_r); end

        if (mcu_wr_xdata && dbg_mwx<40) begin dbg_mwx=dbg_mwx+1;
            $display("MCUwr #%0d xaddr=%h word=%h byte=%h", dbg_mwx, mcu_wr_addr, mcu_wr_addr[13:1], mcu_wr_byte); end
        if (dbg_hbc[20:0]==21'd0)
            $display("MCUPC hbc=%0d rom_addr=%h mcuact=%0d firma=%h mcu_lo1A80=%h cpu_lo1A80=%h", dbg_hbc,
                     mcu_rom_addr, dbg_mcu_act_r, {dbg_firma_hi,dbg_firma_lo}, dbg_1a80_mcu_r, dbg_1a80_cpu_r); end

    integer dbg_rdn=0; reg [15:0] dbg_lastpc=0;
    always @(posedge clk) if (!rst && mcu_rd_xdata && dbg_rdn<300) begin
        dbg_rdn = dbg_rdn+1;
        $display("MCURD #%0d pc=%h xrd[%h]=%h | 1A80 mcu=%h cpu=%h | firma=%h", dbg_rdn,
                 mcu_rom_addr, mcu_rd_addr, mcu_rd_byte, dbg_1a80_mcu_r, dbg_1a80_cpu_r,
                 {dbg_firma_hi,dbg_firma_lo});
    end

    integer dbg_w68n=0;
    always @(posedge clk) if (!rst && wr68_wram && dbg_w68n<200) begin
        dbg_w68n = dbg_w68n+1;
        $display("W68 #%0d t=%0d wram[%h] u=%b l=%b dat=%h | mcuPC=%h mcuRD[%h]", dbg_w68n, dbg_hbc,
                 addr[13:1], uds, lds, oEdb, mcu_rom_addr, mcu_rd_addr);
    end

    integer dbg_w1n=0, dbg_r1n=0;
    always @(posedge clk) if (!rst) begin
        if (wr68_wram && addr[13:1]==13'h1A80 && dbg_w1n<60) begin dbg_w1n=dbg_w1n+1;
            $display("HS68w  #%0d t=%0d wram[1A80] u=%b l=%b dat=%h (low=%h) | mcuPC=%h",
                     dbg_w1n, dbg_hbc, uds, lds, oEdb, oEdb[7:0], mcu_rom_addr); end
        if (mcu_rd_xdata && mcu_rd_addr==16'hF501 && dbg_r1n<60) begin dbg_r1n=dbg_r1n+1;
            $display("HSmcuR #%0d t=%0d MCU lee 0xF501 -> byte=%h | mcuPC=%h", dbg_r1n, dbg_hbc, mcu_rd_byte, mcu_rom_addr); end
    end

    integer dbg_vbl=0, dbg_iack=0, dbg_h400=0, dbg_h2330=0;
    always @(posedge clk) if (!rst) begin
        if (vblank_irq && dbg_vbl<20) begin dbg_vbl=dbg_vbl+1;
            $display("VBL    #%0d t=%0d (vblank_irq) irq_pending=%b IPL2n=%b", dbg_vbl, dbg_hbc, irq_pending, IPL2n); end
        if (~ASn && fc==3'd7 && dbg_iack<20) begin dbg_iack=dbg_iack+1;
            $display("IACK   #%0d t=%0d eab=%06X VPAn=%b DTACKn=%b", dbg_iack, dbg_hbc, {eab,1'b0}, VPAn, DTACKn); end
        if (~ASn && {eab,1'b0}>=24'h400 && {eab,1'b0}<=24'h410 && dbg_h400<20) begin dbg_h400=dbg_h400+1;
            $display("HND400 #%0d t=%0d eab=%06X (handler rte 0x400 = vector MALO)", dbg_h400, dbg_hbc, {eab,1'b0}); end
        if (~ASn && {eab,1'b0}>=24'h2330 && {eab,1'b0}<=24'h2340 && dbg_h2330<20) begin dbg_h2330=dbg_h2330+1;
            $display("HND2330#%0d t=%0d eab=%06X (handler vblank REAL 0x2330 = autovector OK)", dbg_h2330, dbg_hbc, {eab,1'b0}); end
    end
`endif

    reg mcu_ram_rd_vld;
    always @(posedge clk) mcu_ram_rd_vld <= (mcu_rd_data | mcu_rd_sfr | mcu_rd_xdata);

    wire        mcu_cpu_en_w  = MCU_FULLSPEED ? 1'b1 : mcu_cen;
    wire        mcu_rom_vld_w = mcurom_vld;
    wire        mcu_rrd_vld_w = mcu_ram_rd_vld;

    wire [15:0] mc_xdata_addr;
    wrally_mcu #(.DIVCEN(1)) u_mcu (
        .clk(clk), .rst(rst), .cen(mcu_cen),
        .rom_addr(mcu_rom_addr), .rom_en(mcu_rom_en), .rom_byte(mcurom_data),
        .xdata_rd(mcu_rd_xdata), .xdata_wr(mcu_wr_xdata), .xdata_addr(mc_xdata_addr),
        .xdata_dout(mcu_wr_byte), .xdata_din(wram_mcu_q),
        .dbg_work_en(mcu_dbg_work_en)
    );
    assign mcu_rd_addr = mc_xdata_addr;
    assign mcu_wr_addr = mc_xdata_addr;
    assign mcu_rd_data = 1'b0;  assign mcu_rd_sfr = 1'b0;
    assign mcu_wr_data = 1'b0;  assign mcu_wr_sfr = 1'b0;
    assign mcu_dbg_rom_wait = 1'b0;  assign mcu_dbg_rd_wait = 1'b0;

`ifdef SIMULATION

    integer mcudbg=0;
    always @(posedge clk) if(!rst && mcu_cpu_en_w && mcudbg<64) begin
        mcudbg = mcudbg+1;
        $display("R8051cen #%0d romen=%b addr=%h vld=%b byte=%h | rdvld=%b wrxd=%b wradr=%h wrbyte=%h",
            mcudbg, mcu_rom_en, mcu_rom_addr, mcu_rom_vld_w, mcurom_data,
            mcu_rrd_vld_w, mcu_wr_xdata, mcu_wr_addr, mcu_wr_byte);
    end

    reg [15:0] mcrom_a1=16'd0, mcrom_a2=16'd0;
    integer    mcrom_ln=0;
    always @(posedge clk) begin
        mcrom_a1 <= mcu_rom_addr; mcrom_a2 <= mcrom_a1;
        if (!rst && mcrom_ln<300000 && mcu_rom_addr==mcrom_a1 && mcrom_a1!=mcrom_a2) begin
            $display("MCUROM addr=%04x byte=%02x", mcu_rom_addr, mcurom_data);
            mcrom_ln <= mcrom_ln + 1;
        end
    end

    integer mcx_ln=0;
    reg mcrd_d=0, mcwr_d=0;
    always @(posedge clk) begin
        mcrd_d <= mcu_rd_xdata; mcwr_d <= mcu_wr_xdata;
        if (!rst && mcx_ln<4000) begin
            if (mcu_rd_xdata & ~mcrd_d) begin $display("MCUXR addr=%04x din=%02x", mc_xdata_addr, wram_mcu_q); mcx_ln<=mcx_ln+1; end
            if (mcu_wr_xdata & ~mcwr_d) begin $display("MCUXW addr=%04x dout=%02x", mc_xdata_addr, mcu_wr_byte); mcx_ln<=mcx_ln+1; end
        end
    end
`endif

endmodule

`default_nettype wire
