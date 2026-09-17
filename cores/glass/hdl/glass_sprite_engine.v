`default_nettype none

module glass_sprite_engine (
    input  wire        clk,
    input  wire        ce,
    input  wire        start,
    input  wire [8:0]  line,
    output reg         busy,

    output wire [10:0] spr_a,
    input  wire [15:0] spr_q,

    output wire [19:0] rom_a,
    input  wire [7:0]  d_p0, d_p1, d_p2, d_p3,
    input  wire        gfx_ok,

    input  wire [8:0]  lb_x,
    output wire [12:0] lb_q,

    input  wire        wbank,
    input  wire        rbank
);
    localparam [3:0] IDLE=0, CLR=1, RDW0=2, RDW2=3, RDW3=4, TEST=5, CADDR=6, PADDR=7, PWR=8, NEXT=9, DON=10, CWAIT=11;

    reg [3:0]  state;
    reg [10:0] spr_idx;
    reg [9:0]  clr_i;
    reg [8:0]  line_r;
    reg [15:0] w0_r, w2_r, w3_r;
    reg        flipx_r, flipy_r;
    reg [8:0]  sx_r;
    reg [5:0]  color_r;
    reg [2:0]  prio_r;
    reg [14:0] code_r;
    reg [3:0]  rowq_r;
    reg        cellcol;
    reg [2:0]  px;

    reg [12:0] lb0 [0:367];
    reg [12:0] lb1 [0:367];
    reg        wbank_r;
    assign lb_q = rbank ? lb1[lb_x] : lb0[lb_x];

    assign spr_a = (state==CLR && clr_i==10'd367) ? 11'd2043 :
                   (state==NEXT) ? (spr_idx - 11'd4) :
                   (state==RDW0) ? (spr_idx + 11'd2) :
                   (state==RDW2) ? (spr_idx + 11'd3) : 11'd0;

    wire       col3 = flipx_r ? ~cellcol : cellcol;
    wire [19:0] rom_a_lin = {code_r, 5'b00000} + {15'b0, col3, rowq_r};
    assign rom_a = rom_a_lin;

    wire [2:0] gpx  = flipx_r ? (3'd7 - px) : px;
    wire [2:0] bsel = 3'd7 - gpx;
    wire [3:0] pen  = { d_p3[bsel], d_p2[bsel], d_p1[bsel], d_p0[bsel] };

    wire [9:0] xbase = {1'b0,sx_r} + (cellcol ? 10'd8 : 10'd0) - 10'd15;
    wire [9:0] xpos  = xbase + {7'b0, px};
    wire       xin   = (xpos < 10'd368);
    wire [8:0] lb_wa = xpos[8:0];

    wire [7:0] sy0    = 8'd240 - spr_q[7:0];
    wire [8:0] py0    = (line_r - {1'b0, sy0}) & 9'h1ff;
    wire       online0= (py0 < 9'd16);
    wire [7:0] sy_c   = 8'd240 - w0_r[7:0];
    wire [8:0] py_c   = (line_r - {1'b0, sy_c}) & 9'h1ff;
    wire [3:0] spr_row= w0_r[15] ? (4'd15 - py_c[3:0]) : py_c[3:0];

    wire [12:0] lb_cur   = wbank_r ? lb1[lb_wa] : lb0[lb_wa];
    wire        lb_empty = (lb_cur[3:0] == 4'd0);
    always @(posedge clk) if (ce) begin
        if (state==CLR) begin
            if (wbank_r) lb1[clr_i[8:0]] <= 13'd0; else lb0[clr_i[8:0]] <= 13'd0;
        end else if (state==PWR && (pen != 4'd0) && xin && lb_empty) begin
            if (wbank_r) lb1[lb_wa] <= {prio_r, color_r, pen};
            else         lb0[lb_wa] <= {prio_r, color_r, pen};
        end
    end

    always @(posedge clk) if (ce) begin
        if (start) begin
            line_r <= line; clr_i <= 10'd0; busy <= 1'b1; wbank_r <= wbank; state <= CLR;
        end else case (state)
            IDLE: ;
            CLR:  begin clr_i <= clr_i + 1'b1; if (clr_i == 10'd367) begin spr_idx <= 11'd2043; state <= RDW0; end end
            RDW0: begin w0_r <= spr_q; state <= online0 ? RDW2 : NEXT; end
            RDW2: begin w2_r <= spr_q; state <= RDW3; end
            RDW3: begin w3_r <= spr_q; state <= TEST; end
            TEST: begin
                flipx_r <= w0_r[14]; flipy_r <= w0_r[15];
                sx_r    <= w2_r[8:0];
                color_r <= {2'b01, w2_r[12:9]};
                prio_r  <= 3'd0;
                code_r  <= {w3_r[0], w3_r[15:2]};
                rowq_r  <= spr_row;
                cellcol <= 1'b0; px <= 3'd0;
                state <= (py_c < 9'd16) ? CADDR : NEXT;
            end
            CADDR: state <= PADDR;
            PADDR: if (gfx_ok) state <= PWR;
            PWR: begin
                if (px == 3'd7) begin
                    if (cellcol==1'b0) begin cellcol <= 1'b1; px <= 3'd0; state <= CADDR; end
                    else state <= NEXT;
                end else begin px <= px + 1'b1; state <= PWR; end
            end
            NEXT: if (spr_idx >= 11'd7) begin spr_idx <= spr_idx - 11'd4; state <= RDW0; end
                  else state <= DON;
            DON:  begin busy <= 1'b0; state <= IDLE; end
            default: state <= IDLE;
        endcase
    end

`ifdef GLASS_SPRDBG

    integer non=0;
    always @(posedge clk) if (ce) begin
        if (start) begin
            if (busy) $display("SPR OVERBUDGET! start con busy line=%0d non_prev=%0d state=%0d spr_idx=%0d", line, non, state, spr_idx);
            non <= 0;
        end else if (state==TEST && (py_c < 9'd16)) non <= non + 1;
        else if (state==DON) $display("SPR line=%0d on-line=%0d (fin OK)", line_r, non);
    end
`endif
    // synthesis translate_off
    integer k;
    initial begin state=IDLE; busy=0; spr_idx=2043; px=0; clr_i=0; wbank_r=0; cellcol=0;
        for (k=0;k<368;k=k+1) begin lb0[k]=0; lb1[k]=0; end end
    // synthesis translate_on
endmodule

`default_nettype wire
