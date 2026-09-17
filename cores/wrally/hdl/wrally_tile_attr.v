`default_nettype none

module wrally_tile_attr (
    input  wire [15:0] data,
    input  wire [15:0] data2,
    output wire [13:0] code,
    output wire [4:0]  color,
    output wire        prio,
    output wire        flipx,
    output wire        flipy
);
    assign code     = data[13:0];
    assign color    = data2[4:0];
    assign prio     = data2[5];
    assign flipx    = data2[6];
    assign flipy    = data2[7];
endmodule

`default_nettype wire
