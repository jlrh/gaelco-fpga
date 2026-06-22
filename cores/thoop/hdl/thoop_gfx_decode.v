// ============================================================================
//  Thunder Hoop (Gaelco) — Decodificador de gfx planar (4bpp, RGN_FRAC(1,4)).
//
//  MAME gfx_layout (gaelco.cpp):
//    tilelayout16 (tiles): 16x16, 4bpp, planos {0,1/4,2/4,3/4}, x={STEP8(0,1),STEP8(16*8,1)},
//                          y={STEP16(0,8)}, inc=32*8 -> 32 bytes/tile/plano.
//    tilelayout8 (sprites): 8x8, 4bpp, planos {0,1/4,2/4,3/4}, x=STEP8(0,1), y=STEP8(0,8),
//                          inc=8*8 -> 8 bytes/tile/plano.
//  Derivado (idem fórmula que WRally tilelayout16):
//    tile16:  byte_in_plane = code*32 + (col>=8 ? 16:0) + row ;  bit = 7 - col[2:0]
//    sprite8: byte_in_plane = code*8  + row              ;       bit = 7 - col[2:0]
//    pix4 = { p3[bit], p2[bit], p1[bit], p0[bit] }   (p0 = plano offset 0 = LSB)
//
//  Los 4 planos llegan como 4 byte-lanes de una lectura DW32 de la SDRAM (el .mra
//  de-interleava los 4 cuartos a los lanes p0..p3). El orden plano<->lane es el GRADO
//  DE LIBERTAD a CALIBRAR contra captura (como WRally V.054). Combinacional puro.
// ============================================================================
`default_nettype none

module thoop_gfx_decode (
    input  wire        is8,        // 1 = sprite 8x8 (code*8) ; 0 = tile 16x16 (code*32)
    input  wire [13:0] code,
    input  wire [3:0]  row,        // 0..15 (flipY aplicado fuera). En 8x8 solo row[2:0].
    input  wire [3:0]  col,        // 0..15 (flipX aplicado fuera). En 8x8 solo col[2:0].
    output wire [19:0] romaddr,    // byte index intra-plano (0..0xFFFFF = 1MB/plano)
    input  wire [7:0]  p0, p1, p2, p3,
    output wire [3:0]  pix         // 0..15 (pen dentro del bloque de color)
);
    // tile 16x16: code*32 + col[3]*16 + row       sprite 8x8: code*8 + row[2:0]
    // code (14b) base 0x4000 -> code*32 llega hasta ~0xFFFE0 -> 20 bits.
    wire [19:0] addr16 = {1'b0, code, 5'b00000} + {15'b0, col[3], row};  // code*32 + (col>=8?16:0) + row
    wire [19:0] addr8  = {3'b0, code, 3'b000} + {17'b0, row[2:0]};  // code*8 + row
    assign romaddr = is8 ? addr8 : addr16;

    wire [2:0] b = 3'd7 - col[2:0];
    assign pix = { p3[b], p2[b], p1[b], p0[b] };
endmodule

`default_nettype wire
