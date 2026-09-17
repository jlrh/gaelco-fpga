`default_nettype none

module wrally2_main (
    input  wire        clk,
    input  wire        rst,
    input  wire        game_run,
    input  wire        vblank_irq,

    output wire [19:1] prog_addr,
    output wire        prog_cs,
    input  wire [15:0] prog_data,
    input  wire        prog_data_ok,

    input  wire [15:0] in0, in1, in2, in3,
    input  wire [7:0]  paddle0, paddle1,

    output wire        flip_screen,
    output wire [15:0] vmem_addr,
    output wire        vmem_uds, vmem_lds,
    output wire        vmem_we,
    output wire        vmem_cs_vram,
    output wire        vmem_cs_pal,
    output wire [15:0] vmem_wdata,
    input  wire [15:0] vmem_vram_rdata,
    input  wire [15:0] vmem_pal_rdata,

    output wire [15:0] vreg0, vreg1, vreg2,

    output wire        sndreg_cs,
    output wire        sndreg_we,
    input  wire [15:0] snd_rdata,

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
    output wire [ 7:0] dbg_key
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

    wire cs_rom, cs_vram, cs_sound, cs_pal, cs_xram, cs_vregs, cs_in0, cs_in1, cs_in2, cs_in3,
         cs_latch, cs_wram, cs_shram;
    wrally2_addr_decode u_dec (
        .addr(addr), .as(~ASn),
        .cs_rom(cs_rom), .cs_vram(cs_vram), .cs_sound(cs_sound), .cs_pal(cs_pal), .cs_xram(cs_xram),
        .cs_vregs(cs_vregs), .cs_in0(cs_in0), .cs_in1(cs_in1), .cs_in2(cs_in2), .cs_in3(cs_in3),
        .cs_latch(cs_latch), .cs_wram(cs_wram), .cs_shram(cs_shram)
    );

    wire        latch_we = wr_ack & ~rw_rd & cs_latch;
    wire [2:0]  latch_sel = addr[5:3];
    wire        adc1_bit, adc2_bit;
    wrally2_adc u_adc (
        .clk(clk), .rst(rst),
        .latch_we(latch_we), .latch_sel(latch_sel), .latch_dat(oEdb[0]),
        .analog0(paddle0), .analog1(paddle1),
        .adc1_bit(adc1_bit), .adc2_bit(adc2_bit)
    );

    assign prog_addr = eab[19:1];
    assign prog_cs   = cs_rom & rw_rd;
    wire [15:0] rom_word = prog_data;

    wire bus_busy  = cs_rom & rw_rd & ~prog_data_ok;
    wire bus_cs_dt = cs_rom & rw_rd;
    wire dtack_raw;
    wrally2_68kdtack #(.W(8)) u_dtack (
        .rst(rst), .clk(clk), .cen_en(game_run),
        .cpu_cen(cpu_cen), .cpu_cenb(cpu_cenb),
        .bus_cs(bus_cs_dt), .bus_busy(bus_busy), .bus_legit(1'b0), .bus_ack(1'b0),
        .ASn(ASn), .DSn({UDSn,LDSn}),

        .num(7'd13), .den(8'd48),
        .wait2(1'b0), .wait3(1'b0),
        .DTACKn(dtack_raw)
    );

    assign DTACKn = (fc == 3'd7) ? 1'b1 : dtack_raw;

    reg [15:0] vregs[0:7];
    assign vreg0 = vregs[2]; assign vreg1 = vregs[3]; assign vreg2 = vregs[4];

    assign flip_screen = 1'b0;

    assign vmem_addr    = addr[15:0];
    assign vmem_uds     = uds;
    assign vmem_lds     = lds;
    assign vmem_cs_vram = cs_vram;
    assign vmem_cs_pal  = cs_pal;
    assign vmem_we      = wr_ack & ~rw_rd & (cs_vram | cs_pal);
    assign vmem_wdata   = oEdb;

    assign sndreg_cs    = cs_sound;
    assign sndreg_we    = wr_ack & ~rw_rd & cs_sound;

    always @(*) begin
        iEdb = 16'hFFFF;
        case (1'b1)
            cs_rom:   iEdb = rom_word;
            cs_vram:  iEdb = vmem_vram_rdata;
            cs_pal:   iEdb = vmem_pal_rdata;
            cs_xram:  iEdb = xram_q;

            cs_vregs: iEdb = vregs[addr[3:1]];
            cs_in0:   iEdb = {in0[15:7], adc1_bit, in0[5:0]};
            cs_in1:   iEdb = in1;
            cs_in2:   iEdb = {in2[15:7], adc2_bit, in2[5:0]};
            cs_in3:   iEdb = in3;
            cs_wram:  iEdb = wram_q;
            cs_shram: iEdb = shram_q;
            cs_sound: iEdb = snd_rdata;
            default:  iEdb = 16'hFFFF;
        endcase
    end

    reg  asn_d;
    wire wr_ack     = (~ASn) & (~asn_d);

    reg irq_pending;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            asn_d       <= 1'b1;
            VPAn        <= 1'b1;
            irq_pending <= 1'b0;
            IPL_n       <= 1'b1;
        end else begin
            asn_d <= ASn;

            if (vblank_irq) irq_pending <= 1'b1;
            IPL_n <= ~irq_pending;

            if (~ASn) VPAn <= (fc == 3'd7) ? 1'b0 : 1'b1;
            else      VPAn <= 1'b1;

            if (wr_ack) begin
                if (fc == 3'd7) begin
                    irq_pending <= 1'b0;
                end else if (~rw_rd) begin
                    if (cs_vregs) begin
                        if (uds) vregs[addr[3:1]][15:8] <= oEdb[15:8];
                        if (lds) vregs[addr[3:1]][7:0]  <= oEdb[7:0];
                    end

                end
            end
        end
    end

    reg [7:0] wram_hi[0:16383], wram_lo[0:16383];
    wire [13:0] wramidx = addr[14:1];
    wire        ww_hi = wr_ack & ~rw_rd & cs_wram & uds;
    wire        ww_lo = wr_ack & ~rw_rd & cs_wram & lds;
    reg  [15:0] wram_q;
    always @(posedge clk) begin
        if (ww_hi) wram_hi[wramidx] <= oEdb[15:8];
        if (ww_lo) wram_lo[wramidx] <= oEdb[7:0];
        wram_q <= {wram_hi[wramidx], wram_lo[wramidx]};
    end

    reg [7:0] xram_hi[0:4095], xram_lo[0:4095];
    wire [11:0] xramidx = addr[12:1];
    wire        xw_hi = wr_ack & ~rw_rd & cs_xram & uds;
    wire        xw_lo = wr_ack & ~rw_rd & cs_xram & lds;
    reg  [15:0] xram_q;
    always @(posedge clk) begin
        if (xw_hi) xram_hi[xramidx] <= oEdb[15:8];
        if (xw_lo) xram_lo[xramidx] <= oEdb[7:0];
        xram_q <= {xram_hi[xramidx], xram_lo[xramidx]};
    end

    wire        mcu_xrd, mcu_xwr; wire [15:0] mcu_xaddr; wire [7:0] mcu_xdout; wire [7:0] mcu_xdin;
    wire [15:0] mcu_rom_addr; wire mcu_rom_en;
    wrally2_mcu u_mcu (
        .clk(clk), .rst(rst), .cen(mcu_cen),
        .rom_addr(mcu_rom_addr), .rom_en(mcu_rom_en), .rom_byte(mcurom_data),
        .xdata_rd(mcu_xrd), .xdata_wr(mcu_xwr), .xdata_addr(mcu_xaddr),
        .xdata_dout(mcu_xdout), .xdata_din(mcu_xdin)
    );
    assign mcurom_addr = mcu_rom_addr[14:0];
    assign mcurom_en   = mcu_rom_en;

    wire        mcu_sh    = mcu_xaddr[15];
    wire [13:0] mcu_shidx = mcu_xaddr[14:1];
    wire        mcu_scr   = ~mcu_xaddr[15];

    wire [13:0] shidx = addr[14:1];
    wire        sw_hi = wr_ack & ~rw_rd & cs_shram & uds;
    wire        sw_lo = wr_ack & ~rw_rd & cs_shram & lds;
    wire        mcu_sh_wr_hi = mcu_xwr & mcu_sh & ~mcu_xaddr[0];
    wire        mcu_sh_wr_lo = mcu_xwr & mcu_sh &  mcu_xaddr[0];
    wire [7:0]  shram_hi_q, shram_lo_q;
    wire [7:0]  shram_mcu_hi_q, shram_mcu_lo_q;
    wire [15:0] shram_q = {shram_hi_q, shram_lo_q};
    jtframe_dual_ram #(.AW(14),.DW(8)) u_shram_hi (
        .clk0(clk), .data0(oEdb[15:8]), .addr0(shidx),     .we0(sw_hi),        .q0(shram_hi_q),
        .clk1(clk), .data1(mcu_xdout),  .addr1(mcu_shidx), .we1(mcu_sh_wr_hi), .q1(shram_mcu_hi_q)
    );
    jtframe_dual_ram #(.AW(14),.DW(8)) u_shram_lo (
        .clk0(clk), .data0(oEdb[7:0]),  .addr0(shidx),     .we0(sw_lo),        .q0(shram_lo_q),
        .clk1(clk), .data1(mcu_xdout),  .addr1(mcu_shidx), .we1(mcu_sh_wr_lo), .q1(shram_mcu_lo_q)
    );

    wire [14:0] scridx = mcu_xaddr[14:0];
    wire [7:0]  scratch_q;

    jtframe_dual_ram #(.AW(15),.DW(8),.SIMFILE("dallas.bin")) u_scratch (
        .clk0(clk),        .data0(mcu_xdout),   .addr0(scridx),     .we0(mcu_xwr & mcu_scr), .q0(scratch_q),
        .clk1(scr_dl_clk), .data1(scr_dl_data), .addr1(scr_dl_addr), .we1(scr_dl_we),        .q1()
    );

    assign mcu_xdin = mcu_scr ? scratch_q :
                      (mcu_xaddr[0] ? shram_mcu_lo_q : shram_mcu_hi_q);

`ifdef ALI_XTRACE

    integer xr_lo=0, xr_hi=0, xw_lo=0, xw_hi=0, xsmp=0;
    reg xrd_d=0, xwr_d=0;
    always @(posedge clk) begin
        xrd_d <= mcu_xrd; xwr_d <= mcu_xwr;
        if (mcu_xrd & ~xrd_d) begin
            if (mcu_xaddr[15]) xr_hi<=xr_hi+1; else xr_lo<=xr_lo+1;
            if (~mcu_xaddr[15] && xsmp<32) begin
                xsmp<=xsmp+1;
                $display("XTR rd lo [%04x] -> %02x", mcu_xaddr, mcu_xdin);
            end
        end
        if (mcu_xwr & ~xwr_d) begin
            if (mcu_xaddr[15]) xw_hi<=xw_hi+1; else xw_lo<=xw_lo+1;
        end
    end

    reg [23:0] xtc=0;
    always @(posedge clk) begin
        xtc<=xtc+1;
        if (xtc==24'hFFFFFF) $display("XTR HIST  rd lo(0-7fff)=%0d hi(8000-ffff)=%0d  wr lo=%0d hi=%0d", xr_lo, xr_hi, xw_lo, xw_hi);
    end
`endif

    localparam [15:0] T_SAT16 = 16'hFFFF;
    localparam [ 7:0] T_SAT8  = 8'hFF;
    reg [14:0] tl_mcu_prev   = 15'd0;
    reg [14:0] tl_mcu_pcmax  = 15'd0;
    reg [15:0] tl_mcu_fetch  = 16'd0;
    reg [15:0] tl_mcuw       = 16'd0;
    reg [15:0] tl_mcu_scrw   = 16'd0;
    reg [ 7:0] tl_key        = 8'd0;
    reg        tl_mcuw_prev  = 1'b0;
    reg        tl_scrw_prev  = 1'b0;
    reg        tl_key_prev   = 1'b0;
    wire       tl_mcuw_lvl   = mcu_xwr & mcu_sh;
    wire       tl_scrw_lvl   = mcu_xwr & mcu_scr;
    wire       tl_key_lvl    = sw_hi | sw_lo;

    always @(posedge clk) begin
        if (rst) begin
            tl_mcu_prev<=15'd0; tl_mcu_pcmax<=15'd0; tl_mcu_fetch<=16'd0;
            tl_mcuw<=16'd0; tl_mcu_scrw<=16'd0; tl_key<=8'd0;
            tl_mcuw_prev<=1'b0; tl_scrw_prev<=1'b0; tl_key_prev<=1'b0;
        end else begin
            tl_mcu_prev <= mcurom_addr;
            if (mcurom_addr != tl_mcu_prev && tl_mcu_fetch != T_SAT16) tl_mcu_fetch <= tl_mcu_fetch + 1'b1;
            if (mcurom_addr > tl_mcu_pcmax) tl_mcu_pcmax <= mcurom_addr;
            tl_mcuw_prev <= tl_mcuw_lvl;
            if (tl_mcuw_lvl & ~tl_mcuw_prev & (tl_mcuw != T_SAT16)) tl_mcuw <= tl_mcuw + 1'b1;
            tl_scrw_prev <= tl_scrw_lvl;
            if (tl_scrw_lvl & ~tl_scrw_prev & (tl_mcu_scrw != T_SAT16)) tl_mcu_scrw <= tl_mcu_scrw + 1'b1;
            tl_key_prev <= tl_key_lvl;
            if (tl_key_lvl & ~tl_key_prev & (shidx==14'h3e02) & (tl_key != T_SAT8)) tl_key <= tl_key + 1'b1;
        end
    end
    assign dbg_mcu_pcmax = {1'b0, tl_mcu_pcmax};
    assign dbg_mcu_fetch = tl_mcu_fetch;
    assign dbg_mcuw      = tl_mcuw;
    assign dbg_mcu_scrw  = tl_mcu_scrw;
    assign dbg_key       = tl_key;

`ifdef SIMULATION

    reg [31:0] dc=0; integer n_iack=0, n_vbl=0; reg asn_dd=1;
    always @(posedge clk) begin
        dc <= dc + 1; asn_dd <= ASn;
        if (vblank_irq) n_vbl <= n_vbl + 1;
        if ((~ASn) & asn_dd & (fc==3'd7)) n_iack <= n_iack + 1;
        if (dc[20:0]==0) $display("MAINDBG vbl=%0d iack=%0d pc=%h dataacc=%h IPLn=%b vreg=%h,%h,%h",
                                  n_vbl, n_iack, {prog_addr,1'b0}, addr, IPL_n, vregs[2], vregs[3], vregs[4]);
    end
`endif
endmodule

`default_nettype wire
