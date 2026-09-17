`default_nettype none

module wrally_palette (
    input  wire [15:0] pal_word,
    output wire [7:0]  r,
    output wire [7:0]  g,
    output wire [7:0]  b
);
    wire [3:0] b4 = pal_word[11:8];
    wire [3:0] r4 = pal_word[7:4];
    wire [3:0] g4 = pal_word[3:0];

    assign r = {r4, r4};
    assign g = {g4, g4};
    assign b = {b4, b4};
endmodule

`default_nettype wire
