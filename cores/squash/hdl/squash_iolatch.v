`default_nettype none

module squash_iolatch (
    input  wire        clk,
    input  wire        reset,

    input  wire        cs_outlatch,
    input  wire [2:0]  outlatch_a,
    input  wire        outlatch_d0,
    output reg  [7:0]  outlatch,

    input  wire        cs_okibank,
    input  wire [3:0]  okibank_in,
    output reg  [3:0]  okibank,

    output wire        flip_screen
);
    assign flip_screen = outlatch[5];

    always @(posedge clk) begin
        if (reset) begin
            outlatch <= 8'd0;
            okibank  <= 4'd0;
        end else begin
            if (cs_outlatch) outlatch[outlatch_a] <= outlatch_d0;
            if (cs_okibank)  okibank <= okibank_in;
        end
    end
endmodule

`default_nettype wire
