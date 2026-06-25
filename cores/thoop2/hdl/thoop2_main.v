// ============================================================================
//  TH Strikes Back (thoop2, Gaelco 1994) — "PLACA" sintetizable: 68000 (fx68k) + mapa de
//  memoria + protocolo de bus + IRQ6 (vblank) + work RAM + I/O + OKI.
//
//  Hardware Tipo-1 "Rev B" (gaelco/thoop2.cpp) + DS5002FP. A diferencia de thoop:
//   - SIN cifrado de VRAM (vram_w = COMBINE_DATA plano, thoop2.cpp:182) -> sin cadena gaelcrpt.
//   - VRAM ÚNICA de 8KB (2 tilemaps), sin screenram.
//   - work RAM 0xfe0000-0xfe7fff (privada) + 0xfe8000-0xfeffff (COMPARTIDA con el DS5002).
//   - puerto SYSTEM (0x700008) con service/test/btn3.
//
//  FASE actual: SIN el MCU (el DS5002 entra en Fase 5). El bloque 0xfe0000-0xfeffff se trata
//  como work RAM plana de 64KB; la separacion de la ventana compartida + el arbitraje con el
//  mc8051 se añaden en la Fase 5. Sin el MCU el juego no pasara su check de proteccion, pero el
//  68k arranca y escribe VRAM/paleta (objetivo de smoke) y el video se valida por replay (golden).
//
//  Estructura/protocolo de bus tomados de thoop/wrally_main.v (arranque del 68k, DTACK jtframe
//  co-generando los cen).
// ============================================================================
`default_nettype none

module thoop2_main (
    input  wire        clk,            // reloj de la logica del juego (48 MHz)
    input  wire        rst,
    input  wire        oki_cen,        // enable del OKI (~1 MHz)
    input  wire        vblank_irq,     // pulso de vblank -> IRQ6

    // --- ROM de programa del 68000 (1 MB) -> SDRAM ---
    output wire [19:1] prog_addr,      // direccion de WORD
    output wire        prog_cs,
    input  wire [15:0] prog_data,
    input  wire        prog_data_ok,

    // --- ROM de samples del OKI (1 MB) -> SDRAM ---
    output wire [19:0] oki_rom_addr,
    input  wire [7:0]  oki_rom_data,
    input  wire        oki_rom_ok,

    // --- puertos de entrada (ya ensamblados por thoop2_inputs) ---
    input  wire [15:0] in_dsw2, in_dsw1, in_p1, in_p2, in_system,

    // --- puerto CPU hacia thoop2_vmem ---
    output wire        flip_screen,
    output wire [13:0] vmem_addr,        // direccion de BYTE (addr[13:0])
    output wire        vmem_uds, vmem_lds,
    output wire        vmem_we,
    output wire        vmem_cs_vram,     // VRAM 100000-101FFF (plana)
    output wire        vmem_cs_pal,      // paleta 200000-2007FF
    output wire        vmem_cs_spr,      // sprite RAM 440000-440FFF
    output wire [15:0] vmem_io_wdata,    // dato crudo del bus (VRAM/paleta/sprite)
    input  wire [15:0] vmem_vram_rdata,
    input  wire [15:0] vmem_pal_rdata,
    input  wire [15:0] vmem_spr_rdata,
    output wire [15:0] vreg0, vreg1, vreg2, vreg3,

    // --- audio (OKI) ---
    output wire signed [13:0] sound,
    output wire        snd_sample,

    // --- DS5002FP (firmware 32KB en BRAM 'dallas' via PROM) ---
    input  wire        mcu_cen,          // = clk48/4 = 12 MHz (cristal del DS5002)
    output wire [14:0] mcurom_addr,      // PC del MCU (15b -> firmware 32KB)
    output wire        mcurom_en,
    input  wire [ 7:0] mcurom_data       // dato del firmware (1 clk después)
);
    // ===================== fx68k (68000) =====================
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
        // IRQ6 = nivel 6 = {IPL2n,IPL1n,IPL0n}=001 -> IPL0n=1, IPL2n=IPL1n=~irq_pending.
        .IPL0n(1'b1), .IPL1n(IPL_n), .IPL2n(IPL_n),
        .iEdb(iEdb), .oEdb(oEdb), .eab(eab)
    );

    wire [23:0] addr  = {eab, 1'b0};   // direccion de BYTE (A0 lo dan UDS/LDS)
    wire        uds   = ~UDSn;
    wire        lds   = ~LDSn;
    wire        rw_rd = eRWn;           // 1 = lectura

    // ===================== decodificador de direcciones =====================
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

    // ===================== DTACK (jtframe_68kdtack) =====================
    // cens del 68000 CO-GENERADOS con el DTACK (clave para muestrear dato fresco). num=1/den=4 -> 12 MHz.
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
    // En IACK (fc==7) el 68000 usa VPAn (autovector), NO DTACK.
    assign DTACKn = (fc == 3'd7) ? 1'b1 : dtack_raw;

    // ===================== vregs (scroll) =====================
    reg [15:0] vregs[0:3];
    assign vreg0 = vregs[0]; assign vreg1 = vregs[1];
    assign vreg2 = vregs[2]; assign vreg3 = vregs[3];

    // ===================== puerto CPU hacia thoop2_vmem =====================
    assign vmem_addr     = addr[13:0];
    assign vmem_uds      = uds;
    assign vmem_lds      = lds;
    assign vmem_cs_vram  = cs_vram;
    assign vmem_cs_pal   = cs_pal;
    assign vmem_cs_spr   = cs_spr;
    assign vmem_we       = wr_ack & ~rw_rd & (cs_vram | cs_pal | cs_spr);
    assign vmem_io_wdata = oEdb;          // thoop2 NO cifra: VRAM/paleta/sprite con el dato crudo del bus

    // ===================== lectura del bus (iEdb) =====================
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
            cs_shram:  iEdb = (addr[15:0]==16'hff00) ? 16'h55aa : shram_q;  // DIAG: forzar firma DS5002
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

    // ===================== protocolo de bus + IRQ + escrituras =====================
    reg  asn_d;
    wire as_rising  = ASn & (~asn_d);              // fin de ciclo
    wire wr_ack     = (~ASn) & (~asn_d);           // NIVEL: dato valido (clks tardios del ciclo)

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

            if (vblank_irq) irq_pending <= 1'b1;     // vblank -> arma IRQ6
            IPL_n <= ~irq_pending;

            // VPAn: autovector en IACK
            if (~ASn) VPAn <= (fc == 3'd7) ? 1'b0 : 1'b1;
            else      VPAn <= 1'b1;

            // Escrituras de registros / strobes I/O (en el NIVEL: idempotente)
            if (wr_ack) begin
                if (fc == 3'd7) begin
                    irq_pending <= 1'b0;             // se reconocio la IRQ (autovector)
                end else if (~rw_rd) begin
                    if (cs_vregs) begin
                        if (uds) vregs[addr[2:1]][15:8] <= oEdb[15:8];
                        if (lds) vregs[addr[2:1]][7:0]  <= oEdb[7:0];
                    end
                    if (cs_clrint)   irq_pending <= 1'b0;   // irqack_w (CLR INT6)
                    if (cs_outlatch) outlatch_stb <= 1'b1;
                    if (cs_okibank)  okibank_stb  <= 1'b1;
                    if (cs_oki)      oki_wr_stb   <= 1'b1;
                    bus_lo <= oEdb[7:0];
                end
            end
        end
    end

    // ===================== work RAM PRIVADA 0xFE0000-0xFE7FFF (32KB) -> BRAM =====================
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

    // ===================== DS5002FP: mc8051 + RAM COMPARTIDA 0xFE8000 + scratch (clon aligator/WRally) =====
    // Ventana MCU 0x8000-0xffff -> shram (byte BIG-ENDIAN: par=alto/impar=bajo). MOVX <0x8000 -> scratch
    // on-chip. ROM del MCU = firmware (BRAM 'dallas'). cen-gate del handshake DENTRO de thoop2_mcu.
    wire        mcu_xrd, mcu_xwr; wire [15:0] mcu_xaddr; wire [7:0] mcu_xdout; wire [7:0] mcu_xdin;
    wire [15:0] mcu_rom_addr; wire mcu_rom_en;
    thoop2_mcu u_mcu (
        .clk(clk), .rst(rst), .cen(mcu_cen),
        .rom_addr(mcu_rom_addr), .rom_en(mcu_rom_en), .rom_byte(mcurom_data),
        .xdata_rd(mcu_xrd), .xdata_wr(mcu_xwr), .xdata_addr(mcu_xaddr),
        .xdata_dout(mcu_xdout), .xdata_din(mcu_xdin)
    );
    assign mcurom_addr = mcu_rom_addr[14:0];   // firmware 32KB
    assign mcurom_en   = mcu_rom_en;

    wire        mcu_sh    = mcu_xaddr[15];           // 0x8000-0xffff -> shram
    wire [13:0] mcu_shidx = mcu_xaddr[14:1];         // word dentro de la shram
    wire        mcu_scr   = ~mcu_xaddr[15];          // 0x0000-0x7fff -> scratch

    // --- RAM compartida 32KB (dual-port 68k/MCU), byte big-endian ---
    wire [13:0] shidx = addr[14:1];                  // word del 68k dentro de la shram (cs_shram)
    wire        sw_hi = wr_ack & ~rw_rd & cs_shram & uds;
    wire        sw_lo = wr_ack & ~rw_rd & cs_shram & lds;
    wire        mcu_sh_wr_hi = mcu_xwr & mcu_sh & ~mcu_xaddr[0];   // byte alto (par, big-endian)
    wire        mcu_sh_wr_lo = mcu_xwr & mcu_sh &  mcu_xaddr[0];   // byte bajo (impar)
    wire [7:0]  shram_hi_q, shram_lo_q;                            // lectura 68k (hi/lo)
    wire [7:0]  shram_mcu_hi_q, shram_mcu_lo_q;                    // lectura MCU (hi/lo)
    wire [15:0] shram_q = {shram_hi_q, shram_lo_q};
    jtframe_dual_ram #(.AW(14),.DW(8)) u_shram_hi (
        .clk0(clk), .data0(oEdb[15:8]), .addr0(shidx),     .we0(sw_hi),        .q0(shram_hi_q),
        .clk1(clk), .data1(mcu_xdout),  .addr1(mcu_shidx), .we1(mcu_sh_wr_hi), .q1(shram_mcu_hi_q)
    );
    jtframe_dual_ram #(.AW(14),.DW(8)) u_shram_lo (
        .clk0(clk), .data0(oEdb[7:0]),  .addr0(shidx),     .we0(sw_lo),        .q0(shram_lo_q),
        .clk1(clk), .data1(mcu_xdout),  .addr1(mcu_shidx), .we1(mcu_sh_wr_lo), .q1(shram_mcu_lo_q)
    );
    // --- scratch on-chip del MCU (32KB, single-port; port1 sin usar) ---
    wire [14:0] scridx = mcu_xaddr[14:0];
    wire [7:0]  scratch_q;
    jtframe_dual_ram #(.AW(15),.DW(8)) u_scratch (
        .clk0(clk), .data0(mcu_xdout), .addr0(scridx), .we0(mcu_xwr & mcu_scr), .q0(scratch_q),
        .clk1(clk), .data1(8'd0),      .addr1(15'd0),  .we1(1'b0),              .q1()
    );
    // dato leído por el MCU: scratch (<0x8000) o shram (byte alto/bajo según paridad)
    assign mcu_xdin = mcu_scr ? scratch_q :
                      (mcu_xaddr[0] ? shram_mcu_lo_q : shram_mcu_hi_q);

    // ===================== LS259 + banco OKI =====================
    wire [3:0] okibank;
    thoop2_iolatch u_iolatch (
        .clk(clk), .reset(rst),
        .cs_outlatch(outlatch_stb), .outlatch_a(addr[6:4]), .outlatch_d0(bus_lo[0]),
        .outlatch(),
        .cs_okibank(okibank_stb), .okibank_in(bus_lo[3:0]), .okibank(okibank),
        .flip_screen(flip_screen)
    );

    // ===================== OKI MSM6295 (jt6295 via glue) =====================
    wire [7:0] oki_dout;
    thoop2_oki u_oki (
        .clk(clk), .rst(rst), .cen(oki_cen),
        .cs_oki(oki_wr_stb), .rwn(1'b0), .din(bus_lo), .dout(oki_dout),
        .okibank(okibank),
        .sample_addr(oki_rom_addr), .sample_data(oki_rom_data), .sample_ok(oki_rom_ok),
        .sound(sound), .sample_tick(snd_sample)
    );
`ifdef SIMULATION
    // DIAGNOSTICO DS5002: traza escrituras del MCU a la shram + el handshake.
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
    // PC del MCU (firmware) cada cierto tiempo
    reg [31:0] mc=0;
    always @(posedge clk) if (mcu_cen) begin mc<=mc+1; if (mc[14:0]==0) $display("MCUPC rom_addr=%h byte=%h", mcurom_addr, mcurom_data); end
    // 68k accesos a la región del handshake (0xfeff00-0x0f = shram addr[14:0] 0x7f00-0x7f0f)
    reg [9:0] n_hs=0; reg wr_ack_d=0;
    always @(posedge clk) wr_ack_d <= wr_ack;
    // accesos del 68k a 0xfeff00 (la firma que comprueba 0x26ec): R con valor leído, W con valor escrito
    always @(posedge clk) if (wr_ack & ~wr_ack_d & cs_shram & (addr[15:0]==16'hff00) & (n_hs<40)) begin
        n_hs <= n_hs+1;
        $display("FEFF00 68k %s val=%h (shram_q=%h)", rw_rd?"RD":"WR", rw_rd?shram_q:oEdb, shram_q);
    end
    // escrituras del MCU a 0xff00/0xff01 (la firma) — ¿se reescriben tras un clear del 68k?
    reg [9:0] n_sig=0;
    always @(posedge clk) if (mcu_cen & mcu_xwr & mcu_sh & (mcu_xaddr[15:1]==15'h7f80) & (n_sig<20)) begin
        n_sig <= n_sig+1;
        $display("SIG MCU WR xaddr=%h dout=%h", mcu_xaddr, mcu_xdout);
    end
    // PC de fetch de instruccion (fc=110 sup-prog): VENTANA TARDÍA (estado estable, no el boot).
    reg [31:0] n_pc=0, pcdc=0; reg [23:0] last_pc=24'hffffff;
    always @(posedge clk) pcdc <= pcdc+1;
    // max dirección de lectura de DATOS del 68k (fc=101) en ROM = el a0 del checksum. ¿llega a 0x7ffff?
    reg [19:0] maxdrd=0; reg [31:0] ddc=0;
    always @(posedge clk) begin
        ddc<=ddc+1;
        if (wr_ack & ~wr_ack_d & cs_rom & rw_rd & (fc==3'd5) & (addr[19:1]>maxdrd[19:1])) maxdrd<=addr[19:0];
        if (ddc[22:0]==0) $display("MAXDRD a0_max=%05x (checksum hasta 0x7ffff?)", {maxdrd,1'b0});
    end
    wire in_csum = (addr[23:0]>=24'h0026aa) & (addr[23:0]<=24'h0026b1); // bucle interno del checksum
    always @(posedge clk) if (wr_ack & ~wr_ack_d & cs_rom & rw_rd & (fc==3'd6) & (pcdc>32'd20000000) & ~in_csum & (n_pc<120) & (addr!=last_pc)) begin
        n_pc <= n_pc+1; last_pc <= addr;
        $display("LPC %06x", addr);
    end
    // accesos a la wram PRIVADA (stack 0xfe7f80) — ¿funciona?
    reg [9:0] n_wr=0;
    always @(posedge clk) if (wr_ack & ~wr_ack_d & cs_wram & (n_wr<20)) begin
        n_wr <= n_wr+1;
        $display("WRAM %s addr=%h wdata=%h rdata=%h", rw_rd?"RD":"WR", addr[15:0], oEdb, wram_q);
    end

    // DIAGNOSTICO IRQ: ¿la IRQ6 de vblank se ARMA y se TOMA (IACK)?
    reg [31:0] dc=0; integer n_iack=0, n_vbl=0, n_irqset=0; reg ip_d=0, asn_dd=1;
    always @(posedge clk) begin
        dc <= dc + 1; asn_dd <= ASn; ip_d <= irq_pending;
        if (vblank_irq)            n_vbl    <= n_vbl + 1;
        if (irq_pending & ~ip_d)   n_irqset <= n_irqset + 1;
        if ((~ASn) & asn_dd & (fc==3'd7)) n_iack <= n_iack + 1;   // flanco de ciclo IACK
        if (dc[20:0]==0) $display("IRQDBG vbl=%0d irqset=%0d iack=%0d  pc=%h dataacc=%h IPLn=%b",
                                  n_vbl, n_irqset, n_iack, {prog_addr,1'b0}, addr, IPL_n);
    end
    // STATE MACHINE: traza escrituras del 68k a 0xfeb6d4 (variable de estado del juego, = MAME 3->5->6->0)
    always @(posedge clk) if (wr_ack & ~wr_ack_d & ~rw_rd & cs_shram & (addr[15:0]==16'hb6d4)) begin
        $display("STATE feb6d4 <= %h (uds=%b lds=%b) frm=%0d", oEdb, uds, lds, frm);
    end
    // GATE DS5002: escrituras del 68k a 0xfec07d (flag de proteccion: 1=firma OK, 0=FALLO -> path 0x2738)
    always @(posedge clk) if (wr_ack & ~wr_ack_d & ~rw_rd & cs_shram & (addr[15:0]==16'hc07d)) begin
        $display("GATE fec07d <= %h frm=%0d  (lds_byte=%h)", oEdb, frm, oEdb[7:0]);
    end
    // VOLCADO de work RAM en frames clave para DIFF vs MAME (oraculo del DS5002, Fase 5).
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
