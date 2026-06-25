// ============================================================================
//  Thunder Hoop (Gaelco) — Conversor de color de paleta xBGR_555 -> RGB (5-5-5).
//
//  MAME (gaelco.cpp:1014): PALETTE set_format(palette_device::xBGR_555, 1024).
//  Cada entrada de 16 bits:  x BBBBB GGGGG RRRRR
//    [14:10] B   [9:5] G   [4:0] R   ([15] sin uso)
//  COLORW=5 -> salida DIRECTA de 5 bits/canal (sin expansion). Combinacional puro.
// ============================================================================
`default_nettype none

module thoop2_palette (
    input  wire [15:0] pal_word,   // entrada de la RAM de paleta (xBGR_555)
    output wire [4:0]  r,
    output wire [4:0]  g,
    output wire [4:0]  b
);
    assign r = pal_word[4:0];
    assign g = pal_word[9:5];
    assign b = pal_word[14:10];
endmodule

`default_nettype wire
