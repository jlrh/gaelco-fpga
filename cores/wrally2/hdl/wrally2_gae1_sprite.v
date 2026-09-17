`default_nettype none

module wrally2_gae1_sprite #(

    parameter LBDEPTH = 512
)(
    input  wire        clk,
    input  wire        ce,
    input  wire        start,
    input  wire [8:0]  line,
    input  wire        index,
    input  wire        twin,
    input  wire [15:0] vreg0, vreg1,
    output reg         busy,

    output reg  [14:0] spr_a,
    input  wire [15:0] spr_q,

    output reg  [21:0] rom_a,
    input  wire [7:0]  d_p0, d_p1, d_p2, d_p3,
    input  wire        gfx_ok,

    input  wire [9:0]  lb_x,
    output wire [16:0] lb_q,

    input  wire        wbank,
    input  wire        rbank
);

    localparam [4:0] IDLE=0, CLR=1, RDW1F=2, RDW0=3, RDW2=4, RDW3=5, SETUP=6,
                     D5ADR=7, D5RD=8, FSETL=9, FWL=10, FSETL4=11, FWL4=12,
                     FSETR=13, FWR=14, FSETR4=15, FWR4=16, PWR=17, NEXT=18, DON=19;

    reg [4:0]  state;
    reg [9:0]  spr_e;
    reg [9:0]  clr_i;
    reg [8:0]  line_r;
    reg        wbank_r;

    reg [8:0]  bank_hi;
    reg [6:0]  color_base;
    reg [8:0]  sy0;
    reg        en_r;
    reg        yflip, xflip;
    reg [4:0]  ysize, xsize;
    reg [9:0]  sx0;
    reg [14:0] ptr_w;
    reg [3:0]  ydata;
    reg [3:0]  gpy;

    reg [4:0]  cx;
    reg [11:0] cell_idx;
    reg        cell_shadow;
    reg [16:0] number;
    reg [3:0]  px;
    reg [9:0]  bx;
    reg signed [11:0] cell_x0;
    reg [8:0]  row_off;

    reg [7:0]  gl0,gl1,gl2,gl3,gl4, gr0,gr1,gr2,gr3,gr4;

    localparam LBAW = $clog2(LBDEPTH);
    (* ramstyle = "no_rw_check, M10K" *) reg [16:0] lb0 [0:LBDEPTH-1];
    (* ramstyle = "no_rw_check, M10K" *) reg [16:0] lb1 [0:LBDEPTH-1];
    wire        is0w   = (wbank_r==1'b0);
    wire [LBAW-1:0] lb0_ra = is0w ? lb_wa[LBAW-1:0] : lb_x[LBAW-1:0];
    wire [LBAW-1:0] lb1_ra = is0w ? lb_x[LBAW-1:0]  : lb_wa[LBAW-1:0];
    reg  [16:0] lb0_rq, lb1_rq;
    assign      lb_q   = rbank ? lb1_rq : lb0_rq;

    wire [14:0] base_word = vreg1[4] ? 15'h800 : 15'h0;
    wire signed [11:0] spradj = -12'sd126 - {11'b0, vreg0[4]};

    wire [4:0] ex      = xflip ? (xsize - 5'd1 - cx) : cx;
    wire [9:0] bx_cell = (sx0 + {1'b0, ex, 4'b0}) & 10'h3ff;

    wire signed [11:0] xoff_cell = (twin & color_base[6]) ? 12'sd384 : 12'sd0;

    reg [7:0]  gld0,gld1,gld2,gld3,gld4, grd0,grd1,grd2,grd3,grd4;
    reg signed [11:0] cx0_d, xoff_d; reg [11:0] idx_d; reg shadow_d, xflip_d;
    reg [3:0]  px_d; reg draw_busy; reg draw_start;

    wire [3:0] gpx   = xflip_d ? (4'd15 - px_d) : px_d;
    wire [2:0] bsel  = 3'd7 - gpx[2:0];
    wire [7:0] p0b   = gpx[3] ? grd0 : gld0;
    wire [7:0] p1b   = gpx[3] ? grd1 : gld1;
    wire [7:0] p2b   = gpx[3] ? grd2 : gld2;
    wire [7:0] p3b   = gpx[3] ? grd3 : gld3;
    wire [7:0] p4b   = gpx[3] ? grd4 : gld4;
    wire [4:0] pen   = {p4b[bsel], p3b[bsel], p2b[bsel], p1b[bsel], p0b[bsel]};
    wire signed [11:0] xraw  = cx0_d + $signed({8'b0, px_d});
    wire       xin   = (xraw >= 0) && (xraw < 12'sd384);
    wire [9:0] lb_wa = (xraw + xoff_d);

    wire       pen_ok   = shadow_d ? (pen != 5'd0 && !pen[4]) : (pen != 5'd0);
    wire       do_write = draw_busy && pen_ok && xin;
    reg        dw_s1, sh_s1; reg [4:0] pen_s1; reg [11:0] idx_s1; reg [LBAW-1:0] wa_s1;
    reg        dw_s2; reg [16:0] wd_s2; reg [LBAW-1:0] wa_s2;
    reg        clr_we_q; reg [LBAW-1:0] clr_wa_q;
    wire [16:0] lb_cur  = is0w ? lb0_rq : lb1_rq;
    wire [16:0] lb_new  = sh_s1
        ? {1'b1, pen_s1[3:0], (lb_cur[16] ? lb_cur[11:0] : 12'd0)}
        : {1'b1, 4'd0, (idx_s1 | {7'b0, pen_s1})};

    wire [21:0] rom_a_l  = {1'b0, number[15:0], 1'b0, gpy};
    wire [21:0] rom_a_l4 = {1'b1, number[15:0], 1'b0, gpy};
    wire [21:0] rom_a_r  = {1'b0, number[15:0], 1'b1, gpy};
    wire [21:0] rom_a_r4 = {1'b1, number[15:0], 1'b1, gpy};

    wire [8:0]  rely    = (line_r - sy0) & 9'h1ff;
    wire        covered = (rely < {ysize, 4'b0});

    wire [8:0]  sy0_w     = spr_q[8:0];
    wire [4:0]  ysize_w   = {1'b0, spr_q[15:12]} + 5'd1;
    wire [8:0]  rely_w    = (line_r - sy0_w) & 9'h1ff;
    wire        proceed_w = spr_q[9] & (rely_w < {ysize_w, 4'b0});

    wire [14:0] d5_addr = (ptr_w + {6'b0, row_off} + {10'b0, cx}) & 15'h7fff;
    always @(*) begin
        case (state)
            CLR:   spr_a = base_word + 15'd1;
            RDW1F: spr_a = base_word + {3'b0, spr_e, 2'b00};
            RDW0:  spr_a = base_word + {3'b0, spr_e, 2'b10};
            RDW2:  spr_a = base_word + {3'b0, spr_e, 2'b11};
            D5ADR: spr_a = d5_addr;
            NEXT:  spr_a = base_word + {3'b0, (spr_e + 10'd1), 2'b01};
            default: spr_a = base_word + {3'b0, spr_e, 2'b00};
        endcase
    end

    always @(posedge clk) if (ce) begin

        lb0_rq <= lb0[lb0_ra];
        lb1_rq <= lb1[lb1_ra];

        dw_s1 <= do_write; sh_s1 <= shadow_d; pen_s1 <= pen; idx_s1 <= idx_d; wa_s1 <= lb_wa[LBAW-1:0];
        dw_s2 <= dw_s1;    wd_s2 <= lb_new;       wa_s2  <= wa_s1;

        clr_we_q <= (state==CLR); clr_wa_q <= clr_i[LBAW-1:0];

        if (clr_we_q) begin
            if (is0w) lb0[clr_wa_q] <= 17'd0; else lb1[clr_wa_q] <= 17'd0;
        end else if (dw_s2) begin
            if (is0w) lb0[wa_s2] <= wd_s2; else lb1[wa_s2] <= wd_s2;
        end
    end

    always @(posedge clk) if (ce) begin
        if (start)           draw_busy <= 1'b0;

        else if (draw_start) begin px_d <= 4'd0; draw_busy <= 1'b1; end
        else if (draw_busy)  begin
            if (px_d == 4'd15) draw_busy <= 1'b0;
            else               px_d <= px_d + 4'd1;
        end
    end

    // synthesis translate_off
    `ifdef WRALLY2_SPRPROF
    integer c_clr=0, c_fetch=0, c_pwr=0, c_iter=0, c_cells=0;
    always @(posedge clk) if (ce && !start) begin
        if (state==CLR) c_clr <= c_clr+1;
        else if (state>=FSETL && state<=FWR4) c_fetch <= c_fetch+1;
        else if (state!=IDLE && state!=DON) c_iter <= c_iter+1;
        if (draw_busy) c_pwr <= c_pwr+1;
        if (draw_start) c_cells <= c_cells+1;
    end
    `endif
    // synthesis translate_on

    always @(posedge clk) if (ce) begin
        draw_start <= 1'b0;
        if (start) begin
            // synthesis translate_off
            `ifdef WRALLY2_SPRPROF
            if (state != IDLE && state != DON)
                $display("SPRCUT line=%0d cut spr_e=%0d st=%0d | clr=%0d fetch=%0d pwr=%0d iter=%0d cells=%0d tot=%0d",
                         line_r, spr_e, state, c_clr, c_fetch, c_pwr, c_iter, c_cells, c_clr+c_fetch+c_pwr+c_iter);
            else
                $display("SPROK  line=%0d fin spr_e=%0d | clr=%0d fetch=%0d pwr=%0d iter=%0d cells=%0d tot=%0d",
                         line_r, spr_e, c_clr, c_fetch, c_pwr, c_iter, c_cells, c_clr+c_fetch+c_pwr+c_iter);
            c_clr<=0; c_fetch<=0; c_pwr<=0; c_iter<=0; c_cells<=0;
            `endif
            // synthesis translate_on
            line_r <= line; clr_i <= 10'd0; busy <= 1'b1; wbank_r <= wbank; state <= CLR;
        end else case (state)
            IDLE: ;
            CLR: begin
                clr_i <= clr_i + 1'b1;
                if (clr_i == (twin ? 10'd767 : 10'd383)) begin spr_e <= 10'd0; state <= RDW1F; end
            end

            RDW1F: begin
                sy0   <= spr_q[8:0]; en_r <= spr_q[9];
                yflip <= spr_q[10]; xflip <= spr_q[11];
                ysize <= {1'b0, spr_q[15:12]} + 5'd1;
                state <= proceed_w ? RDW0 : NEXT;
            end
            RDW0: begin
                bank_hi <= spr_q[8:0]; color_base <= spr_q[15:9];

                state <= (~twin & (spr_q[15] != index)) ? NEXT : RDW2;
            end
            RDW2: begin
                sx0   <= spr_q[9:0];
                xsize <= {1'b0, spr_q[15:12]} + 5'd1;
                state <= RDW3;
            end
            RDW3: begin
                ptr_w <= spr_q[15:1];
                state <= SETUP;
            end
            SETUP: begin
                ydata   <= yflip ? (ysize[3:0] - 4'd1 - rely[7:4]) : rely[7:4];
                row_off <= (yflip ? (ysize[3:0] - 4'd1 - rely[7:4]) : rely[7:4]) * xsize;
                gpy     <= yflip ? (4'd15 - rely[3:0])             : rely[3:0];
                cx      <= 5'd0;
                state   <= D5ADR;
            end

            D5ADR: state <= D5RD;
            D5RD: begin
                number      <= {bank_hi, 10'b0} + {7'b0, spr_q[11:0]};
                cell_idx    <= {(color_base + {3'b0, spr_q[15:12]}), 5'b0};
                cell_shadow <= (((color_base + {3'b0, spr_q[15:12]}) & 7'h3f) == 7'h3f);
                state <= FSETL;
            end

            FSETL:  begin rom_a <= rom_a_l;  state <= FWL; end

            FWL:    if (gfx_ok) begin gl0<=d_p0; gl1<=d_p1; gl2<=number[15]?8'd0:d_p2; gl3<=number[15]?8'd0:d_p3; rom_a<=rom_a_l4; state<=FSETL4; end
            FSETL4: state <= FWL4;
            FWL4:   if (gfx_ok) begin gl4<=d_p0; rom_a<=rom_a_r; state<=FSETR; end
            FSETR:  state <= FWR;
            FWR:    if (gfx_ok) begin gr0<=d_p0; gr1<=d_p1; gr2<=number[15]?8'd0:d_p2; gr3<=number[15]?8'd0:d_p3; rom_a<=rom_a_r4; state<=FSETR4; end
            FSETR4: state <= FWR4;

            FWR4:   if (gfx_ok && !draw_busy) begin
                       gr4<=d_p0;
                       gld0<=gl0; gld1<=gl1; gld2<=gl2; gld3<=gl3; gld4<=gl4;
                       grd0<=gr0; grd1<=gr1; grd2<=gr2; grd3<=gr3; grd4<=d_p0;
                       cx0_d   <= $signed({2'b0, bx_cell}) + spradj;
                       idx_d   <= cell_idx; shadow_d <= cell_shadow; xflip_d <= xflip; xoff_d <= xoff_cell;
                       draw_start <= 1'b1;
                       if (cx + 5'd1 < xsize) begin cx <= cx + 5'd1; state <= D5ADR; end
                       else state <= NEXT;
                   end
            NEXT: if (spr_e < 10'd511) begin
                      spr_e <= spr_e + 10'd1;
                      state <= RDW1F;
                  end else state <= DON;

            DON:  if (!draw_busy && !dw_s1 && !dw_s2) begin busy <= 1'b0; state <= IDLE; end
            default: state <= IDLE;
        endcase
    end

    // synthesis translate_off
    integer k;
    initial begin state=IDLE; busy=0; spr_e=0; px=0; clr_i=0; wbank_r=0; cx=0; number=0;
        dw_s1=0; dw_s2=0; clr_we_q=0; lb0_rq=0; lb1_rq=0; wd_s2=0; wa_s2=0;
        draw_busy=0; draw_start=0; px_d=0;
        for (k=0;k<LBDEPTH;k=k+1) begin lb0[k]=0; lb1[k]=0; end end
    // synthesis translate_on
endmodule

`default_nettype wire
