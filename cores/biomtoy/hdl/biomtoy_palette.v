`default_nettype none

module biomtoy_palette (
    input  wire [15:0] pal_word,
    output wire [4:0]  r,
    output wire [4:0]  g,
    output wire [4:0]  b
);
    assign r = pal_word[4:0];
    assign g = pal_word[9:5];
    assign b = pal_word[14:10];
endmodule

`default_nettype wire
