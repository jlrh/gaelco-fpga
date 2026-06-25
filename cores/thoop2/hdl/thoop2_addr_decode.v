// ============================================================================
//  TH Strikes Back (thoop2) — Decodificador de direcciones del bus del 68000.
//
//  Mapa EXACTO de MAME (src/mame/gaelco/thoop2.cpp thoop2_map:377):
//    000000-0FFFFF  ROM de programa (1 MB)
//    100000-101FFF  VRAM (8 KB, PLANA sin cifrar) -> 2 tilemaps L0/L1
//    108000-108007  vregs (4x u16 scroll)
//    10800C-10800D  irqack / watchdog (CLR INT6)
//    200000-2007FF  paleta (1024 entradas xBGR-555)
//    440000-440FFF  sprite RAM (4 KB)
//    700000 DSW2  700002 DSW1  700004 P1  700006 P2  700008 SYSTEM
//    70000B  LS259 outlatch (select 0x70 -> a[6:4])   70000D OKI bank   70000F OKIM6295
//    FE0000-FE7FFF  work RAM privada (32 KB)
//    FE8000-FEFFFF  work RAM COMPARTIDA con el DS5002 (32 KB)
//
//  NOTA: thoop2 NO tiene screenram (thoop sí) y NO cifra la VRAM. Decodificacion por rango,
//  combinacional pura. El cs_wram cubre TODO 0xFE0000-0xFEFFFF (privada+compartida); la
//  separacion de la compartida con el MCU se hace en la Fase 5 (DS5002).
// ============================================================================
`default_nettype none

module thoop2_addr_decode (
    input  wire [23:0] addr,    // direccion de BYTE del 68000 (A0 implicito por UDS/LDS)
    input  wire        as,      // 1 = ciclo de bus valido (address strobe)

    output wire        cs_rom,      // 000000-0FFFFF  ROM
    output wire        cs_vram,     // 100000-101FFF  VRAM (plana)
    output wire        cs_vregs,    // 108000-108007  registros de video
    output wire        cs_clrint,   // 10800C-10800D  CLR INT6 / watchdog
    output wire        cs_pal,      // 200000-2007FF  paleta
    output wire        cs_spr,      // 440000-440FFF  sprite RAM
    output wire        cs_dsw2,     // 700000-700001  DSW2
    output wire        cs_dsw1,     // 700002-700003  DSW1
    output wire        cs_p1,       // 700004-700005  P1
    output wire        cs_p2,       // 700006-700007  P2
    output wire        cs_system,   // 700008-700009  SYSTEM (service/test/btn3)
    output wire        cs_outlatch, // 70000B         LS259 (coin lockout/counter)
    output wire        cs_okibank,  // 70000D         OKI bankswitch
    output wire        cs_oki,      // 70000F         OKI r/w
    output wire        cs_wram,     // FE0000-FE7FFF  work RAM privada
    output wire        cs_shram     // FE8000-FEFFFF  work RAM COMPARTIDA con el DS5002
);
    assign cs_rom   = as & (addr[23:20] == 4'h0);                          // 000000-0FFFFF
    assign cs_vram  = as & (addr[23:20] == 4'h1) & (addr[19:13] == 7'd0);  // 100000-101FFF
    assign cs_pal   = as & (addr[23:20] == 4'h2) & (addr[19:11] == 9'd0);  // 200000-2007FF
    assign cs_spr   = as & (addr[23:16] == 8'h44) & (addr[15:12] == 4'h0); // 440000-440FFF
    assign cs_wram  = as & (addr[23:16] == 8'hFE) & ~addr[15];             // FE0000-FE7FFF privada
    assign cs_shram = as & (addr[23:16] == 8'hFE) &  addr[15];             // FE8000-FEFFFF compartida

    // Bloque 108xxx: vregs (108000-108007) y CLR INT (10800C-10800F).
    wire blk_108 = as & (addr[23:12] == 12'h108);
    assign cs_vregs  = blk_108 & (addr[11:3] == 9'd0);                     // 108000-108007 (8 bytes)
    assign cs_clrint = blk_108 & (addr[11:2] == 10'b0000000011);           // 10800C-10800F

    // Bloque 7000xx: I/O. El 68000 no tiene A0 (byte por UDS/LDS) -> decodificar por word (a[7:1]).
    wire blk_70 = as & (addr[23:8] == 16'h7000);
    assign cs_dsw2     = blk_70 & (addr[7:1] == 7'h00);                    // 700000-700001
    assign cs_dsw1     = blk_70 & (addr[7:1] == 7'h01);                    // 700002-700003
    assign cs_p1       = blk_70 & (addr[7:1] == 7'h02);                    // 700004-700005
    assign cs_p2       = blk_70 & (addr[7:1] == 7'h03);                    // 700006-700007
    assign cs_system   = blk_70 & (addr[7:1] == 7'h04);                    // 700008-700009
    assign cs_outlatch = blk_70 & (addr[7:1] == 7'h05);                    // 70000A-70000B (byte bajo 0B)
    assign cs_okibank  = blk_70 & (addr[7:1] == 7'h06);                    // 70000C-70000D (byte bajo 0D)
    assign cs_oki      = blk_70 & (addr[7:1] == 7'h07);                    // 70000E-70000F (byte bajo 0F)
endmodule

`default_nettype wire
