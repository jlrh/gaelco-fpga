`default_nettype none

module wrally2_twin_split (
    input  wire        clk,
    input  wire        en,
    input  wire        ce16,

    input  wire [4:0]  r_i, g_i, b_i,
    input  wire        hb_i, vb_i, hs_i, vs_i,

    output reg  [4:0]  r_o, g_o, b_o,
    output reg         hb_o, vb_o, hs_o, vs_o,
    output wire        ce_o,

    output reg         tfb_we,
    output reg  [8:0]  tfb_x,
    output reg  [8:0]  tfb_y,
    output reg  [14:0] tfb_rgb,
    output reg         tfb_frame
);

    reg [9:0] x16;
    reg [8:0] y;
    reg       hb_q, vb_q;
    always @(posedge clk) if (ce16) begin
        hb_q <= hb_i; vb_q <= vb_i;
        if (hb_i)            x16 <= 10'd0;
        else                 x16 <= x16 + 10'd1;
        if (vb_i)            y   <= 9'd0;
        else if (hb_i & ~hb_q) y <= y + 9'd1;
    end

    reg [14:0] lbuf [0:511];
    always @(posedge clk) if (ce16 && !hb_i && x16 < 10'd384) lbuf[x16[8:0]] <= {r_i, g_i, b_i};

    always @(posedge clk) begin
        tfb_we    <= 1'b0;
        tfb_frame <= 1'b0;
        if (ce16) begin
            if (en && !hb_i && !vb_i && x16 >= 10'd384) begin
                tfb_we  <= 1'b1;
                tfb_x   <= x16[8:0] - 9'd384;
                tfb_y   <= y;
                tfb_rgb <= {r_i, g_i, b_i};
            end
            if (vb_i & ~vb_q) tfb_frame <= 1'b1;
        end
    end

    reg [1:0] hb_d, vb_d, hs_d, vs_d;
    always @(posedge clk) if (ce16) begin
        hb_d <= {hb_d[0], hb_i}; vb_d <= {vb_d[0], vb_i};
        hs_d <= {hs_d[0], hs_i}; vs_d <= {vs_d[0], vs_i};
    end
    wire hb_dd = hb_d[1];

    reg ph;
    always @(posedge clk) if (ce16) ph <= (hb_d[1] & ~hb_d[0]) ? 1'b0 : ~ph;
    wire ce8 = ce16 & ~ph;
    assign ce_o = en ? ce8 : ce16;

    reg [8:0] x8;
    always @(posedge clk) begin
        if (en) begin
            if (ce8) begin
                hb_o <= hb_dd; vb_o <= vb_d[1]; hs_o <= hs_d[1]; vs_o <= vs_d[1];
                if (hb_dd) begin
                    x8 <= 9'd0; {r_o, g_o, b_o} <= 15'd0;
                end else begin
                    {r_o, g_o, b_o} <= lbuf[x8];
                    x8 <= x8 + 9'd1;
                end
            end
        end else if (ce16) begin
            r_o <= r_i; g_o <= g_i; b_o <= b_i;
            hb_o <= hb_i; vb_o <= vb_i; hs_o <= hs_i; vs_o <= vs_i;
        end
    end
endmodule
