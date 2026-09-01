`default_nettype none

module bigkarnk_main (
    input  wire        clk,
    input  wire        rst,
    input  wire        vblank_irq,

    output wire [19:1] prog_addr,
    output wire        prog_cs,
    input  wire [15:0] prog_data,
    input  wire        prog_data_ok,

    input  wire [15:0] in_dsw1, in_dsw2, in_p1, in_p2, in_service,

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

    output reg  [7:0]  snd_latch,
    output reg         snd_irq
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
         cs_dsw1, cs_dsw2, cs_p1, cs_p2, cs_service, cs_outlatch, cs_sndlatch, cs_wram;
    bigkarnk_addr_decode u_dec (
        .addr(addr), .as(~ASn),
        .cs_rom(cs_rom), .cs_vram(cs_vram), .cs_scrram(cs_scrram), .cs_vregs(cs_vregs),
        .cs_clrint(cs_clrint), .cs_pal(cs_pal), .cs_spr(cs_spr),
        .cs_dsw1(cs_dsw1), .cs_dsw2(cs_dsw2), .cs_p1(cs_p1), .cs_p2(cs_p2),
        .cs_service(cs_service), .cs_outlatch(cs_outlatch), .cs_sndlatch(cs_sndlatch), .cs_wram(cs_wram)
    );

    assign prog_addr = eab[19:1];
    assign prog_cs   = cs_rom & rw_rd;
    wire [15:0] rom_word = prog_data;

    wire bus_busy  = cs_rom & rw_rd & ~prog_data_ok;
    wire bus_cs_dt = cs_rom & rw_rd;
    wire dtack_raw;
    bigkarnk_68kdtack #(.W(8)) u_dtack (
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

    assign flip_screen = 1'b0;

    always @(*) begin
        iEdb = 16'hFFFF;
        case (1'b1)
            cs_rom:     iEdb = rom_word;
            cs_vram:    iEdb = vmem_vram_rdata;
            cs_scrram:  iEdb = vmem_scrram_rdata;
            cs_pal:     iEdb = vmem_pal_rdata;
            cs_spr:     iEdb = vmem_spr_rdata;
            cs_vregs:   iEdb = vregs[addr[2:1]];
            cs_wram:    iEdb = wram_q;
            cs_dsw1:    iEdb = in_dsw1;
            cs_dsw2:    iEdb = in_dsw2;
            cs_p1:      iEdb = in_p1;
            cs_p2:      iEdb = in_p2;
            cs_service: iEdb = in_service;
            default:    iEdb = 16'hFFFF;
        endcase
    end

    reg  asn_d;
    wire as_rising  = ASn & (~asn_d);
    wire wr_ack     = (~ASn) & (~asn_d);

    reg irq_pending;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            asn_d         <= 1'b1;
            VPAn          <= 1'b1;
            irq_pending   <= 1'b0;
            IPL_n         <= 1'b1;
            snd_latch     <= 8'd0;
            snd_irq       <= 1'b0;
        end else begin
            asn_d   <= ASn;
            snd_irq <= 1'b0;

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

                    if (cs_sndlatch & lds) begin
                        snd_latch <= oEdb[7:0];
                        snd_irq   <= 1'b1;
                    end
                end
            end
        end
    end

    reg [7:0] wram_hi[0:32767], wram_lo[0:32767];
    wire [14:0] wramidx = addr[15:1];
    wire        ww_hi = wr_ack & ~rw_rd & cs_wram & uds;
    wire        ww_lo = wr_ack & ~rw_rd & cs_wram & lds;
    reg  [15:0] wram_q;
    always @(posedge clk) begin
        if (ww_hi) wram_hi[wramidx] <= oEdb[15:8];
        if (ww_lo) wram_lo[wramidx] <= oEdb[7:0];
        wram_q <= {wram_hi[wramidx], wram_lo[wramidx]};
    end

`ifdef SIMULATION

    reg [31:0] dc=0; integer n_iack=0, n_vbl=0, n_irqset=0; reg ip_d=0, asn_dd=1;
    reg [19:1] pcmax=0;
    always @(posedge clk) begin
        dc <= dc + 1; asn_dd <= ASn; ip_d <= irq_pending;
        if (prog_cs & prog_data_ok & (prog_addr>pcmax)) pcmax <= prog_addr;
        if (vblank_irq)            n_vbl    <= n_vbl + 1;
        if (irq_pending & ~ip_d)   n_irqset <= n_irqset + 1;
        if ((~ASn) & asn_dd & (fc==3'd7)) n_iack <= n_iack + 1;
        if (snd_irq) $display("SNDLATCH w=%h pc=%h", snd_latch, {prog_addr,1'b0});
        if (dc[20:0]==0) $display("IRQDBG vbl=%0d irqset=%0d iack=%0d pc=%h PCmax=%h IPLn=%b",
                                  n_vbl, n_irqset, n_iack, {prog_addr,1'b0}, {pcmax,1'b0}, IPL_n);
    end
`endif

endmodule

`default_nettype wire
