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
//  DS5002 ACTIVO (como WRally/aligator): la work RAM del 68k (0xFEC000-0xFEFFFF, 16KB) es la
//  ventana de la shareram (m_shareram). El MCU la ve enmascarada (mcu_hostmem_map:
//  map(0,0xffff).mask(0x3fff)) -> TODO su XDATA = la shareram. Integración del DS5002 CLONADA de
//  aligator_main.v: glass_mcu (mc8051 Oregano /12) + shram dual-port (BYTE_XOR_BE par=alto) +
//  scratch on-chip (MOVX 0x0000-0x7fff = SRAM del firmware 32KB) + routing XDATA por bit15.
//  Glass NO cifra la VRAM (vram_w plano); la cadena de descifrado de abajo queda inactiva.
// ============================================================================
`default_nettype none

module glass_main (
    input  wire        clk,            // reloj de la logica del juego (48 MHz)
    input  wire        rst,
    input  wire        game_run,       // 1 = corre; 0 = PAUSA (congela 68k via cen del dtack)
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

    // --- puertos de entrada (ya ensamblados por glass_inputs) ---
    input  wire [15:0] in_dsw2, in_dsw1, in_p1, in_p2,

    // --- puerto CPU hacia glass_vmem ---
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
    output wire        snd_sample,

    // --- blitter (capa bitmap, lo nuevo de glass) ---
    output wire [19:0] blit_base,
    output wire        blit_active,

    // --- DS5002: firmware (ROM 32KB) servido por BRAM/PROM del game (camino WRally/aligator) ---
    input  wire        mcu_cen,          // = clk48/4 = 12 MHz (cristal del DS5002)
    output wire [14:0] mcurom_addr,      // PC del MCU (15b -> firmware 32KB)
    output wire        mcurom_en,
    input  wire [ 7:0] mcurom_data,      // dato del firmware (1 clk después)

    // --- descarga (RUNTIME, desde la .mra) del SCRATCH on-chip del DS5002 (32KB) ---
    //  Mismo download que el PROM del firmware (dallas_*): el wrapper cablea estas señales a
    //  dallas_waddr/dallas_dd/dallas_we. Permite un .rbf distribuible (sin hornear el firmware).
    input  wire        scr_dl_clk,       // dominio del download (= clk del wrapper)
    input  wire [14:0] scr_dl_addr,      // direccion de byte dentro del scratch 32KB
    input  wire [ 7:0] scr_dl_data,      // byte del firmware
    input  wire        scr_dl_we,        // strobe de escritura del download

    // --- TELEMETRIA DS5002 (HW, sintetizable; la empaqueta jtglass_game por UART) ---
    output wire [15:0] dbg_mcu_pcmax,    // max de mcurom_addr (PC del MCU). 0x1485~poll/handshake
    output wire [15:0] dbg_mcu_fetch,    // counter: mcurom_addr CAMBIA (MCU vivo = fetching firmware)
    output wire [15:0] dbg_mcuw,         // counter: flanco (mcu_xwr & mcu_sh) (MCU escribe shram = heartbeat/respuesta)
    output wire [15:0] dbg_mcu_scrw,     // counter: flanco (mcu_xwr & mcu_scr) (MCU escribe SCRATCH = corre firmware REAL)
    output wire [ 7:0] dbg_key,          // ultimo byte que el 68k escribio en 0xFEDE02 (go-signal: 0x05 fase1 / 0x02 fase2)
    // --- TELEMETRIA v2 (valores VIVOS, diagnostico del cuelgue cmd-1 fin-de-mision) ---
    output wire [15:0] dbg_mcu_pc_live,  // PC ACTUAL del MCU (0x0143-0x0169 = wait/loop del handler cmd-1; 0x1478-80 = idle)
    output wire [ 7:0] dbg_de04_live,    // mem-truth de DE04 (ultimo valor escrito por cualquier puerto)
    output wire [ 7:0] dbg_de04_68k,     // ultimo DE04 LEIDO por el 68k (su puerto de lectura)
    output wire [ 7:0] dbg_de04_mcu,     // ultimo DE04 LEIDO por el MCU (su puerto de lectura)  <- ¿discrepan?
    output wire [ 7:0] dbg_de03_live,    // mem-truth DE03 (ack del MCU: 1=cmd1 en curso)
    output wire [ 7:0] dbg_de06_live,    // mem-truth DE06 (coord/dato del ping-pong)
    output wire [ 7:0] dbg_de07_live,    // mem-truth DE07
    // --- TELEMETRIA v3 (verificar la TRADUCCION del reveal + estado de la state-machine) ---
    output wire [ 7:0] dbg_de06_in,      // 68k escribio en DE06 (ENTRADA de la traduccion)
    output wire [ 7:0] dbg_de06_out,     // MCU escribio en DE06 (SALIDA traducida) -> ¿== fw[0x2004+in]?
    output wire [ 7:0] dbg_de07_in,      // 68k escribio en DE07 (ENTRADA)
    output wire [ 7:0] dbg_de07_out,     // MCU escribio en DE07 (SALIDA) -> ¿== fw[0x2019+in]?
    output wire [ 7:0] dbg_fec076,       // state-machine del reveal (0=fin, 1/2=activo)
    output wire [ 7:0] dbg_fec06e,       // cursor x del reveal
    output wire [ 7:0] dbg_fec06f,       // cursor y del reveal
    output wire [15:0] dbg_fec078,       // contador +3 (si desborda = terminador 0xFFFF de la tabla nunca aparece)
    // --- TELEMETRIA v4 (CAUSA RAIZ: FEC070 = tabla478c[FEDE98]; tabla valida solo 0..3) ---
    output wire [ 7:0] dbg_fede98,       // indice del selector (68k). 0-3 valido; >=4 -> FEC070 basura -> cuelgue
    output wire [ 7:0] dbg_fede9a,       // check en 0x046aa (esperado 0x07)
    output wire [15:0] dbg_fec070,       // contador cargado del reveal (golden MAME=0x46; si enorme -> FEDE98 malo)
    output wire [ 7:0] dbg_fec072,       // FEC072 +1/frame (tope 0x3c). Trayectoria vs golden.
    output wire [15:0] dbg_fec074,       // FEC074 -1/frame. Trayectoria vs golden.
    output wire [ 7:0] dbg_fec077,       // FEC077 sub-contador render (0..0x3b). Trayectoria vs golden.
    output wire [ 7:0] dbg_fed5c0,       // registros que PROVEE el MCU (inputs/estado) -> alimentan FEDE98
    output wire [ 7:0] dbg_fed5c2,       // (0x3cb4 compara nibbles de C2/C4 = check de aborto)
    output wire [ 7:0] dbg_fed5c4,
    output wire [ 7:0] dbg_fed5c6
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

    // ===================== DTACK (jtframe_68kdtack) =====================
    // El `wait1` interno da 1 ciclo a bus_busy -> elimina la carrera del `ok` rancio del slot
    // SDRAM. cens del 68000 CO-GENERADOS con el DTACK (clave para muestrear dato fresco).
    // num=1/den=4 -> 12 MHz desde clk=48 MHz.
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
    // En IACK (fc==7) el 68000 usa VPAn (autovector), NO DTACK.
    assign DTACKn = (fc == 3'd7) ? 1'b1 : dtack_raw;

    // ===================== vregs (scroll) =====================
    reg [15:0] vregs[0:3];
    assign vreg0 = vregs[0]; assign vreg1 = vregs[1];
    assign vreg2 = vregs[2]; assign vreg3 = vregs[3];

    // ===================== puerto CPU hacia glass_vmem =====================
    assign vmem_addr      = addr[13:0];
    assign vmem_uds       = uds;
    assign vmem_lds       = lds;
    assign vmem_cs_vram   = cs_vram;
    assign vmem_cs_scrram = cs_scrram;
    assign vmem_cs_pal    = cs_pal;
    assign vmem_cs_spr    = cs_spr;
    assign vmem_we        = wr_ack & ~rw_rd & (cs_vram | cs_scrram | cs_pal | cs_spr);
    // GLASS: SIN cifrado de VRAM (usa maniacsq_map -> vram_w PLANO, no vram_encrypted_w como squash/thoop).
    // Se escribe el dato CRUDO del bus (igual que paleta/sprite). El bloque de descifrado de abajo queda
    // INACTIVO (código muerto, se optimiza). Verificado en MAME: gaelco_state::maniacsq sin GAELCO_VRAM_ENCRYPTION.
    assign vmem_dec_wdata = oEdb;          // videoram/screenram CRUDAS (glass no cifra)
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
    glass_vram_decrypt u_decrypt (
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
            cs_shram:  iEdb = shram_q;
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
    // BLITTER: 1 escritura a 0x700008 = 1 bit. Necesita 1 SOLO pulso por ciclo de bus (NO el nivel wr_ack,
    // que dispararia varios shifts). Se latchea durante el ciclo y se pulsa al final (as_rising).
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
            blit_stb     <= 1'b0;       // pulso de 1 ciclo

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
                    if (cs_blit) begin blit_cyc <= 1'b1; blit_d0 <= oEdb[0]; end  // marca escritura al blitter
                    bus_lo <= oEdb[7:0];
                end
            end
            // BLITTER: al cerrar el ciclo de bus, 1 pulso si fue una escritura a 0x700008
            if (as_rising) begin
                if (blit_cyc) blit_stb <= 1'b1;
                blit_cyc <= 1'b0;
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

    // ===================== DS5002FP (protección, runtime — camino WRally/aligator) =====================
    //  MOVX (xdata) del MCU: 0x8000-0xffff -> RAM COMPARTIDA con el 68k (shram, byte big-endian);
    //  0x0000-0x7fff -> SRAM scratch on-chip (32KB). El firmware (32KB) lo sirve el game vía PROM.
    wire        mcu_xrd, mcu_xwr; wire [15:0] mcu_xaddr; wire [7:0] mcu_xdout; wire [7:0] mcu_xdin;
    wire [15:0] mcu_rom_addr; wire mcu_rom_en;
    glass_mcu u_mcu (
        .clk(clk), .rst(rst), .cen(mcu_cen),
        .rom_addr(mcu_rom_addr), .rom_en(mcu_rom_en), .rom_byte(mcurom_data),
        .xdata_rd(mcu_xrd), .xdata_wr(mcu_xwr), .xdata_addr(mcu_xaddr),
        .xdata_dout(mcu_xdout), .xdata_din(mcu_xdin)
    );
    assign mcurom_addr = mcu_rom_addr[14:0];   // firmware 32KB
    assign mcurom_en   = mcu_rom_en;

    // decodificación del MOVX
    wire        mcu_sh    = mcu_xaddr[15];           // 0x8000-0xffff -> shram
    // Glass: shram = 16KB (mcu_hostmem_map mask 0x3fff). word index = bits [13:1] de la ventana.
    wire [12:0] mcu_shidx = mcu_xaddr[13:1];         // word dentro de la shram (16KB = 8K words)
    wire        mcu_scr   = ~mcu_xaddr[15];          // 0x0000-0x7fff -> scratch

    // ===================== RAM compartida con DS5002 16KB (FEC000-FEFFFF) -> BRAM TRUE DUAL-PORT =====
    //  Puerto 0 = 68k (word, uds/lds). Puerto 1 = MCU (byte big-endian: par=alto, impar=bajo,
    //  igual que aligator: shareram_w usa big_endian_cast<u8> == BYTE_XOR_BE). jtframe_dual_ram
    //  (2 instancias hi/lo) -> infiere M10K limpio. AW=13 (16KB = 8K words) vs AW=14 de aligator (32KB).
    wire [12:0] shidx = addr[13:1];
    wire        sw_hi = wr_ack & ~rw_rd & cs_shram & uds;
    wire        sw_lo = wr_ack & ~rw_rd & cs_shram & lds;
    // V007 (2026-07-13): REVERTIDO al patron a NIVEL de aligator (validado en HW con handshake DS5002
    //  ACTIVO). El "pulso defensivo" (2026-07-01) y su variante +3clk (V006) NO arreglaron el cuelgue
    //  de la ultima celda del reveal -> descartan el timing/direccion de la ESCRITURA como causa. El
    //  nivel escribe todo el periodo cen_eff (el ultimo clk pilla adrx/dato asentados). Si aun asi
    //  cuelga, el bug NO es la escritura de la shram (mirar la telemetria DE04 68k-vs-MCU = camino B).
    wire        mcu_sh_wr_hi = mcu_xwr & mcu_sh & ~mcu_xaddr[0];   // byte alto (par, big-endian)
    wire        mcu_sh_wr_lo = mcu_xwr & mcu_sh &  mcu_xaddr[0];   // byte bajo (impar)
    wire [7:0]  shram_hi_q, shram_lo_q;                            // lectura 68k (hi/lo)
    wire [7:0]  shram_mcu_hi_q, shram_mcu_lo_q;                    // lectura MCU (hi/lo)
    wire [15:0] shram_q = {shram_hi_q, shram_lo_q};
    jtframe_dual_ram #(.AW(13),.DW(8)) u_shram_hi (
        .clk0(clk), .data0(oEdb[15:8]), .addr0(shidx),     .we0(sw_hi),        .q0(shram_hi_q),
        .clk1(clk), .data1(mcu_xdout),  .addr1(mcu_shidx), .we1(mcu_sh_wr_hi), .q1(shram_mcu_hi_q)
    );
    jtframe_dual_ram #(.AW(13),.DW(8)) u_shram_lo (
        .clk0(clk), .data0(oEdb[7:0]),  .addr0(shidx),     .we0(sw_lo),        .q0(shram_lo_q),
        .clk1(clk), .data1(mcu_xdout),  .addr1(mcu_shidx), .we1(mcu_sh_wr_lo), .q1(shram_mcu_lo_q)
    );

    // ===================== SRAM scratch on-chip del DS5002 32KB (MOVX 0x0000-0x7fff) -> BRAM =========
    //  El firmware lee SUS PROPIAS tablas de datos vía MOVX en xdata 0x10000-0x17fff (la SRAM del
    //  DS5002 = la misma del programa). El Oregano (16b) emite low-16 = offset 0x0000-0x7fff. Si este
    //  scratch fuera zero-init, el firmware leería ceros -> handshake/gameplay roto. Por eso se carga
    //  con la imagen del firmware: en SIM por SIMFILE (dallas.bin); en HW en RUNTIME desde la .mra por
    //  el PUERTO 1 (scr_dl_*), el mismo download que alimenta el PROM (u_prom_dallas). Ver aligator.
    wire [14:0] scridx = mcu_xaddr[14:0];
    wire [7:0]  scratch_q;
    jtframe_dual_ram #(.AW(15),.DW(8),.SIMFILE("dallas.bin")) u_scratch (
        .clk0(clk),        .data0(mcu_xdout),   .addr0(scridx),      .we0(mcu_xwr & mcu_scr), .q0(scratch_q),
        .clk1(scr_dl_clk), .data1(scr_dl_data), .addr1(scr_dl_addr), .we1(scr_dl_we),         .q1()
    );

    // dato leído por el MCU: scratch (<0x8000) o shram (byte alto/bajo según paridad)
    assign mcu_xdin = mcu_scr ? scratch_q :
                      (mcu_xaddr[0] ? shram_mcu_lo_q : shram_mcu_hi_q);

    // ===================== LS259 + banco OKI =====================
    wire [3:0] okibank;
    glass_iolatch u_iolatch (
        .clk(clk), .reset(rst),
        .cs_outlatch(outlatch_stb), .outlatch_a(addr[6:4]), .outlatch_d0(bus_lo[0]),
        .outlatch(),
        .cs_okibank(okibank_stb), .okibank_in(bus_lo[3:0]), .okibank(okibank),
        .flip_screen(flip_screen)
    );

    // ===================== BLITTER (captura del comando serie -> capa bitmap) =====================
    glass_blitter u_blitter (
        .clk(clk), .rst(rst),
        .stb(blit_stb), .d0(blit_d0),
        .blit_base(blit_base), .blit_active(blit_active)
    );

    // ===================== OKI MSM6295 (jt6295 via glue) =====================
    wire [7:0] oki_dout;
    glass_oki u_oki (
        .clk(clk), .rst(rst), .cen(oki_cen),
        .cs_oki(oki_wr_stb), .rwn(1'b0), .din(bus_lo), .dout(oki_dout),
        .okibank(okibank),
        .sample_addr(oki_rom_addr), .sample_data(oki_rom_data), .sample_ok(oki_rom_ok),
        .sound(sound), .sample_tick(snd_sample)
    );
    // ===================== TELEMETRIA DS5002 (SINTETIZABLE -> la empaqueta jtglass_game por UART) =====
    //  Mismos counters que wrally2_main (handshake DS5002 en placa). Saturan a 0xFFFF.
    localparam [15:0] T_SAT16 = 16'hFFFF;
    reg [14:0] tl_mcu_pcmax = 0, tl_mcu_prev = 0;
    reg [15:0] tl_mcu_fetch = 0, tl_mcuw = 0, tl_mcu_scrw = 0;
    reg [ 7:0] tl_key = 0;
    reg tl_mcuw_prev = 0, tl_scrw_prev = 0;
    wire tl_mcuw_lvl = mcu_xwr & mcu_sh;     // MCU escribe shram (responde/heartbeat)
    wire tl_scrw_lvl = mcu_xwr & mcu_scr;    // MCU escribe scratch (corre firmware REAL)
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
            // 68k escribe el go-signal en 0xFEDE02 (byte alto, shidx 0x0F01): latchea el VALOR (0x05 / 0x02)
            if (sw_hi & (shidx == 13'h0F01)) tl_key <= oEdb[15:8];
        end
    end
    assign dbg_mcu_pcmax = {1'b0, tl_mcu_pcmax};
    assign dbg_mcu_fetch = tl_mcu_fetch;
    assign dbg_mcuw      = tl_mcuw;
    assign dbg_mcu_scrw  = tl_mcu_scrw;
    assign dbg_key       = tl_key;

    // ===================== TELEMETRIA v2 (valores VIVOS) — diagnostico del cuelgue cmd-1 =====================
    //  shidx de los bytes del handshake: DE02/03=0x0F01, DE04/05=0x0F02, DE06/07=0x0F03.
    //  mem-truth: latch del ultimo valor escrito a cada byte por CUALQUIER puerto (68k sw_*, MCU mcu_sh_wr_*).
    //  de04_68k/de04_mcu: lo que cada PUERTO leyo por ultima vez de DE04 (para detectar discrepancia de coherencia).
    reg [14:0] tl_pc_live = 0;
    reg [ 7:0] tl_de04=0, tl_de03=0, tl_de06=0, tl_de07=0, tl_de04_68k=0, tl_de04_mcu=0;
    always @(posedge clk) begin
        tl_pc_live <= mcurom_addr;                                   // PC vivo del MCU
        // mem-truth (por paridad de puerto)
        if (sw_hi        & (shidx    ==13'h0F02)) tl_de04 <= oEdb[15:8];
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0F02)) tl_de04 <= mcu_xdout;
        if (sw_lo        & (shidx    ==13'h0F01)) tl_de03 <= oEdb[7:0];
        if (mcu_sh_wr_lo & (mcu_shidx==13'h0F01)) tl_de03 <= mcu_xdout;
        if (sw_hi        & (shidx    ==13'h0F03)) tl_de06 <= oEdb[15:8];
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0F03)) tl_de06 <= mcu_xdout;
        if (sw_lo        & (shidx    ==13'h0F03)) tl_de07 <= oEdb[7:0];
        if (mcu_sh_wr_lo & (mcu_shidx==13'h0F03)) tl_de07 <= mcu_xdout;
        // lo que ve cada puerto al LEER DE04
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

    // ===================== TELEMETRIA v3 — traduccion (entrada 68k vs salida MCU) + estado reveal ==========
    //  DE06/07 = word 0x0F03 (DE06=hi, DE07=lo). state=0xFEC076 (shidx 0x3B hi). cursor x/y=0xFEC06E/6F
    //  (shidx 0x37 hi/lo). contador 0xFEC078 (word, shidx 0x3C). El 68k escribe (sw_*), el MCU (mcu_sh_wr_*).
    reg [7:0] tl_d6in=0, tl_d6out=0, tl_d7in=0, tl_d7out=0, tl_fc76=0, tl_fc6e=0, tl_fc6f=0;
    reg [15:0] tl_fc78=0;
    always @(posedge clk) begin
        if (sw_hi        & (shidx    ==13'h0F03)) tl_d6in  <= oEdb[15:8];   // 68k -> DE06 (entrada)
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0F03)) tl_d6out <= mcu_xdout;    // MCU -> DE06 (salida)
        if (sw_lo        & (shidx    ==13'h0F03)) tl_d7in  <= oEdb[7:0];    // 68k -> DE07 (entrada)
        if (mcu_sh_wr_lo & (mcu_shidx==13'h0F03)) tl_d7out <= mcu_xdout;    // MCU -> DE07 (salida)
        if (sw_hi        & (shidx    ==13'h003B)) tl_fc76 <= oEdb[15:8];    // state
        if (sw_hi        & (shidx    ==13'h0037)) tl_fc6e <= oEdb[15:8];    // cursor x
        if (sw_lo        & (shidx    ==13'h0037)) tl_fc6f <= oEdb[7:0];     // cursor y
        if (sw_hi        & (shidx    ==13'h003C)) tl_fc78[15:8] <= oEdb[15:8];
        if (sw_lo        & (shidx    ==13'h003C)) tl_fc78[7:0]  <= oEdb[7:0];
    end
    assign dbg_de06_in=tl_d6in; assign dbg_de06_out=tl_d6out;
    assign dbg_de07_in=tl_d7in; assign dbg_de07_out=tl_d7out;
    assign dbg_fec076=tl_fc76;  assign dbg_fec06e=tl_fc6e;  assign dbg_fec06f=tl_fc6f;
    assign dbg_fec078=tl_fc78;

    // --- TELEMETRIA v4 (la CAUSA RAIZ): FEC070 = tabla478c[FEDE98], tabla valida solo 0..3 ---
    //  FEDE98 lo escribe el 68k (selector 0x1936-0x1a6c) leyendo FED5C0/C6 que provee el MCU.
    //  shidx = (addr-0xFEC000)>>1.  FEDE98=0xFEDE98->0x0F4C(hi)  FEDE9A=0xFEDE9A->0x0F4D(hi)
    //  FEC070=0xFEC070 word->0x0038(hi/lo)  FED5C0/C2/C4/C6=0xFED5C0..->0x0AE0/AE1/AE2/AE3(hi, MCU).
    reg [7:0] tl_de98=0, tl_de9a=0, tl_c0=0, tl_c2=0, tl_c4=0, tl_c6=0;
    reg [15:0] tl_c070=0;
    // V008: contadores de la trayectoria del reveal (para diffear contra el golden y ver la desincronia).
    //   FEC072 = word 0x39 (hi byte, par); FEC074 = word 0x3A; FEC077 = byte lo de word 0x3B.
    reg [7:0] tl_c072=0, tl_c077=0; reg [15:0] tl_c074=0;
    always @(posedge clk) begin
        if (sw_hi        & (shidx    ==13'h0F4C)) tl_de98 <= oEdb[15:8];        // 68k -> FEDE98
        if (sw_hi        & (shidx    ==13'h0F4D)) tl_de9a <= oEdb[15:8];        // 68k -> FEDE9A
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0F4D)) tl_de9a <= mcu_xdout;         // (o el MCU)
        if (sw_hi        & (shidx    ==13'h0038)) tl_c070[15:8] <= oEdb[15:8];  // 68k -> FEC070 hi
        if (sw_lo        & (shidx    ==13'h0038)) tl_c070[7:0]  <= oEdb[7:0];   // 68k -> FEC070 lo
        if (sw_hi        & (shidx    ==13'h0039)) tl_c072 <= oEdb[15:8];        // 68k -> FEC072 (hi byte)
        if (sw_hi        & (shidx    ==13'h003A)) tl_c074[15:8] <= oEdb[15:8];  // 68k -> FEC074 hi
        if (sw_lo        & (shidx    ==13'h003A)) tl_c074[7:0]  <= oEdb[7:0];   // 68k -> FEC074 lo
        if (sw_lo        & (shidx    ==13'h003B)) tl_c077 <= oEdb[7:0];         // 68k -> FEC077 (lo byte)
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0AE0)) tl_c0 <= mcu_xdout;           // MCU -> FED5C0
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0AE1)) tl_c2 <= mcu_xdout;           // MCU -> FED5C2
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0AE2)) tl_c4 <= mcu_xdout;           // MCU -> FED5C4
        if (mcu_sh_wr_hi & (mcu_shidx==13'h0AE3)) tl_c6 <= mcu_xdout;           // MCU -> FED5C6
    end
    assign dbg_fede98=tl_de98; assign dbg_fede9a=tl_de9a; assign dbg_fec070=tl_c070;
    assign dbg_fed5c0=tl_c0; assign dbg_fed5c2=tl_c2; assign dbg_fed5c4=tl_c4; assign dbg_fed5c6=tl_c6;
    assign dbg_fec072=tl_c072; assign dbg_fec074=tl_c074; assign dbg_fec077=tl_c077;

`ifdef SIMULATION
    // ===================== DIAGNOSTICO BOOT: 68k + IRQ + DS5002 (handshake) =====================
    //  Mira si el handshake 68k<->DS5002 avanza como en aligator/wrally2 (que completan en sim):
    //   - pc68k/PCmax : ¿el 68k arranca y progresa? (sin prog -> ejecuta basura, PC errático)
    //   - mcupc/mcupcmax : ¿el MCU corre el firmware? (PC del MCU cambia = vivo)
    //   - mcufetch : nº de cambios de mcurom_addr (MCU haciendo fetch)
    //   - mcuw : nº de FLANCOS de (mcu_xwr & mcu_sh) (el MCU ESCRIBE la shram = responde al 68k)
    //   - shw68k : nº de escrituras del 68k a la shram (le pasa datos/llave al MCU)
    reg [31:0] dc=0; integer n_iack=0, n_vbl=0, n_irqset=0; reg ip_d=0, asn_dd=1;
    reg [14:0] mcupcmax=0, mcupc_prev=0; integer mcufetch=0, mcuw=0, shw68k=0, mcurd=0;
    reg mcuw_d=0, mcurd_d=0; reg [19:1] pc68kmax=0;
    // ¿qué región accede el 68k? (para ver si está en un wait/clear-loop a la shram o esperando ROM)
    wire [3:0] cs_id = cs_rom?4'd1 : cs_shram?4'd2 : cs_vram?4'd3 : cs_scrram?4'd4 :
                       cs_pal?4'd5 : cs_spr?4'd6 : cs_vregs?4'd7 : cs_oki?4'd8 :
                       cs_dsw2?4'd9 : cs_dsw1?4'd10 : cs_p1?4'd11 : cs_p2?4'd12 : 4'd0;
    // ---- HANDSHAKE BYTE 0xFEDE02 (shidx 0x0F01, byte alto): espejo del tap MAME poll_byte ----
    //  MAME: el 68k escribe 0x05 aquí en pc=3b18 (frame 4) -> el MCU sale del poll de 0xDE02.
    //  HSW = TODA escritura del 68k al byte; HSR = lectura del MCU con valor != 0 (= breakout).
    //  Edge-detect del ciclo de bus para no inflar (wr_ack es nivel).
    reg sw_hi_idx_d = 0, mcurd_hi_d = 0;
    integer n_hsw = 0;
    wire hs_idx_68k = (shidx == 13'h0F01);
    wire hs_idx_mcu = (mcu_shidx == 13'h0F01) & ~mcu_xaddr[0];
    wire sw_hi_idx  = sw_hi & hs_idx_68k;
    always @(posedge clk) begin
        sw_hi_idx_d <= sw_hi_idx;
        if (sw_hi_idx & ~sw_hi_idx_d) begin           // flanco: 1 por ciclo de bus
            n_hsw <= n_hsw + 1;
            if (n_hsw < 40)
                $display("HSW 68k W 0xFEDE02 = %02h   prog=%h dc=%0d", oEdb[15:8], {prog_addr,1'b0}, dc);
        end
        mcurd_hi_d <= (mcu_xrd & mcu_sh & hs_idx_mcu);
        if ((mcu_xrd & mcu_sh & hs_idx_mcu) & ~mcurd_hi_d & (shram_mcu_hi_q != 8'h00))
            $display("HSR MCU R 0xDE02 = %02h  <<< NON-ZERO (breakout)  dc=%0d", shram_mcu_hi_q, dc);
    end

    // ---- HITOS del 68k (¿hasta dónde llega el boot?) -- prog_addr = fetch addr de word ----
    //  0x46e reset entry, 0x3ad2 sub RAM-test+go, 0x3b18 escritura 0x05, 0x4a0 retorno de 0x3ad2,
    //  0x179c rama de error (tst.b 0xDEC5;bne). Edge-detect por fetch.
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

    // ---- PROGRD: ¿qué DATO lee el 68k en runtime en el bsr 0x49c (op 0x6100) y 0x49e (disp 0x3634)? ----
    //  Si difiere de 0x6100/0x3634 -> carrera de lectura del prog en SDRAM (el bsr no salta).
    //  Tambien: ¿el 68k INTENTA buscar 0x3ad2 (pa==0x1d69) aunque prog_data_ok no llegue (hang)?
    //  MAPA de lecturas del boot: primera vez que se lee cada palabra en 0x460..0x4a0, con su dato.
    //  Esperado (de prog_flat.bin): 46e=46fc 472=4279 478=4239 47e=13fc 486=41f9 48c=303c
    //                               490=4298 492=51c8 496=4ff9 49c=6100 49e=3634 4a0=6100
    reg [255:0] seen = 0;       // 1 bit por (pa - 0x230) para dedup (rango 0x460..0x4a0 = pa 0x230..0x250)
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
        if ((~ASn) & asn_dd & (fc==3'd7)) n_iack <= n_iack + 1;   // flanco de ciclo IACK
        if (prog_cs & prog_data_ok & (prog_addr>pc68kmax)) pc68kmax <= prog_addr;
        // DS5002
        mcupc_prev <= mcurom_addr;
        if (mcurom_addr != mcupc_prev) mcufetch <= mcufetch + 1;
        if (mcurom_addr > mcupcmax)    mcupcmax <= mcurom_addr;
        mcuw_d <= (mcu_xwr & mcu_sh);
        if ((mcu_xwr & mcu_sh) & ~mcuw_d) mcuw <= mcuw + 1;        // MCU ESCRIBE shram (responde)
        mcurd_d <= (mcu_xrd & mcu_sh);
        if ((mcu_xrd & mcu_sh) & ~mcurd_d) mcurd <= mcurd + 1;     // MCU LEE shram (lee la llave del 68k)
        if ((sw_hi|sw_lo))                shw68k <= shw68k + 1;
        // DENSO: cada 2^18 clk (~5.5ms@48MHz) para ver el atasco antes del 1er vblank + el MCU vivo.
        if (dc[17:0]==0) $display("BOOTDBG pc=%h PCmax=%h cs=%0d a=%h iack=%0d vbl=%0d | mcupc=%h mcupcmax=%h fetch=%0d mcuRd=%0d mcuW=%0d shW68k=%0d mcuXa=%h",
                                  {prog_addr,1'b0}, {pc68kmax,1'b0}, cs_id, addr, n_iack, n_vbl,
                                  {1'b0,mcurom_addr}, {1'b0,mcupcmax}, mcufetch, mcurd, mcuw, shw68k, mcu_xaddr);
    end
`endif

endmodule

`default_nettype wire
