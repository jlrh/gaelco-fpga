`default_nettype none

module thoop2_main (
    input  wire        clk,
    input  wire        rst,
    input  wire        oki_cen,
    input  wire        vblank_irq,

    output wire [19:1] prog_addr,
    output wire        prog_cs,
    input  wire [15:0] prog_data,
    input  wire        prog_data_ok,

    output wire [19:0] oki_rom_addr,
    input  wire [7:0]  oki_rom_data,
    input  wire        oki_rom_ok,

    input  wire [15:0] in_dsw2, in_dsw1, in_p1, in_p2, in_system,

    output wire        flip_screen,
    output wire [13:0] vmem_addr,
    output wire        vmem_uds, vmem_lds,
    output wire        vmem_we,
    output wire        vmem_cs_vram,
    output wire        vmem_cs_pal,
    output wire        vmem_cs_spr,
    output wire [15:0] vmem_io_wdata,
    input  wire [15:0] vmem_vram_rdata,
    input  wire [15:0] vmem_pal_rdata,
    input  wire [15:0] vmem_spr_rdata,
    output wire [15:0] vreg0, vreg1, vreg2, vreg3,

    output wire signed [13:0] sound,
    output wire        snd_sample,

    input  wire        mcu_cen,
    output wire [14:0] mcurom_addr,
    output wire        mcurom_en,
    input  wire [ 7:0] mcurom_data
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

    wire cs_rom, cs_vram, cs_vregs, cs_clrint, cs_pal, cs_spr,
         cs_dsw2, cs_dsw1, cs_p1, cs_p2, cs_system, cs_outlatch, cs_okibank, cs_oki, cs_wram, cs_shram;
    thoop2_addr_decode u_dec (
        .addr(addr), .as(~ASn),
        .cs_rom(cs_rom), .cs_vram(cs_vram), .cs_vregs(cs_vregs),
        .cs_clrint(cs_clrint), .cs_pal(cs_pal), .cs_spr(cs_spr),
        .cs_dsw2(cs_dsw2), .cs_dsw1(cs_dsw1), .cs_p1(cs_p1), .cs_p2(cs_p2), .cs_system(cs_system),
        .cs_outlatch(cs_outlatch), .cs_okibank(cs_okibank), .cs_oki(cs_oki), .cs_wram(cs_wram), .cs_shram(cs_shram)
    );

    assign prog_addr = eab[19:1];
    assign prog_cs   = cs_rom & rw_rd;
    wire [15:0] rom_word = prog_data;

    wire bus_busy  = cs_rom & rw_rd & ~prog_data_ok;
    wire bus_cs_dt = cs_rom & rw_rd;
    wire dtack_raw;
    thoop2_68kdtack #(.W(8)) u_dtack (
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

    assign vmem_addr     = addr[13:0];
    assign vmem_uds      = uds;
    assign vmem_lds      = lds;
    assign vmem_cs_vram  = cs_vram;
    assign vmem_cs_pal   = cs_pal;
    assign vmem_cs_spr   = cs_spr;
    assign vmem_we       = wr_ack & ~rw_rd & (cs_vram | cs_pal | cs_spr);
    assign vmem_io_wdata = oEdb;

    always @(*) begin
        iEdb = 16'hFFFF;
        case (1'b1)
            cs_rom:    iEdb = rom_word;
            cs_vram:   iEdb = vmem_vram_rdata;
            cs_pal:    iEdb = vmem_pal_rdata;
            cs_spr:    iEdb = vmem_spr_rdata;
            cs_vregs:  iEdb = vregs[addr[2:1]];
            cs_wram:   iEdb = wram_q;
`ifdef THOOP2_FORCESIG
            cs_shram:  iEdb = (addr[15:0]==16'hff00) ? 16'h55aa : shram_q;
`else
            cs_shram:  iEdb = shram_q;
`endif
            cs_dsw2:   iEdb = in_dsw2;
            cs_dsw1:   iEdb = in_dsw1;
            cs_p1:     iEdb = in_p1;
            cs_p2:     iEdb = in_p2;
            cs_system: iEdb = in_system;
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

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            asn_d         <= 1'b1;
            VPAn          <= 1'b1;
            irq_pending   <= 1'b0;
            IPL_n         <= 1'b1;
            outlatch_stb  <= 1'b0;
            okibank_stb   <= 1'b0;
            oki_wr_stb    <= 1'b0;
        end else begin
            asn_d        <= ASn;
            outlatch_stb <= 1'b0;
            okibank_stb  <= 1'b0;
            oki_wr_stb   <= 1'b0;

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
                    bus_lo <= oEdb[7:0];
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

    wire        mcu_xrd, mcu_xwr; wire [15:0] mcu_xaddr; wire [7:0] mcu_xdout; wire [7:0] mcu_xdin;
    wire [15:0] mcu_rom_addr; wire mcu_rom_en;
    thoop2_mcu u_mcu (
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
    jtframe_dual_ram #(.AW(15),.DW(8)) u_scratch (
        .clk0(clk), .data0(mcu_xdout), .addr0(scridx), .we0(mcu_xwr & mcu_scr), .q0(scratch_q),
        .clk1(clk), .data1(8'd0),      .addr1(15'd0),  .we1(1'b0),              .q1()
    );

    assign mcu_xdin = mcu_scr ? scratch_q :
                      (mcu_xaddr[0] ? shram_mcu_lo_q : shram_mcu_hi_q);

    wire [3:0] okibank;
    thoop2_iolatch u_iolatch (
        .clk(clk), .reset(rst),
        .cs_outlatch(outlatch_stb), .outlatch_a(addr[6:4]), .outlatch_d0(bus_lo[0]),
        .outlatch(),
        .cs_okibank(okibank_stb), .okibank_in(bus_lo[3:0]), .okibank(okibank),
        .flip_screen(flip_screen)
    );

    wire [7:0] oki_dout;
    thoop2_oki u_oki (
        .clk(clk), .rst(rst), .cen(oki_cen),
        .cs_oki(oki_wr_stb), .rwn(1'b0), .din(bus_lo), .dout(oki_dout),
        .okibank(okibank),
        .sample_addr(oki_rom_addr), .sample_data(oki_rom_data), .sample_ok(oki_rom_ok),
        .sound(sound), .sample_tick(snd_sample)
    );
`ifdef SIMULATION

    integer n_mcuwr=0, n_mcurd=0;
    reg [15:0] last_xaddr=0;
    always @(posedge clk) if (mcu_cen) begin
        if (mcu_xwr) begin
            n_mcuwr <= n_mcuwr+1;
            if (n_mcuwr < 40) $display("MCUWR #%0d xaddr=%h %s dout=%h",
                n_mcuwr, mcu_xaddr, mcu_sh?"SHRAM":"scratch", mcu_xdout);
        end
        if (mcu_xrd && n_mcurd<40) begin n_mcurd<=n_mcurd+1;
            $display("MCURD #%0d xaddr=%h %s din=%h", n_mcurd, mcu_xaddr, mcu_sh?"SHRAM":"scratch", mcu_xdin); end
    end

    reg [31:0] mc=0;
    always @(posedge clk) if (mcu_cen) begin mc<=mc+1; if (mc[14:0]==0) $display("MCUPC rom_addr=%h byte=%h", mcurom_addr, mcurom_data); end

    reg [9:0] n_hs=0; reg wr_ack_d=0;
    always @(posedge clk) wr_ack_d <= wr_ack;

    always @(posedge clk) if (wr_ack & ~wr_ack_d & cs_shram & (addr[15:0]==16'hff00) & (n_hs<40)) begin
        n_hs <= n_hs+1;
        $display("FEFF00 68k %s val=%h (shram_q=%h)", rw_rd?"RD":"WR", rw_rd?shram_q:oEdb, shram_q);
    end

    reg [9:0] n_sig=0;
    always @(posedge clk) if (mcu_cen & mcu_xwr & mcu_sh & (mcu_xaddr[15:1]==15'h7f80) & (n_sig<20)) begin
        n_sig <= n_sig+1;
        $display("SIG MCU WR xaddr=%h dout=%h", mcu_xaddr, mcu_xdout);
    end

    reg [31:0] n_pc=0, pcdc=0; reg [23:0] last_pc=24'hffffff;
    always @(posedge clk) pcdc <= pcdc+1;

    reg [19:0] maxdrd=0; reg [31:0] ddc=0;
    always @(posedge clk) begin
        ddc<=ddc+1;
        if (wr_ack & ~wr_ack_d & cs_rom & rw_rd & (fc==3'd5) & (addr[19:1]>maxdrd[19:1])) maxdrd<=addr[19:0];
        if (ddc[22:0]==0) $display("MAXDRD a0_max=%05x (checksum hasta 0x7ffff?)", {maxdrd,1'b0});
    end
    wire in_csum = (addr[23:0]>=24'h0026aa) & (addr[23:0]<=24'h0026b1);
    always @(posedge clk) if (wr_ack & ~wr_ack_d & cs_rom & rw_rd & (fc==3'd6) & (pcdc>32'd20000000) & ~in_csum & (n_pc<120) & (addr!=last_pc)) begin
        n_pc <= n_pc+1; last_pc <= addr;
        $display("LPC %06x", addr);
    end

    reg [9:0] n_wr=0;
    always @(posedge clk) if (wr_ack & ~wr_ack_d & cs_wram & (n_wr<20)) begin
        n_wr <= n_wr+1;
        $display("WRAM %s addr=%h wdata=%h rdata=%h", rw_rd?"RD":"WR", addr[15:0], oEdb, wram_q);
    end

    reg [31:0] dc=0; integer n_iack=0, n_vbl=0, n_irqset=0; reg ip_d=0, asn_dd=1;
    always @(posedge clk) begin
        dc <= dc + 1; asn_dd <= ASn; ip_d <= irq_pending;
        if (vblank_irq)            n_vbl    <= n_vbl + 1;
        if (irq_pending & ~ip_d)   n_irqset <= n_irqset + 1;
        if ((~ASn) & asn_dd & (fc==3'd7)) n_iack <= n_iack + 1;
        if (dc[20:0]==0) $display("IRQDBG vbl=%0d irqset=%0d iack=%0d  pc=%h dataacc=%h IPLn=%b",
                                  n_vbl, n_irqset, n_iack, {prog_addr,1'b0}, addr, IPL_n);
    end

    always @(posedge clk) if (wr_ack & ~wr_ack_d & ~rw_rd & cs_shram & (addr[15:0]==16'hb6d4)) begin
        $display("STATE feb6d4 <= %h (uds=%b lds=%b) frm=%0d", oEdb, uds, lds, frm);
    end

    always @(posedge clk) if (wr_ack & ~wr_ack_d & ~rw_rd & cs_shram & (addr[15:0]==16'hc07d)) begin
        $display("GATE fec07d <= %h frm=%0d  (lds_byte=%h)", oEdb, frm, oEdb[7:0]);
    end

    reg vbl_e=0; reg [15:0] frm=0; reg dB=0,dC=0;
    integer last_iack=0;
    always @(posedge clk) begin
        vbl_e <= vblank_irq;
        if (vblank_irq & ~vbl_e) begin
            frm <= frm + 1'b1;
            $display("FRM %0d iack=%0d (d_iack=%0d) irqp=%b", frm, n_iack, n_iack-last_iack, irq_pending);
            last_iack <= n_iack;
            if (frm==16'd260 && !dB) begin dB<=1'b1; $writememh("our_wram_thoop2_hi_260.hex",wram_hi); $writememh("our_wram_thoop2_lo_260.hex",wram_lo); $display("WRAMDUMP thoop2 260 pc=%h", {prog_addr,1'b0}); end
            if (frm==16'd400 && !dC) begin dC<=1'b1; $writememh("our_wram_thoop2_hi_400.hex",wram_hi); $writememh("our_wram_thoop2_lo_400.hex",wram_lo); $display("WRAMDUMP thoop2 400 DONE pc=%h", {prog_addr,1'b0}); end
        end
    end
`endif

endmodule

`default_nettype wire
