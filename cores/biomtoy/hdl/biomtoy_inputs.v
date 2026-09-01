`default_nettype none

module biomtoy_inputs (

    input  wire [15:0] dipsw,

    input  wire [5:0]  joystick1,
    input  wire [5:0]  joystick2,
    input  wire [1:0]  coin,
    input  wire [1:0]  start,
    input  wire        service,

    output wire [15:0] port_dsw2,
    output wire [15:0] port_dsw1,
    output wire [15:0] port_p1,
    output wire [15:0] port_p2
);
    wire [7:0] dsw1 = dipsw[7:0];
    wire [7:0] dsw2 = dipsw[15:8];

    assign port_dsw1 = {8'hFF, dsw1};
    assign port_dsw2 = {8'hFF, dsw2[7] & service, dsw2[6:0]};

    assign port_p1 = {8'hFF, coin[1], coin[0],
                      joystick1[5], joystick1[4], joystick1[1], joystick1[0], joystick1[2], joystick1[3]};

    assign port_p2 = {8'hFF, start[1], start[0],
                      joystick2[5], joystick2[4], joystick2[1], joystick2[0], joystick2[2], joystick2[3]};
endmodule

`default_nettype wire
