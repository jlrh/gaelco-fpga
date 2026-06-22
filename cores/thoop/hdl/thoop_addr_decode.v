// ============================================================================
//  Thunder Hoop (Gaelco) — Decodificador de direcciones del bus del 68000
//
//  Mapa EXACTO de MAME (src/mame/gaelco/gaelco.cpp thoop_map):
//    000000-0FFFFF  ROM de programa (1 MB)
//    100000-101FFF  videoram (8 KB, CIFRADA: vram_encrypted_w)  -> tilemaps L0/L1
//    102000-103FFF  screenram(8 KB, CIFRADA: encrypted_w)
//    108000-108007  vregs (4x u16 scroll)
//    10800C-10800D  irqack / watchdog (CLR INT6)
//    200000-2007FF  paleta (512 entradas xBGR-555)
//    440000-440FFF  sprite RAM (4 KB)
//    700000  DSW2   700002  DSW1   700004  P1   700006  P2
//    70000B  LS259 outlatch (coin lockout/counter; select 0x70 -> a[6:4])
//    70000D  OKI bankswitch (nibble)     70000F  OKIM6295 r/w
//    FF0000-FFFFFF  work RAM (64 KB)  (NO compartida: Tipo-1 no lleva DS5002)
//
//  Decodificacion por rango (como el hardware real). Combinacional puro.
// ============================================================================
`default_nettype none

module thoop_addr_decode (
    input  wire [23:0] addr,    // direccion de BYTE del 68000 (A0 implicito por UDS/LDS)
    input  wire        as,      // 1 = ciclo de bus valido (address strobe)

    output wire        cs_rom,      // 000000-0FFFFF  ROM
    output wire        cs_vram,     // 100000-101FFF  videoram (cifrada)
    output wire        cs_scrram,   // 102000-103FFF  screenram (cifrada)
    output wire        cs_vregs,    // 108000-108007  registros de video
    output wire        cs_clrint,   // 10800C-10800D  CLR INT6
    output wire        cs_pal,      // 200000-2007FF  paleta
    output wire        cs_spr,      // 440000-440FFF  sprite RAM
    output wire        cs_dsw2,     // 700000-700001  DSW2
    output wire        cs_dsw1,     // 700002-700003  DSW1
    output wire        cs_p1,       // 700004-700005  P1
    output wire        cs_p2,       // 700006-700007  P2
    output wire        cs_outlatch, // 70000B         LS259 (coin lockout/counter)
    output wire        cs_okibank,  // 70000D         OKI bankswitch
    output wire        cs_oki,      // 70000F         OKI r/w
    output wire        cs_wram      // FF0000-FFFFFF  work RAM
);
    assign cs_rom   = as & (addr[23:20] == 4'h0);                                       // 000000-0FFFFF
    // 100000-103FFF: videoram (100000-101FFF) + screenram (102000-103FFF). addr[13]=0 video, =1 screen.
    wire blk_1xxx   = as & (addr[23:20] == 4'h1) & (addr[19:14] == 6'b000000);          // 100000-103FFF
    assign cs_vram  = blk_1xxx & ~addr[13];                                             // 100000-101FFF
    assign cs_scrram= blk_1xxx &  addr[13];                                             // 102000-103FFF
    assign cs_pal   = as & (addr[23:20] == 4'h2) & (addr[19:11] == 9'b0);               // 200000-2007FF
    assign cs_spr   = as & (addr[23:16] == 8'h44) & (addr[15:12] == 4'h0);              // 440000-440FFF
    assign cs_wram  = as & (addr[23:16] == 8'hFF);                                      // FF0000-FFFFFF

    // Bloque 108xxx: vregs (108000-108007) y CLR INT (10800C-10800D).
    wire blk_108 = as & (addr[23:12] == 12'h108);
    assign cs_vregs  = blk_108 & (addr[11:3] == 9'd0);                                  // 108000-108007 (8 bytes)
    assign cs_clrint = blk_108 & (addr[11:2] == 10'b0000000011);                        // 10800C-10800F

    // Bloque 7000xx: I/O. El 68000 no tiene A0 (byte por UDS/LDS) -> decodificar por word (a[7:1]).
    wire blk_70 = as & (addr[23:8] == 16'h7000);
    assign cs_dsw2     = blk_70 & (addr[7:1] == 7'h00);                                 // 700000-700001
    assign cs_dsw1     = blk_70 & (addr[7:1] == 7'h01);                                 // 700002-700003
    assign cs_p1       = blk_70 & (addr[7:1] == 7'h02);                                 // 700004-700005
    assign cs_p2       = blk_70 & (addr[7:1] == 7'h03);                                 // 700006-700007
    assign cs_outlatch = blk_70 & (addr[7:1] == 7'h05);                                 // 70000A-70000B (byte bajo 0B)
    assign cs_okibank  = blk_70 & (addr[7:1] == 7'h06);                                 // 70000C-70000D (byte bajo 0D)
    assign cs_oki      = blk_70 & (addr[7:1] == 7'h07);                                 // 70000E-70000F (byte bajo 0F)
endmodule

`default_nettype wire
