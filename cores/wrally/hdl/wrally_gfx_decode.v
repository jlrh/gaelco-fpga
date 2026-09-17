`default_nettype none

module wrally_gfx_decode (
    input  wire [13:0] code,
    input  wire [3:0]  row,
    input  wire [3:0]  col,
    output wire [18:0] romaddr,
    input  wire [7:0]  d_i07,
    input  wire [7:0]  d_i09,
    input  wire [7:0]  d_i11,
    input  wire [7:0]  d_i13,
    output wire [3:0]  pix
);

    assign romaddr = {code, 5'b00000} + {14'b0, col[3], row};

    wire [2:0] b = 3'd7 - col[2:0];
    assign pix = { d_i07[b], d_i09[b], d_i11[b], d_i13[b] };
endmodule

`default_nettype wire
