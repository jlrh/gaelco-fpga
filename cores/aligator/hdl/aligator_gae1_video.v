`default_nettype none

module aligator_gae1_video (
    input  wire        clk,
    input  wire        ce,
    input  wire [9:0]  hpos,
    input  wire [8:0]  vpos,
    input  wire        frame_end,

    input  wire [15:0] vreg0, vreg1,

    output wire [14:0] wrd_a,
    input  wire [15:0] wrd_q,

    output wire [13:0] tp0_idx, input wire [31:0] tp0_q,
    output wire [21:0] rom_a0,  input wire [7:0] d0_p0, d0_p1, d0_p2, d0_p3, input wire gfx0_ok,

    output wire [13:0] tp1_idx, input wire [31:0] tp1_q,
    output wire [21:0] rom_a1,  input wire [7:0] d1_p0, d1_p1, d1_p2, d1_p3, input wire gfx1_ok,

    output reg  [11:0] pal_index,
    output reg         opaque
);

    reg [8:0] vpos_d;
    always @(posedge clk) vpos_d <= vpos;
    wire        line_change = (vpos != vpos_d);
    wire [8:0]  next_vpos   = frame_end ? 9'd0 : vpos + 9'd1;

    wire [8:0]  render_line = next_vpos + 9'd16;
    wire        rbank = vpos[0];
    wire        wbank = next_vpos[0];

    reg start_r;
    always @(posedge clk) start_r <= line_change;

    reg [2:0] scnt = 3'd0;
    reg [8:0] scroll0y, scroll1y;
    reg [9:0] scroll0x, scroll1x;
    reg [9:0] ls0, ls1;
    assign wrd_a = (scnt==3'd4) ? (15'h1000 + {6'd0, render_line}) :
                   (scnt==3'd5) ? (15'h1200 + {6'd0, render_line}) :

                                  (15'h1400 + {12'd0, scnt});
    always @(posedge clk) if (ce) begin
        scnt <= (scnt==3'd5) ? 3'd0 : scnt + 3'd1;
        case (scnt)
            3'd0: scroll0y <= wrd_q[8:0] + 9'd1;
            3'd1: scroll0x <= wrd_q[9:0] + 10'h14;
            3'd2: scroll1y <= wrd_q[8:0] + 9'd1;
            3'd3: scroll1x <= wrd_q[9:0] + 10'h10;
            3'd4: ls0      <= wrd_q[9:0] + 10'h14;
            3'd5: ls1      <= wrd_q[9:0] + 10'h10;
        endcase
    end
    wire [9:0] scroll0x_eff = vreg0[15] ? ls0 : scroll0x;
    wire [9:0] scroll1x_eff = vreg1[15] ? ls1 : scroll1x;

    wire [2:0] bank0 = vreg0[11:9];
    wire [2:0] bank1 = vreg1[11:9];

    wire [11:0] lb_q0, lb_q1;

`ifdef ALIGATOR_TMOFF
    localparam [9:0] TMOFF = `ALIGATOR_TMOFF;
`else
    localparam [9:0] TMOFF = 10'd0;

`endif
    wire [9:0] sc0x = (scroll0x_eff - TMOFF) & 10'h3ff;
    wire [9:0] sc1x = (scroll1x_eff - TMOFF) & 10'h3ff;

`ifdef ALIGATOR_TMRD
    wire [9:0] lb_rx = (hpos + `ALIGATOR_TMRD) & 10'h1ff;
`else
    wire [9:0] lb_rx = (hpos - 10'd14) & 10'h1ff;
`endif

    aligator_gae1_tilemap u_l0 (
        .clk(clk), .ce(1'b1), .start(start_r), .line(render_line),
        .scroll_x(sc0x), .scroll_y(scroll0y), .bank(bank0), .busy(),
        .tp_idx(tp0_idx), .tp_q(tp0_q),
        .rom_a(rom_a0), .d_p0(d0_p0), .d_p1(d0_p1), .d_p2(d0_p2), .d_p3(d0_p3), .gfx_ok(gfx0_ok),
        .lb_x(lb_rx), .lb_q(lb_q0), .wbank(wbank), .rbank(rbank)
    );
    aligator_gae1_tilemap u_l1 (
        .clk(clk), .ce(1'b1), .start(start_r), .line(render_line),
        .scroll_x(sc1x), .scroll_y(scroll1y), .bank(bank1), .busy(),
        .tp_idx(tp1_idx), .tp_q(tp1_q),
        .rom_a(rom_a1), .d_p0(d1_p0), .d_p1(d1_p1), .d_p2(d1_p2), .d_p3(d1_p3), .gfx_ok(gfx1_ok),
        .lb_x(lb_rx), .lb_q(lb_q1), .wbank(wbank), .rbank(rbank)
    );

    wire [4:0] pen0 = lb_q0[4:0]; wire [6:0] color0 = lb_q0[11:5];
    wire [4:0] pen1 = lb_q1[4:0]; wire [6:0] color1 = lb_q1[11:5];
    wire op0 = (pen0 != 5'd0);
`ifdef ALIGATOR_L0ONLY
    wire op1 = 1'b0;
`else
    wire op1 = (pen1 != 5'd0);
`endif
    always @(posedge clk) if (ce) begin
        if (op0)      begin pal_index <= {color0, pen0}; opaque <= 1'b1; end
        else if (op1) begin pal_index <= {color1, pen1}; opaque <= 1'b1; end
        else          begin pal_index <= 12'd0;          opaque <= 1'b0; end
    end
endmodule

`default_nettype wire
