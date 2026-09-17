`default_nettype none

module aligator_inputs (

    input  wire [15:0] dipsw,

    input  wire [6:0]  joystick1,
    input  wire [6:0]  joystick2,
    input  wire [1:0]  coin,
    input  wire [1:0]  start,
    input  wire        service,

    output wire [15:0] port_in0,
    output wire [15:0] port_in1,
    output wire [15:0] port_coin
);
    wire [7:0] dsw1 = dipsw[7:0];
    wire [7:0] dsw2 = dipsw[15:8];

    wire [7:0] p1 = { start[0], joystick1[6], joystick1[5], joystick1[4],
                      joystick1[1], joystick1[0], joystick1[2], joystick1[3] };

    wire [7:0] p2 = { start[1], joystick2[6], joystick2[5], joystick2[4],
                      joystick2[1], joystick2[0], joystick2[2], joystick2[3] };

    assign port_in0 = { dsw1, p1 };
    assign port_in1 = { dsw2, p2 };

    assign port_coin = { 10'h3FF, service, 1'b1, 1'b1, 1'b1, coin[1], coin[0] };
endmodule

`default_nettype wire
