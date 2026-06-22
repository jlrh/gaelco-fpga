// ============================================================================
//  Thunder Hoop (Gaelco) — "PLACA" sintetizable: 68000 (fx68k) + mapa de memoria +
//  protocolo de bus + IRQ6 (vblank) + descifrado de VRAM + work RAM 64KB + I/O + OKI.
//
//  Hardware Tipo-1 (gaelco.cpp): NO lleva DS5002/coprocesador (a diferencia de WRally).
//  -> mucho mas simple: sin RAM compartida, sin handshake, sin r8051.
//
//  Estructura/protocolo de bus tomados de wrally_main.v (verificado: arranque del 68k,
//  DTACK jtframe co-generando los cen, cadena de descifrado por offset consecutivo).
//
//  VRAM (videoram + screenram) y screenram se escriben DESCIFRADAS (cadena compartida,
//  igual que el unico m_vramcrypt de MAME). paleta/spriteRAM con el dato crudo del bus.
// ============================================================================
`default_nettype none

module biomtoy_main (
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

    // --- puertos de entrada (ya ensamblados por biomtoy_inputs) ---
    input  wire [15:0] in_dsw2, in_dsw1, in_p1, in_p2,

    // --- puerto CPU hacia biomtoy_vmem ---
    output wire        flip_screen,
    output wire [13:0] vmem_addr,        // direccion de BYTE (addr[13:0])
    output wire        vmem_uds, vmem_lds,
    output wire        vmem_we,
    output wire        vmem_cs_vram,     // videoram 100000-101FFF (descifrada)
    output wire        vmem_cs_scrram,   // screenram 102000-103FFF (descifrada)
    output wire        vmem_cs_pal,      // paleta 200000-2007FF
    output wire        vmem_cs_spr,      // sprite RAM 440000-440FFF
    output wire [15:0] vmem_dec_wdata,   // dato DESCIFRADO (videoram/screenram)
    output wire [15:0] vmem_io_wdata,    // dato crudo del bus (paleta/sprite)
    input  wire [15:0] vmem_vram_rdata,
    input  wire [15:0] vmem_scrram_rdata,
    input  wire [15:0] vmem_pal_rdata,
    input  wire [15:0] vmem_spr_rdata,
    output wire [15:0] vreg0, vreg1, vreg2, vreg3,

    // --- audio (OKI) ---
    output wire signed [13:0] sound,
    output wire        snd_sample
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
    wire cs_rom, cs_vram, cs_scrram, cs_vregs, cs_clrint, cs_pal, cs_spr,
         cs_dsw2, cs_dsw1, cs_p1, cs_p2, cs_outlatch, cs_okibank, cs_oki, cs_wram;
    biomtoy_addr_decode u_dec (
        .addr(addr), .as(~ASn),
        .cs_rom(cs_rom), .cs_vram(cs_vram), .cs_scrram(cs_scrram), .cs_vregs(cs_vregs),
        .cs_clrint(cs_clrint), .cs_pal(cs_pal), .cs_spr(cs_spr),
        .cs_dsw2(cs_dsw2), .cs_dsw1(cs_dsw1), .cs_p1(cs_p1), .cs_p2(cs_p2),
        .cs_outlatch(cs_outlatch), .cs_okibank(cs_okibank), .cs_oki(cs_oki), .cs_wram(cs_wram)
    );

    assign prog_addr = eab[19:1];
    assign prog_cs   = cs_rom & rw_rd;
    wire [15:0] rom_word = prog_data;

    // ===================== DTACK (jtframe_68kdtack) =====================
    // El `wait1` interno da 1 ciclo a bus_busy -> elimina la carrera del `ok` rancio del slot
    // SDRAM. cens del 68000 CO-GENERADOS con el DTACK (clave para muestrear dato fresco).
    // num=1/den=4 -> 12 MHz desde clk=48 MHz.
    wire bus_busy  = cs_rom & rw_rd & ~prog_data_ok;
    wire bus_cs_dt = cs_rom & rw_rd;
    wire dtack_raw;
    biomtoy_68kdtack #(.W(8)) u_dtack (
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

    // ===================== puerto CPU hacia biomtoy_vmem =====================
    assign vmem_addr      = addr[13:0];
    assign vmem_uds       = uds;
    assign vmem_lds       = lds;
    assign vmem_cs_vram   = cs_vram;
    assign vmem_cs_scrram = cs_scrram;
    assign vmem_cs_pal    = cs_pal;
    assign vmem_cs_spr    = cs_spr;
    assign vmem_we        = wr_ack & ~rw_rd & (cs_vram | cs_scrram | cs_pal | cs_spr);
    // BIOMTOY: SIN cifrado de VRAM (usa maniacsq_map -> vram_w PLANO, no vram_encrypted_w como squash/thoop).
    // Se escribe el dato CRUDO del bus (igual que paleta/sprite). El bloque de descifrado de abajo queda
    // INACTIVO (código muerto, se optimiza). Verificado en MAME: gaelco_state::maniacsq sin GAELCO_VRAM_ENCRYPTION.
    assign vmem_dec_wdata = oEdb;          // videoram/screenram CRUDAS (biomtoy no cifra)
    assign vmem_io_wdata  = oEdb;          // paleta/sprite con el dato del bus

    // ===================== descifrado de VRAM (cadena 16/32-bit por BUS) =====================
    // videoram (woff 0x000-0xFFF) y screenram (woff 0x1000-0x1FFF) comparten estado (=un solo
    // m_vramcrypt en MAME). La cadena encadena words consecutivos (move.l/movem); se rompe con
    // cualquier acceso intermedio. is2nd latcheado al inicio del ciclo (estable toda la escritura).
    wire [15:0] dec_word;
    reg  [15:0] vdec_last_enc, vdec_last_dec;
    reg  [12:0] vdec_prev_woff;
    reg         vdec_prev_wr;
    wire [12:0] cur_woff = addr[13:1];
    wire        is2nd = vdec_prev_wr & (vdec_prev_woff == (cur_woff - 13'd1));
    // pend_*: latch de los valores de la escritura DURANTE el ciclo (~ASn, estables) para
    // commitearlos a la cadena en as_rising (FIX igual que WRally: committear los valores VIVOS
    // en as_rising tomaba addr/dato del ciclo SIGUIENTE -> corrompia words alternas del descifrado).
    reg  [12:0] pend_woff;
    reg  [15:0] pend_enc, pend_dec;
    reg         pend_vramwr;
    biomtoy_vram_decrypt u_decrypt (
        .enc_prev(is2nd ? vdec_last_enc : 16'd0),
        .dec_prev(is2nd ? vdec_last_dec : 16'd0),
        .enc(oEdb),
        .dec(dec_word)
    );

    // ===================== lectura del bus (iEdb) =====================
    always @(*) begin
        iEdb = 16'hFFFF;
        case (1'b1)
            cs_rom:    iEdb = rom_word;
            cs_vram:   iEdb = vmem_vram_rdata;     // VRAM se LEE descifrada (almacenada asi)
            cs_scrram: iEdb = vmem_scrram_rdata;
            cs_pal:    iEdb = vmem_pal_rdata;
            cs_spr:    iEdb = vmem_spr_rdata;
            cs_vregs:  iEdb = vregs[addr[2:1]];
            cs_wram:   iEdb = wram_q;
            cs_dsw2:   iEdb = in_dsw2;
            cs_dsw1:   iEdb = in_dsw1;
            cs_p1:     iEdb = in_p1;
            cs_p2:     iEdb = in_p2;
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

            // Cadena de descifrado (= WRally): latchea los candidatos DURANTE el ciclo (~ASn, estables)
            // y commitea los LATCHEADOS en as_rising. Asi vdec_prev_* toma los valores del ciclo que
            // ACABA, no los del siguiente (addr/oEdb ya transicionando) -> sin corrupcion alterna.
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
                    vdec_prev_wr <= 1'b0;            // cualquier otro acceso rompe la cadena
                end
            end
        end
    end

    // ===================== work RAM 64KB (FF0000-FFFFFF) -> BRAM =====================
    // 0x8000 words (32768). 2 lanes de byte (hi/lo), escritura de byte completo, lectura
    // registrada -> infiere block-RAM (mismo patron que biomtoy_vmem).
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

    // ===================== LS259 + banco OKI =====================
    wire [3:0] okibank;
    biomtoy_iolatch u_iolatch (
        .clk(clk), .reset(rst),
        .cs_outlatch(outlatch_stb), .outlatch_a(addr[6:4]), .outlatch_d0(bus_lo[0]),
        .outlatch(),
        .cs_okibank(okibank_stb), .okibank_in(bus_lo[3:0]), .okibank(okibank),
        .flip_screen(flip_screen)
    );

    // ===================== OKI MSM6295 (jt6295 via glue) =====================
    wire [7:0] oki_dout;
    biomtoy_oki u_oki (
        .clk(clk), .rst(rst), .cen(oki_cen),
        .cs_oki(oki_wr_stb), .rwn(1'b0), .din(bus_lo), .dout(oki_dout),
        .okibank(okibank),
        .sample_addr(oki_rom_addr), .sample_data(oki_rom_data), .sample_ok(oki_rom_ok),
        .sound(sound), .sample_tick(snd_sample)
    );
`ifdef SIMULATION
    // DIAGNOSTICO IRQ: ¿la IRQ6 de vblank se ARMA y se TOMA (IACK)? Si iack=0 el bucle principal
    // del 68k espera para siempre el flag que pondria el handler de vblank.
    reg [31:0] dc=0; integer n_iack=0, n_vbl=0, n_irqset=0; reg ip_d=0, asn_dd=1;
    always @(posedge clk) begin
        dc <= dc + 1; asn_dd <= ASn; ip_d <= irq_pending;
        if (vblank_irq)            n_vbl    <= n_vbl + 1;
        if (irq_pending & ~ip_d)   n_irqset <= n_irqset + 1;
        if ((~ASn) & asn_dd & (fc==3'd7)) n_iack <= n_iack + 1;   // flanco de ciclo IACK
        if (dc[20:0]==0) $display("IRQDBG vbl=%0d irqset=%0d iack=%0d  pc=%h dataacc=%h IPLn=%b",
                                  n_vbl, n_irqset, n_iack, {prog_addr,1'b0}, addr, IPL_n);
    end
    // VOLCADO de work RAM en frames clave para DIFF vs MAME (mame_wram_biomtoy_{260,400}.bin).
    reg vbl_e=0; reg [15:0] frm=0; reg dB=0,dC=0;
    always @(posedge clk) begin
        vbl_e <= vblank_irq;
        if (vblank_irq & ~vbl_e) begin
            frm <= frm + 1'b1;
            if (frm==16'd260 && !dB) begin dB<=1'b1; $writememh("our_wram_biomtoy_hi_260.hex",wram_hi); $writememh("our_wram_biomtoy_lo_260.hex",wram_lo); $display("WRAMDUMP biomtoy 260 pc=%h", {prog_addr,1'b0}); end
            if (frm==16'd400 && !dC) begin dC<=1'b1; $writememh("our_wram_biomtoy_hi_400.hex",wram_hi); $writememh("our_wram_biomtoy_lo_400.hex",wram_lo); $display("WRAMDUMP biomtoy 400 DONE pc=%h", {prog_addr,1'b0}); $finish; end
        end
    end
`endif

endmodule

`default_nettype wire
