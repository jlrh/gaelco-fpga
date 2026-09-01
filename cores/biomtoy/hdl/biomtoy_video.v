`default_nettype none

module biomtoy_video (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire [8:0]  hpos,
    input  wire [8:0]  vpos,

    input  wire [15:0] vreg_l0y, vreg_l0x, vreg_l1y, vreg_l1x,

    output wire [10:0] tile_a0, input wire [31:0] tile_q0,
    output wire [19:0] rom_a0,  input wire [7:0] d0_p0, d0_p1, d0_p2, d0_p3, input wire gfx0_ok,

    output wire [10:0] tile_a1, input wire [31:0] tile_q1,
    output wire [19:0] rom_a1,  input wire [7:0] d1_p0, d1_p1, d1_p2, d1_p3, input wire gfx1_ok,

    output reg  [9:0]  pal_index,
    output reg  [4:0]  win_rank,
    output reg         win_opaque
);

    wire [8:0] tmx0 = hpos + vreg_l0x[8:0] + 9'd3;
    wire [8:0] tmy0 = vpos + vreg_l0y[8:0] + 9'd16;
    wire [8:0] tmx1 = hpos + vreg_l1x[8:0] - 9'd1;
    wire [8:0] tmy1 = vpos + vreg_l1y[8:0] + 9'd16;

    wire [3:0] pen0, pen1; wire [5:0] color0, color1; wire [1:0] cat0, cat1;
    biomtoy_tilemap u_l0 (
        .clk(clk), .rst(rst), .ce(ce), .tmx(tmx0), .tmy(tmy0), .layer(1'b0),
        .tile_a(tile_a0), .tile_q(tile_q0),
        .rom_a(rom_a0), .d_p0(d0_p0), .d_p1(d0_p1), .d_p2(d0_p2), .d_p3(d0_p3), .gfx_ok(gfx0_ok),
        .pen(pen0), .color(color0), .category(cat0)
    );
    biomtoy_tilemap u_l1 (
        .clk(clk), .rst(rst), .ce(ce), .tmx(tmx1), .tmy(tmy1), .layer(1'b1),
        .tile_a(tile_a1), .tile_q(tile_q1),
        .rom_a(rom_a1), .d_p0(d1_p0), .d_p1(d1_p1), .d_p2(d1_p2), .d_p3(d1_p3), .gfx_ok(gfx1_ok),
        .pen(pen1), .color(color1), .category(cat1)
    );

    function [4:0] rank;
        input        t;
        input        isback;
        input [1:0]  cat;
        case ({cat, t, isback})
            {2'd3,1'b1,1'b1}: rank=5'd0;  {2'd3,1'b1,1'b0}: rank=5'd1;
            {2'd3,1'b0,1'b1}: rank=5'd2;  {2'd3,1'b0,1'b0}: rank=5'd3;
            {2'd2,1'b1,1'b1}: rank=5'd4;  {2'd2,1'b1,1'b0}: rank=5'd5;
            {2'd2,1'b0,1'b1}: rank=5'd6;  {2'd2,1'b0,1'b0}: rank=5'd7;
            {2'd1,1'b1,1'b1}: rank=5'd8;  {2'd1,1'b0,1'b1}: rank=5'd9;
            {2'd1,1'b1,1'b0}: rank=5'd10; {2'd1,1'b0,1'b0}: rank=5'd11;
            {2'd0,1'b1,1'b1}: rank=5'd12; {2'd0,1'b1,1'b0}: rank=5'd13;
            {2'd0,1'b0,1'b1}: rank=5'd14; default:           rank=5'd15;
        endcase
    endfunction

`ifdef BIOMTOY_L1ONLY
    wire op0 = 1'b0;
`elsif BIOMTOY_L0ONLY
    wire op0 = (pen0 != 4'd0);
`else
    wire op0 = (pen0 != 4'd0);
`endif
`ifdef BIOMTOY_L0ONLY
    wire op1 = 1'b0;
`else
    wire op1 = (pen1 != 4'd0);
`endif

`ifdef BIOMTOY_LINETRACE

    always @(posedge clk) if (ce && vpos==9'd85) begin
        $display("LT hpos=%0d pen0=%h op0=%b col0=%h g0ok=%b rom0=%h ta0=%h", hpos, pen0, op0, color0, gfx0_ok, rom_a0, tile_a0);
    end
`endif
`ifdef SIMULATION
    integer n_ce=0, n_g0=0, n_g1=0, n_op0=0, n_op1=0;
    always @(posedge clk) if (ce) begin
        n_ce<=n_ce+1;
        if (gfx0_ok) n_g0<=n_g0+1;
        if (gfx1_ok) n_g1<=n_g1+1;
        if (op0) n_op0<=n_op0+1;
        if (op1) n_op1<=n_op1+1;
        if (n_ce[18:0]==0) $display("VIDDBG ce=%0d g0ok=%0d g1ok=%0d op0=%0d op1=%0d | pen0=%h pen1=%h col0=%h col1=%h gfx0d=%h rom0=%h",
            n_ce, n_g0, n_g1, n_op0, n_op1, pen0, pen1, color0, color1, {d0_p3,d0_p2,d0_p1,d0_p0}, rom_a0);
    end
`endif
    wire [4:0] r0 = rank(1'b0, pen0[3], cat0);
    wire [4:0] r1 = rank(1'b1, pen1[3], cat1);

    wire l0_wins = op0 & (~op1 | (r0 >= r1));

    always @(posedge clk) begin
        if (rst) begin
            pal_index <= 10'd0; win_rank <= 5'd0; win_opaque <= 1'b0;
        end else if (ce) begin
            if (op0 & l0_wins) begin
                pal_index <= {color0, pen0}; win_rank <= r0; win_opaque <= 1'b1;
            end else if (op1) begin
                pal_index <= {color1, pen1}; win_rank <= r1; win_opaque <= 1'b1;
            end else begin
                pal_index <= 10'd0; win_rank <= 5'd0; win_opaque <= 1'b0;
            end
        end
    end
endmodule

`default_nettype wire
