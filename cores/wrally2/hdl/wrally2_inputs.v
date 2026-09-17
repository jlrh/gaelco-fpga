`default_nettype none

module wrally2_inputs (
    input  wire        clk,
    input  wire [15:0] dipsw,
    input  wire [5:0]  joystick1,
    input  wire [5:0]  joystick2,
    input  wire [1:0]  coin,
    input  wire [1:0]  start,
    input  wire        service,
    input  wire        test,

    output wire [15:0] port_in0,
    output wire [15:0] port_in1,
    output wire [15:0] port_in2,
    output wire [15:0] port_in3
);
    wire [7:0] dsw1 = dipsw[7:0];
    wire [7:0] dsw2 = dipsw[15:8];

    reg gear1 = 1'b0, gear2 = 1'b0, b1p = 1'b0, b2p = 1'b0;
    always @(posedge clk) begin
        b1p <= ~joystick1[5]; b2p <= ~joystick2[5];
        if (~joystick1[5] & ~b1p) gear1 <= ~gear1;
        if (~joystick2[5] & ~b2p) gear2 <= ~gear2;
    end

    wire [7:0] p1 = { start[0], 1'b0, gear1, joystick1[4],
                      joystick1[1], joystick1[0], joystick1[2], joystick1[3] };
    wire [7:0] p2 = { start[1], 1'b0, gear2, joystick2[4],
                      joystick2[1], joystick2[0], joystick2[2], joystick2[3] };

    wire [7:0] coinb = { 5'b11111, coin[1], 1'b1, coin[0] };

    wire [7:0] servb = { 5'b11111, 1'b1, test, service };

    assign port_in0 = { dsw2, p1 };
    assign port_in1 = { dsw1, 8'hFF };
    assign port_in2 = { coinb, p2 };
    assign port_in3 = { servb, 8'hFF };
endmodule

`default_nettype wire
