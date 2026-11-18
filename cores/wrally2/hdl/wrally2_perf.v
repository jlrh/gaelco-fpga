`default_nettype none

module wrally2_perf #(
    parameter [23:0] A_IDLE   = 24'hFE8118,
    parameter [15:0] LOW_THR  = 16'd256,
    parameter integer UART_DIV = 417
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        frame,
    input  wire [23:1] eab,
    input  wire        asn,
    input  wire [ 2:0] fc,
    input  wire        rwn,
    input  wire [ 1:0] dsn,
    input  wire [15:0] wdata,
    input  wire        tm_ovr,
    input  wire        spr_ovr_tog,
    input  wire        spr2_ovr_tog,
    input  wire [ 7:0] debug_bus,

    input  wire [ 5:0] joy1, joy2,
    input  wire        tfb_frame,
    input  wire        tfb_vbl,
    output reg  [ 7:0] debug_view,
    output reg         txd
);
    localparam [15:0] SAT16 = 16'hFFFF;

    reg frame_d;
    always @(posedge clk) frame_d <= frame;
    wire fr = frame & ~frame_d;

    wire wcyc = ~asn & ~rwn & (dsn != 2'b11);
    reg  wcyc_d;
    reg  [23:1] wa_q; reg [15:0] wd_q; reg [1:0] wds_q;
    always @(posedge clk) begin
        wcyc_d <= wcyc;
        if (wcyc) begin wa_q <= eab; wd_q <= wdata; wds_q <= dsn; end
    end
    wire wr     = wcyc_d & ~wcyc;
    wire wr_hi  = wr & (wa_q == A_IDLE[23:1]);
    wire wr_lo  = wr & (wa_q == A_IDLE[23:1] + 23'd1);
    reg  [15:0] w_hi, w_lo;
    wire [15:0] n_hi = wr_hi ? {wds_q[1] ? w_hi[15:8] : wd_q[15:8], wds_q[0] ? w_hi[7:0] : wd_q[7:0]} : w_hi;
    wire [15:0] n_lo = wr_lo ? {wds_q[1] ? w_lo[15:8] : wd_q[15:8], wds_q[0] ? w_lo[7:0] : wd_q[7:0]} : w_lo;
    wire [31:0] n_val = {n_hi, n_lo};
    reg  [31:0] prev;
    wire hit_exit = (wr_hi | wr_lo) & (n_val == 32'd0) & (prev != 32'd0);
    wire [15:0] idle_cnt = (|prev[31:16]) ? 16'hFFFF : prev[15:0];
    wire hit_late = hit_exit & (idle_cnt < LOW_THR);

    reg [2:0] spr_s, spr2_s;
    always @(posedge clk) begin spr_s <= {spr_s[1:0], spr_ovr_tog}; spr2_s <= {spr2_s[1:0], spr2_ovr_tog}; end
    wire spr_ev  = spr_s[2]  ^ spr_s[1];
    wire spr2_ev = spr2_s[2] ^ spr2_s[1];

    wire clr = debug_bus[7];

    reg [9:0] pre = 10'd0;
    always @(posedge clk) pre <= pre + 10'd1;
    wire tick = &pre;
    reg  [5:0] j1_d, j2_d;
    reg        asn_d;
    always @(posedge clk) begin j1_d <= joy1; j2_d <= joy2; asn_d <= asn; end
    wire rd_start = ~asn & asn_d & rwn;
    wire rd_in0   = rd_start & (eab == 23'h180000);
    wire rd_in2   = rd_start & (eab == 23'h180002);
    reg        p1_run, p2_run;
    reg [15:0] p1_t, p2_t, lag_last, lag_max, lag_n;
    reg  [2:0] vbl_s;
    always @(posedge clk) vbl_s <= {vbl_s[1:0], tfb_vbl};
    wire       hdmi_vbl = vbl_s[1] & ~vbl_s[2];
    reg        fa_run;
    reg [15:0] fa_t, fb_last, fb_min, fb_max;
    always @(posedge clk) begin
        if (rst) begin
            p1_run <= 0; p2_run <= 0; p1_t <= 0; p2_t <= 0; lag_last <= 0; lag_max <= 0; lag_n <= 0;
            fa_run <= 0; fa_t <= 0; fb_last <= 0; fb_min <= SAT16; fb_max <= 0;
        end else begin

            if (rd_in0 && p1_run) begin
                p1_run <= 0; lag_last <= p1_t; if (p1_t > lag_max) lag_max <= p1_t; lag_n <= inc16(lag_n);
            end else if (joy1 != j1_d && !p1_run) begin p1_run <= 1; p1_t <= 0; end
            else if (tick && p1_run) p1_t <= inc16(p1_t);

            if (rd_in2 && p2_run) begin
                p2_run <= 0; lag_last <= p2_t; if (p2_t > lag_max) lag_max <= p2_t; lag_n <= inc16(lag_n);
            end else if (joy2 != j2_d && !p2_run) begin p2_run <= 1; p2_t <= 0; end
            else if (tick && p2_run) p2_t <= inc16(p2_t);

            if (tfb_frame) begin fa_run <= 1; fa_t <= 0; end
            else if (hdmi_vbl && fa_run) begin
                fa_run <= 0; fb_last <= fa_t;
                if (fa_t < fb_min) fb_min <= fa_t;
                if (fa_t > fb_max) fb_max <= fa_t;
            end else if (tick && fa_run) fa_t <= inc16(fa_t);
            if (clr) begin lag_max <= 0; lag_n <= 0; fb_min <= SAT16; fb_max <= 0; end
        end
    end

    reg [15:0] idle_last, idle_min, idle_max;
    reg [15:0] late_cnt, lost_cnt, spr_frames, tm_frames, frames, spr2_frames;
    reg [ 7:0] spr_lines, spr_last, spr_max, tm_lines, tm_last, tm_max, spr2_lines, spr2_last, spr2_max;
    reg        exit_this, late_this;
    reg        exit_last, late_last;
    reg        send;

    function [15:0] inc16(input [15:0] v); inc16 = (v == SAT16) ? v : v + 16'd1; endfunction
    function [ 7:0] inc8 (input [ 7:0] v); inc8  = (&v) ? v : v + 8'd1;          endfunction

    always @(posedge clk) begin
        send <= 1'b0;
        if (rst) begin
            w_hi <= 0; w_lo <= 0; prev <= 0; idle_last <= 0; idle_min <= SAT16; idle_max <= 0;
            late_cnt <= 0; lost_cnt <= 0; spr_frames <= 0; tm_frames <= 0; frames <= 0;
            spr_lines <= 0; spr_last <= 0; spr_max <= 0; tm_lines <= 0; tm_last <= 0; tm_max <= 0;
            spr2_lines <= 0; spr2_last <= 0; spr2_max <= 0; spr2_frames <= 0;
            exit_this <= 0; late_this <= 0; exit_last <= 0; late_last <= 0;
        end else begin
            w_hi <= n_hi; w_lo <= n_lo;
            if (wr_hi | wr_lo) begin
                if (n_val != 32'd0) prev <= n_val;
                else                prev <= 32'd0;
            end
            if (hit_exit) begin
                idle_last <= idle_cnt;
                if (idle_cnt < idle_min) idle_min <= idle_cnt;
                if (idle_cnt > idle_max) idle_max <= idle_cnt;
                exit_this <= 1'b1;
            end
            if (hit_late) begin late_cnt <= inc16(late_cnt); late_this <= 1'b1; end
            if (spr_ev)  spr_lines  <= inc8(spr_lines);
            if (spr2_ev) spr2_lines <= inc8(spr2_lines);
            if (tm_ovr) tm_lines  <= inc8(tm_lines);

            if (fr) begin
                frames   <= inc16(frames);
                if (!exit_this) lost_cnt <= inc16(lost_cnt);
                spr_last <= spr_lines;  if (spr_lines > spr_max) spr_max <= spr_lines;
                tm_last  <= tm_lines;   if (tm_lines  > tm_max)  tm_max  <= tm_lines;
                if (spr_lines != 0) spr_frames <= inc16(spr_frames);
                spr2_last <= spr2_lines; if (spr2_lines > spr2_max) spr2_max <= spr2_lines;
                if (spr2_lines != 0) spr2_frames <= inc16(spr2_frames);
                spr2_lines <= spr2_ev ? 8'd1 : 8'd0;
                if (tm_lines  != 0) tm_frames  <= inc16(tm_frames);
                spr_lines <= spr_ev ? 8'd1 : 8'd0;
                tm_lines  <= tm_ovr ? 8'd1 : 8'd0;
                send      <= 1'b1;
            end
            if (fr) begin
                exit_last <= exit_this; late_last <= late_this;
                exit_this <= hit_exit;  late_this <= hit_late;
            end

            if (clr) begin
                idle_min <= SAT16; idle_max <= 0; late_cnt <= 0; lost_cnt <= 0;
                spr_max <= 0; tm_max <= 0; spr_frames <= 0; tm_frames <= 0; frames <= 0;
                spr2_max <= 0; spr2_frames <= 0;
            end
        end
    end

    always @(posedge clk) begin
        case (debug_bus[3:0])
            4'h0: debug_view <= idle_last[ 7:0];
            4'h1: debug_view <= idle_last[15:8];
            4'h2: debug_view <= idle_min [ 7:0];
            4'h3: debug_view <= idle_min [15:8];
            4'h4: debug_view <= idle_max [ 7:0];
            4'h5: debug_view <= idle_max [15:8];
            4'h6: debug_view <= (|late_cnt[15:8]) ? 8'hFF : late_cnt[7:0];
            4'h7: debug_view <= (|lost_cnt[15:8]) ? 8'hFF : lost_cnt[7:0];
            4'h8: debug_view <= spr_last;
            4'h9: debug_view <= spr_max;
            4'hA: debug_view <= (|spr_frames[15:8]) ? 8'hFF : spr_frames[7:0];
            4'hB: debug_view <= tm_last;
            4'hC: debug_view <= tm_max;
            4'hD: debug_view <= (|tm_frames[15:8]) ? 8'hFF : tm_frames[7:0];
            4'hE: debug_view <= spr2_last;
            default: debug_view <= spr2_max;
        endcase
    end

    localparam integer NB = 40;
    wire [8*NB-1:0] pkt = {
        8'h0A,
        {6'd0, late_last, exit_last},
        fb_max, fb_min, fb_last, lag_n, lag_max, lag_last,
        spr2_frames, spr2_max, spr2_last,
        tm_frames, tm_max, tm_last,
        spr_frames, spr_max, spr_last,
        lost_cnt, late_cnt, idle_max, idle_min, idle_last, frames,
        8'hAA, 8'h55 };

    reg [8*NB-1:0] buf_q;
    reg [ 5:0]     bidx;
    reg [ 3:0]     bitn;
    reg [12:0]     div;
    reg            busy;
    always @(posedge clk) begin
        if (rst) begin
            txd <= 1'b1; busy <= 1'b0; bidx <= 0; bitn <= 0; div <= 0;
        end else if (!busy) begin
            txd <= 1'b1;
            if (send) begin busy <= 1'b1; buf_q <= pkt; bidx <= 0; bitn <= 0; div <= 0; end
        end else if (div != UART_DIV-1) begin
            div <= div + 13'd1;
        end else begin
            div <= 0;
            case (bitn)
                4'd0:    txd <= 1'b0;
                4'd9:    txd <= 1'b1;
                default: txd <= buf_q[8*bidx + bitn - 1];
            endcase
            if (bitn == 4'd9) begin
                bitn <= 0;
                if (bidx == NB-1) busy <= 1'b0;
                else              bidx <= bidx + 6'd1;
            end else bitn <= bitn + 4'd1;
        end
    end
endmodule
