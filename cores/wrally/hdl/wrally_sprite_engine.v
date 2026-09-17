`default_nettype none

module wrally_sprite_engine (
    input  wire        clk,
    input  wire        ce,
    input  wire        start,
    input  wire [8:0]  line,
    output reg         busy,
    output reg         done,

    output wire [10:0] spr_a,
    input  wire [15:0] spr_q,

    output wire [18:0] rom_a,
    input  wire [7:0]  d_i07, d_i09, d_i11, d_i13,
    input  wire        gfx_ok,

    input  wire [9:0]  lb_x,
    output wire [11:0] lb_q,

    output wire        lb_high,

    input  wire        wbank,
    input  wire        rbank
);
    localparam [3:0] IDLE=0, CLR=1, RDW0=2, RDW2=3, RDW3=4, TEST=5, PADDR=6, PWR=7, NEXT=8, DON=9;

    reg [3:0]  state;
    reg [10:0] spr_idx;
    reg [9:0]  clr_i;
    reg [8:0]  line_r;
    reg [15:0] w0_r, w2_r, w3_r;
    reg        flipx_r, flipy_r;
    reg [9:0]  sx_r;
    reg [3:0]  color_r, gpy_r, px;
    reg [13:0] code_r;

    reg [11:0] lb0 [0:367];
    reg [11:0] lb1 [0:367];
    reg       lb0h [0:367];
    reg       lb1h [0:367];
    reg       wbank_r;
    reg       high_r;
    reg       shad_r;
    assign lb_q    = rbank ? lb1[lb_x[8:0]]  : lb0[lb_x[8:0]];
    assign lb_high = rbank ? lb1h[lb_x[8:0]] : lb0h[lb_x[8:0]];

    assign spr_a = (state==CLR && clr_i==10'd367) ? 11'd3 :
                   (state==NEXT) ? (spr_idx + 11'd4) :
                   (state==RDW0) ? (spr_idx + 11'd2) :
                   (state==RDW2) ? (spr_idx + 11'd3) : 11'd0;

    wire [3:0] gpx = flipx_r ? (4'd15 - px) : px;
    assign rom_a = {code_r, 5'b00000} + {14'b0, gpx[3], gpy_r};

    wire [2:0] bsel = 3'd7 - gpx[2:0];
    wire [3:0] pen  = { d_i07[bsel], d_i09[bsel], d_i11[bsel], d_i13[bsel] };
    wire [9:0] sumx = (sx_r + {6'b0, px}) & 10'h3ff;
    wire [9:0] xpos = (sumx - 10'd15) & 10'h3ff;
    wire       xin  = (xpos >= 10'd8) && (xpos <= 10'd375);

    wire        spr_on = shad_r ? pen[3] : (pen != 4'd0);
    wire [11:0] lb_wd  = shad_r ? {1'b1, pen[2:0], 8'd0}
                                : {1'b0, 3'd0, color_r, pen};

    wire [9:0]  lb_wa    = (xpos - 10'd8);
    wire [11:0] lb_cur   = wbank_r ? lb1[lb_wa] : lb0[lb_wa];
    wire        cur_norm = (lb_cur[11]==1'b0) && (lb_cur[3:0]!=4'd0);
    wire [11:0] lb_mrg   = (shad_r && cur_norm) ? {1'b1, pen[2:0], lb_cur[7:0]} : lb_wd;
    wire        lb_keep  = shad_r && cur_norm;

    wire [7:0] sy_c   = 8'd240 - w0_r[7:0];
    wire [8:0] py_c   = (line_r - {1'b0, sy_c}) & 9'h1ff;
    wire       on_line= (py_c < 9'd16);

    wire [7:0] sy0    = 8'd240 - spr_q[7:0];
    wire [8:0] py0    = (line_r - {1'b0, sy0}) & 9'h1ff;
    wire       online0= (py0 < 9'd16);

    always @(posedge clk) if (ce) begin
        if (state==CLR) begin
            if (wbank_r) begin lb1[clr_i[8:0]] <= 12'd0; lb1h[clr_i[8:0]] <= 1'b0; end
            else         begin lb0[clr_i[8:0]] <= 12'd0; lb0h[clr_i[8:0]] <= 1'b0; end
        end else if (state==PWR && spr_on && xin) begin
            if (wbank_r) begin lb1[lb_wa] <= lb_mrg; if(!lb_keep) lb1h[lb_wa] <= high_r; end
            else         begin lb0[lb_wa] <= lb_mrg; if(!lb_keep) lb0h[lb_wa] <= high_r; end
        end
    end

    always @(posedge clk) if (ce) begin
        done <= 1'b0;
        if (start) begin
            line_r <= line; clr_i <= 10'd0; busy <= 1'b1; wbank_r <= wbank; state <= CLR;
        end else case (state)
            IDLE: ;
            CLR:  begin clr_i <= clr_i + 1'b1; if (clr_i == 10'd367) begin spr_idx <= 11'd3; state <= RDW0; end end

            RDW0: begin w0_r <= spr_q; state <= online0 ? RDW2 : NEXT; end
            RDW2: begin w2_r <= spr_q; state <= RDW3; end
            RDW3: begin w3_r <= spr_q; state <= TEST; end
            TEST: begin
                flipx_r <= w0_r[14]; flipy_r <= w0_r[15];
                sx_r    <= w2_r[9:0]; color_r <= w2_r[13:10]; code_r <= w3_r[13:0];
                high_r  <= (w3_r[13:0] >= 14'h3700);
                shad_r  <= w2_r[14];
                if (on_line) begin
                    gpy_r <= w0_r[15] ? (4'd15 - py_c[3:0]) : py_c[3:0];
                    px    <= 4'd0;
                    state <= PADDR;
                end else state <= NEXT;
            end

            PADDR: if (gfx_ok) state <= PWR;
            PWR:   begin
                if (px == 4'd15)            state <= NEXT;
                else if (px[2:0] == 3'd7) begin px <= px + 1'b1; state <= PADDR; end
                else                       begin px <= px + 1'b1; state <= PWR;   end
            end
            NEXT:  if (spr_idx < 11'd2041) begin spr_idx <= spr_idx + 11'd4; state <= RDW0; end
                   else state <= DON;
            DON:   begin done <= 1'b1; busy <= 1'b0; state <= IDLE; end
            default: state <= IDLE;
        endcase
    end

    // synthesis translate_off
    integer k;
    initial begin state=IDLE; busy=0; done=0; spr_idx=3; px=0; clr_i=0; wbank_r=0; high_r=0; shad_r=0;
        for (k=0;k<368;k=k+1) begin lb0[k]=0; lb1[k]=0; lb0h[k]=0; lb1h[k]=0; end end
    // synthesis translate_on

`ifdef SPR_OVDBG

    integer n_over=0, n_line=0, cyc=0, idx_at_start=0, n_online_done=0;
    reg [8:0] last_line=0;
    always @(posedge clk) if (ce) begin
        cyc <= cyc + 1;
        if (start) begin
            n_line <= n_line + 1;
            if (state!=IDLE && state!=DON) begin
                n_over <= n_over + 1;

                $display("OVR linea=%0d TRUNCADA en spr_idx=%0d (proc %0d sprites) state=%0d cyc=%0d",
                         line_r, spr_idx, (spr_idx-3)/4, state, cyc);
            end
            idx_at_start <= spr_idx;
        end
        if (state==DON) $display("DONE linea=%0d spr_idx_final=%0d (proc %0d) cyc=%0d",
                                 line_r, spr_idx, (spr_idx-3)/4, cyc);

        if (start && line==9'd0) $display("=== SPR_OVDBG resumen: lineas=%0d overruns=%0d ===", n_line, n_over);
    end
`endif

`ifdef SPR_BARDBG

    always @(posedge clk) if (ce) begin

        if (state==TEST && spr_idx==11'd259)
            $display("BARTEST line=%0d on_line=%b sy_c=%0d py_c=%0d w0=%h w2=%h w3=%h", line_r, on_line, sy_c, py_c, w0_r, w2_r, w3_r);
        if (state==PWR && spr_on && xin && spr_idx==11'd259 && px==4'd0)
            $display("BARWR line=%0d lb_wa=%0d xpos=%0d py_c(gpy)=%0d", line_r, lb_wa, xpos, gpy_r);

        if (state==CLR && clr_i==10'd0)
            $display("CLRSTART line=%0d wbank_r=%b lb0[290]=%h lb1[290]=%h", line_r, wbank_r, lb0[290], lb1[290]);
    end
`endif

`ifdef SPR_PXDBG

    integer nlt=0;
    always @(posedge clk) if (ce) begin
        if (state==TEST && line_r==9'd116) begin
            $display("SPX linea=%0d online=%b sx=%0d code=%h flipx=%b", line_r, on_line, sx_r, code_r, flipx_r);
        end
        if (state==PWR && line_r==9'd116 && (px==4'd0 || px==4'd7 || px==4'd8 || px==4'd15)) begin
            $display("  SPXPWR code=%h px=%0d gpx=%0d rom_a=%h gfx=%h_%h_%h_%h pen=%h spron=%b xin=%b xpos=%0d",
                     code_r, px, gpx, rom_a, d_i07,d_i09,d_i11,d_i13, pen, spr_on, xin, xpos);
        end
    end
`endif
endmodule

`default_nettype wire
