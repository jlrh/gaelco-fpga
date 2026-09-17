`default_nettype none

module aligator_gae1_tilemap (
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
    input  wire        rbank
);
    localparam [2:0] IDLE=0, REQ=1, RDTP=2, ATTR=3, WAITG=4, PIX=5, DONE=6;

    reg [2:0]  state;
    reg [9:0]  sx;
    reg        wbank_r;
    reg [4:0]  ty_r;
    reg [3:0]  row0_r;
    reg [9:0]  tmx_r;

    reg [18:0] code_r; reg flipx_r, flipy_r; reg [6:0] color_r;
    reg [7:0]  g0, g1, g2, g3;
`ifdef ALIGATOR_SWAPTRACE
    reg [12:0] swtn = 0;
`endif

    reg [11:0] lb0 [0:511];
    reg [11:0] lb1 [0:511];
    assign lb_q = rbank ? lb1[lb_x] : lb0[lb_x];

    wire [9:0] tmx_next = (sx + 10'd1 + scroll_x) & 10'h3ff;
    wire       half_end = (tmx_next[3] != tmx_r[3]);

    wire [3:0] col0 = tmx_r[3:0];
    wire [3:0] col1 = flipx_r ? ~col0 : col0;
    wire [2:0] bbit = 3'd7 - col1[2:0];
    wire [4:0] pen  = {1'b0, g3[bbit], g2[bbit], g1[bbit], g0[bbit]};
    wire [11:0] lb_wdata = {color_r, pen};

    wire [5:0]  tx_f       = tmx_r[9:4];
    wire [10:0] tindex_f   = {ty_r, tx_f};
    wire [15:0] word0      = tp_q[31:16];
    wire [15:0] word1      = tp_q[15:0];
    wire [18:0] code_w     = {word0[2:0], word1};
    wire        flipx_w    = word0[7];
    wire        flipy_w    = word0[6];
    wire [3:0]  col1_f     = flipx_w ? ~tmx_r[3:0] : tmx_r[3:0];
    wire [3:0]  row1_f     = flipy_w ? ~row0_r     : row0_r;

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
                color_r <= word0[15:9];
                rom_a   <= {code_w[16:0], col1_f[3], row1_f};
                state   <= WAITG;
            end
            WAITG: if (gfx_ok) begin
                g0 <= d_p0; g1 <= d_p1; g2 <= d_p2; g3 <= d_p3;
                state <= PIX;
`ifdef ALIGATOR_SWAPTRACE

                if (rom_a[21:9]==13'h1d01 && swtn<13'd60) begin
                    $display("SWAPTRACE rom_a=%06x dp=%02x%02x%02x%02x", rom_a, d_p3,d_p2,d_p1,d_p0);
                    swtn <= swtn + 1;
                end
`endif
            end
            PIX: begin
                if (wbank_r) lb1[sx[8:0]] <= lb_wdata; else lb0[sx[8:0]] <= lb_wdata;
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

`ifdef ALIGATOR_TMTRACE

    reg [9:0] dbg_maxsx=0; reg [9:0] dbg_n=0;
    always @(posedge clk) if (ce) begin
        if (start) begin
            if (dbg_n<10'd24 && (busy || dbg_maxsx!=10'd319)) begin
                $display("TMTRACE scroll=%0d: prev_line maxsx=%0d busy=%b state=%0d", scroll_x, dbg_maxsx, busy, state);
                dbg_n <= dbg_n + 10'd1;
            end
            dbg_maxsx <= 10'd0;
        end else if (state==PIX && sx>dbg_maxsx) dbg_maxsx <= sx;
    end
`endif

    // synthesis translate_off
    integer k;
    initial begin state=IDLE; busy=0; sx=0; wbank_r=0; code_r=0;
        for (k=0;k<512;k=k+1) begin lb0[k]=0; lb1[k]=0; end end
    // synthesis translate_on
endmodule

`default_nettype wire
