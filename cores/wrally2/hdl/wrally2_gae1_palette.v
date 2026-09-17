`default_nettype none

module wrally2_gae1_palette (
    input  wire [15:0] pal_word,
    input  wire [3:0]  variant,
    output wire [4:0]  r, g, b
);

    wire [4:0] r5 = pal_word[14:10];
    wire [4:0] g5 = pal_word[9:5];
    wire [4:0] b5 = pal_word[4:0];
    wire [7:0] r8 = {r5, r5[4:2]};
    wire [7:0] g8 = {g5, g5[4:2]};
    wire [7:0] b8 = {b5, b5[4:2]};

    function signed [8:0] adj;
        input [3:0] v;
        case (v)
            4'd0:  adj =  9'sd0;
            4'd1:  adj = -9'sd8;
            4'd2:  adj = -9'sd16;
            4'd3:  adj = -9'sd24;
            4'd4:  adj = -9'sd32;
            4'd5:  adj = -9'sd40;
            4'd6:  adj = -9'sd48;
            4'd7:  adj = -9'sd56;
            4'd8:  adj =  9'sd64;
            4'd9:  adj =  9'sd56;
            4'd10: adj =  9'sd48;
            4'd11: adj =  9'sd40;
            4'd12: adj =  9'sd32;
            4'd13: adj =  9'sd24;
            4'd14: adj =  9'sd16;
            4'd15: adj =  9'sd8;
        endcase
    endfunction
    wire signed [8:0] a = adj(variant);

    function [4:0] adjclamp;
        input [7:0] c8;
        input signed [8:0] off;
        reg signed [9:0] s;
        begin
            s = $signed({2'b0, c8}) + off;
            if (s < 0)            adjclamp = 5'd0;
            else if (s > 10'sd255) adjclamp = 5'd31;
            else                  adjclamp = s[7:3];
        end
    endfunction

    assign r = adjclamp(r8, a);
    assign g = adjclamp(g8, a);
    assign b = adjclamp(b8, a);
endmodule

`default_nettype wire
