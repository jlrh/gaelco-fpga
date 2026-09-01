`default_nettype none

module thoop_gfx_decode (
    input  wire        is8,
    input  wire [13:0] code,
    input  wire [3:0]  row,
    input  wire [3:0]  col,
    output wire [19:0] romaddr,
    input  wire [7:0]  p0, p1, p2, p3,
    output wire [3:0]  pix
);

    wire [19:0] addr16 = {1'b0, code, 5'b00000} + {15'b0, col[3], row};
    wire [19:0] addr8  = {3'b0, code, 3'b000} + {17'b0, row[2:0]};
    assign romaddr = is8 ? addr8 : addr16;

    wire [2:0] b = 3'd7 - col[2:0];
    assign pix = { p3[b], p2[b], p1[b], p0[b] };
endmodule

`default_nettype wire
