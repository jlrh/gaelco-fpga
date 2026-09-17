`default_nettype none

module wrally_inputs (

    input  wire [15:0] dsw,

    input  wire p1_up, p1_down, p1_left, p1_right,
    input  wire p1_btn1,
    input  wire p1_gear,

    input  wire p2_up, p2_down, p2_left, p2_right,
    input  wire p2_btn1,
    input  wire p2_gear,

    input  wire coin1, coin2,
    input  wire start1, start2,
    input  wire service,
    input  wire test,

    output wire [15:0] port_dsw,
    output wire [15:0] port_p1p2,
    output wire [15:0] port_wheel,
    output wire [15:0] port_system
);

    assign port_dsw = dsw;

    assign port_p1p2 = ~{
        start2,
        start1,
        p2_btn1,
        p2_gear,
        p2_left,
        p2_right,
        p2_down,
        p2_up,
        coin2,
        coin1,
        p1_btn1,
        p1_gear,
        p1_left,
        p1_right,
        p1_down,
        p1_up
    };

    assign port_wheel = 16'hFFFF;

    assign port_system = { 12'hFFF, 2'b00, ~test, ~service };

endmodule

`default_nettype wire
