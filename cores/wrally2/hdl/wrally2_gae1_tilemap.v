`default_nettype none

module wrally2_gae1_tilemap (
    input  wire        clk,
    input  wire        ce,
    input  wire        start,
    input  wire [8:0]  line,
    input  wire [9:0]  scroll_x,
    input  wire [8:0]  scroll_y,
    input  wire [2:0]  bank,
    output reg         busy,

    output reg  [13:0] tp_idx,
    input  wire [31:0] tp_q,

    output reg  [21:0] rom_a,
    input  wire [7:0]  d_p0, d_p1, d_p2, d_p3,
    input  wire        gfx_ok,

    input  wire [9:0]  lb_x,
    output wire [11:0] lb_q,

    input  wire        wbank,
    input  wire        rbank,

    output reg         ovr
);
    localparam [2:0] IDLE=0, REQ=1, RDTP=2, ATTR=3, WAITG=4, WAITG4=5, PIX=6, DONE=7;

    reg [2:0]  state;
    reg [9:0]  sx;
    reg        wbank_r;
    reg [4:0]  ty_r;
    reg [3:0]  row0_r;
    reg [9:0]  tmx_r;

    reg [15:0] code_r; reg flipx_r, flipy_r; reg [6:0] color_r;
    reg [20:0] elem_r;
    reg [7:0]  g0, g1, g2, g3, g4;

    reg [11:0] lb0 [0:511];
    reg [11:0] lb1 [0:511];
    reg [11:0] lb0_q, lb1_q;
    wire lb0_we = (state==PIX) & ~wbank_r;
    wire lb1_we = (state==PIX) &  wbank_r;
    always @(posedge clk) begin
        if (lb0_we) lb0[sx[8:0]] <= lb_wdata;
        lb0_q <= lb0[lb_x[8:0]];
    end
    always @(posedge clk) begin
        if (lb1_we) lb1[sx[8:0]] <= lb_wdata;
        lb1_q <= lb1[lb_x[8:0]];
    end
    assign lb_q = rbank ? lb1_q : lb0_q;

    wire [9:0] tmx_next = (sx + 10'd1 + scroll_x) & 10'h3ff;
    wire       half_end = (tmx_next[3] != tmx_r[3]);

    wire [3:0] col0 = tmx_r[3:0];
    wire [3:0] col1 = flipx_r ? ~col0 : col0;
    wire [2:0] bbit = 3'd7 - col1[2:0];
    wire [4:0] pen  = {g4[bbit], g3[bbit], g2[bbit], g1[bbit], g0[bbit]};
    wire [11:0] lb_wdata = {color_r, pen};

    wire [5:0]  tx_f       = tmx_r[9:4];
    wire [10:0] tindex_f   = {ty_r, tx_f};
    wire [15:0] word0      = tp_q[31:16];
    wire [15:0] word1      = tp_q[15:0];
    wire [15:0] code_w     = word1;
    wire        flipx_w    = word0[7];
    wire        flipy_w    = word0[6];
    wire [3:0]  col1_f     = flipx_w ? ~tmx_r[3:0] : tmx_r[3:0];
    wire [3:0]  row1_f     = flipy_w ? ~row0_r     : row0_r;
    wire [20:0] elem_w     = {code_w[15:0], col1_f[3], row1_f};

    always @(posedge clk) if (ce) begin
        if (start) begin
            wbank_r <= wbank; busy <= 1'b1;
            ty_r    <= (line + scroll_y) >> 4;
            row0_r  <= (line + scroll_y) & 9'h00f;
            sx      <= 10'd0;
            tmx_r   <= scroll_x & 10'h3ff;
            state   <= REQ;
        end else case (state)
            IDLE: ;
            REQ: begin
                tp_idx <= {bank, tindex_f};
                state  <= RDTP;
            end
            RDTP: state <= ATTR;
            ATTR: begin
                code_r  <= code_w; flipx_r <= flipx_w; flipy_r <= flipy_w;
                color_r <= {1'b0, word0[14:9]};
                elem_r  <= elem_w;
                rom_a   <= {1'b0, elem_w};
                state   <= WAITG;
            end
            WAITG: if (gfx_ok) begin
                g0 <= d_p0; g1 <= d_p1;

                g2 <= elem_r[20] ? 8'd0 : d_p2;
                g3 <= elem_r[20] ? 8'd0 : d_p3;
                rom_a <= {1'b1, elem_r};
                state <= WAITG4;
            end
            WAITG4: if (gfx_ok) begin
                g4 <= d_p0;
                state <= PIX;
            end
            PIX: begin
                if (sx == 10'd383) begin
                    state <= DONE;
                end else begin
                    sx    <= sx + 10'd1;
                    tmx_r <= tmx_next;
                    if (half_end) state <= REQ;

                end
            end
            DONE: begin busy <= 1'b0; state <= IDLE; end
            default: state <= IDLE;
        endcase
    end

    always @(posedge clk) if (ce) ovr <= start & (state != IDLE);

    // synthesis translate_off
    integer k;
    initial begin state=IDLE; busy=0; sx=0; wbank_r=0; code_r=0; lb0_q=0; lb1_q=0; ovr=0;
        for (k=0;k<512;k=k+1) begin lb0[k]=0; lb1[k]=0; end end
    // synthesis translate_on

`ifdef SIMULATION
    localparam integer LINE_BUDGET = 3072;
    integer rcyc=0, rmax=0, novr=0, nline=0;

    integer wcyc=0, wmax=0;
    always @(posedge clk) if (ce) begin

        if ((state==WAITG || state==WAITG4) && !gfx_ok) wcyc <= wcyc + 1;
        else begin
            if (wcyc > wmax) begin wmax <= wcyc;
                $display("TMLAT %m read-latency=%0d clk (max)", wcyc);
            end
            wcyc <= 0;
        end
        if (start) begin
            if (state != IDLE) begin
                novr <= novr + 1;
                $display("TMOVR %m line=%0d OVERRUN (state=%0d sx=%0d de %0d) novr=%0d", line, state, sx, 10'd383, novr+1);
            end
            nline <= nline + 1;
            rcyc  <= 0;
        end else begin
            rcyc <= rcyc + 1;
            if (state==DONE && rcyc > rmax) begin
                rmax <= rcyc;
                $display("TMMAX %m line=%0d rcyc=%0d / budget=%0d (%0d%% )", line, rcyc, LINE_BUDGET, (rcyc*100)/LINE_BUDGET);
            end
        end
    end
    final $display("TMSUM %m lineas=%0d rmax=%0d/%0d overruns=%0d lat_max=%0d", nline, rmax, LINE_BUDGET, novr, wmax);
`endif
endmodule

`default_nettype wire
