`default_nettype none

module aligator_gae1_sprite (
    input  wire        clk,
    input  wire        ce,
    input  wire        start,
    input  wire [8:0]  line,
    input  wire [15:0] vreg0, vreg1,
    output reg         busy,

    output reg  [14:0] spr_a,
    input  wire [15:0] spr_q,

    output reg  [21:0] rom_a,
    input  wire [7:0]  d_p0, d_p1, d_p2, d_p3,
    input  wire        gfx_ok,

    input  wire [8:0]  lb_x,
    output wire [16:0] lb_q,

    input  wire        wbank,
    input  wire        rbank
);

    localparam [3:0] IDLE=0, CLR=1, RDW1F=2, RDW0=3, RDW2=4, RDW3=5, SETUP=6,
                     D5ADR=7, D5RD=8, FSETL=9, FWL=10, FSETR=11, FWR=12, PWR=13, NEXT=14, DON=15;

    reg [3:0]  state;
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

    reg [7:0]  gl0,gl1,gl2,gl3, gr0,gr1,gr2,gr3;

    reg [16:0] lb0 [0:319];
    reg [16:0] lb1 [0:319];
    assign lb_q = rbank ? lb1[lb_x] : lb0[lb_x];

    wire [14:0] base_word = vreg1[4] ? 15'h800 : 15'h0;
    wire signed [11:0] spradj = -12'sd190 - {11'b0, vreg0[4]};

    wire [4:0] ex      = xflip ? (xsize - 5'd1 - cx) : cx;
    wire [9:0] bx_cell = (sx0 + {1'b0, ex, 4'b0}) & 10'h3ff;

    wire [3:0] gpx   = xflip ? (4'd15 - px) : px;
    wire [2:0] bsel  = 3'd7 - gpx[2:0];
    wire [7:0] p0b   = gpx[3] ? gr0 : gl0;
    wire [7:0] p1b   = gpx[3] ? gr1 : gl1;
    wire [7:0] p2b   = gpx[3] ? gr2 : gl2;
    wire [7:0] p3b   = gpx[3] ? gr3 : gl3;
    wire [3:0] pen   = {p3b[bsel], p2b[bsel], p1b[bsel], p0b[bsel]};
    wire signed [11:0] xpos_s = cell_x0 + $signed({8'b0, px});
    wire       xin   = (xpos_s >= 0) && (xpos_s < 12'sd320);
    wire [8:0] lb_wa = xpos_s[8:0];

    wire [16:0] lb_cur = wbank_r ? lb1[lb_wa] : lb0[lb_wa];
    wire [16:0] lb_new = cell_shadow
        ? {1'b1, pen, (lb_cur[16] ? lb_cur[11:0] : 12'd0)}
        : {1'b1, 4'd0, (cell_idx | {8'b0, pen})};
    wire       do_write = (state==PWR) && (pen != 4'd0) && xin;

    wire [21:0] rom_a_l = {number, 1'b0, gpy};
    wire [21:0] rom_a_r = {number, 1'b1, gpy};

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

    reg        wr_q;
    reg [8:0]  lb_wa_q;
    reg [16:0] lb_new_q;
    always @(posedge clk) if (ce) begin
        wr_q     <= do_write;
        lb_wa_q  <= lb_wa;
        lb_new_q <= lb_new;
        if (state==CLR) begin
            if (wbank_r) lb1[clr_i[8:0]] <= 17'd0; else lb0[clr_i[8:0]] <= 17'd0;
        end else if (wr_q) begin
            if (wbank_r) lb1[lb_wa_q] <= lb_new_q; else lb0[lb_wa_q] <= lb_new_q;
        end
    end

    always @(posedge clk) if (ce) begin
        if (start) begin
            line_r <= line; clr_i <= 10'd0; busy <= 1'b1; wbank_r <= wbank; state <= CLR;
        end else case (state)
            IDLE: ;
            CLR: begin
                clr_i <= clr_i + 1'b1;
                if (clr_i == 10'd319) begin spr_e <= 10'd0; state <= RDW1F; end
            end

            RDW1F: begin
                sy0   <= spr_q[8:0]; en_r <= spr_q[9];
                yflip <= spr_q[10]; xflip <= spr_q[11];
                ysize <= {1'b0, spr_q[15:12]} + 5'd1;
                state <= proceed_w ? RDW0 : NEXT;
            end
            RDW0: begin
                bank_hi <= spr_q[8:0]; color_base <= spr_q[15:9];
                state <= RDW2;
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
                cell_shadow <= ((color_base + {3'b0, spr_q[15:12]}) == 7'h7f);
                state <= FSETL;
            end
            FSETL: begin rom_a <= rom_a_l; state <= FWL; end
            FWL:   if (gfx_ok) begin gl0<=d_p0; gl1<=d_p1; gl2<=d_p2; gl3<=d_p3; rom_a<=rom_a_r; state<=FSETR; end
            FSETR: state <= FWR;
            FWR:   if (gfx_ok) begin gr0<=d_p0; gr1<=d_p1; gr2<=d_p2; gr3<=d_p3; px<=4'd0; bx<=bx_cell;
                       cell_x0 <= $signed({2'b0, bx_cell}) + spradj;
                       state<=PWR; end
            PWR: begin
                if (px == 4'd15) begin
                    if (cx + 5'd1 < xsize) begin cx <= cx + 5'd1; state <= D5ADR; end
                    else state <= NEXT;
                end else px <= px + 4'd1;
            end
            NEXT: if (spr_e < 10'd511) begin
                      spr_e <= spr_e + 10'd1;
                      state <= RDW1F;
                  end else state <= DON;
            DON:  begin busy <= 1'b0; state <= IDLE; end
            default: state <= IDLE;
        endcase
    end

    // synthesis translate_off
    integer k;
    initial begin state=IDLE; busy=0; spr_e=0; px=0; clr_i=0; wbank_r=0; cx=0; number=0; wr_q=0;
        for (k=0;k<320;k=k+1) begin lb0[k]=0; lb1[k]=0; end end
    // synthesis translate_on
endmodule

`default_nettype wire
