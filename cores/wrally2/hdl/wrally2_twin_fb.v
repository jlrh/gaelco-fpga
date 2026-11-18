`default_nettype none

module wrally2_twin_fb #(
    parameter [6:0]  MEM_BASE = 7'b0010010,
    parameter [11:0] W        = 12'd384,
    parameter [11:0] H        = 12'd240
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,

    input  wire        pix_we,
    input  wire [8:0]  pix_x,
    input  wire [8:0]  pix_y,
    input  wire [14:0] pix_rgb,
    input  wire        pix_frame,

    output wire        FB_EN,
    output wire [4:0]  FB_FORMAT,
    output wire [11:0] FB_WIDTH,
    output wire [11:0] FB_HEIGHT,
    output wire [31:0] FB_BASE,
    output wire [13:0] FB_STRIDE,
    input  wire        FB_VBL,
    input  wire        FB_LL,

    output wire        DDRAM_CLK,
    input  wire        DDRAM_BUSY,
    output wire [7:0]  DDRAM_BURSTCNT,
    output wire [28:0] DDRAM_ADDR,
    output wire [63:0] DDRAM_DIN,
    output wire [7:0]  DDRAM_BE,
    output wire        DDRAM_WE,
    output wire        DDRAM_RD
);
    localparam [13:0] STRIDE = {W, 2'b00};

    function [1:0] buf_next(input [1:0] a, input [1:0] b);
        begin
            buf_next = 2'd1;
            if ((a==0 && b==1) || (a==1 && b==0)) buf_next = 2'd2;
            if ((a==1 && b==2) || (a==2 && b==1)) buf_next = 2'd0;
        end
    endfunction

    reg [2:0] vbl_s, ll_s;
    always @(posedge clk) begin vbl_s <= {vbl_s[1:0], FB_VBL}; ll_s <= {ll_s[1:0], FB_LL}; end
    wire vbl_rise = vbl_s[1] & ~vbl_s[2];
    wire ll       = ll_s[1];

    reg [1:0] i_fb, o_fb;
    reg [2:0] fb_on;

    reg [1:0] i_n, o_n;
    always @* begin
        i_n = i_fb;
        if (pix_frame) i_n = ll ? {1'b0, ~i_fb[0]} : buf_next(i_fb, o_fb);
        o_n = o_fb;
        if (vbl_rise)  o_n = ll ? {1'b0, ~i_fb[0]} : buf_next(o_fb, i_n);
    end
    always @(posedge clk) begin
        if (rst) begin
            i_fb <= 2'd0; o_fb <= 2'd1; fb_on <= 3'd0;
        end else begin
            i_fb <= i_n;
            o_fb <= o_n;
            if (pix_frame) fb_on <= {fb_on[1:0], en};
            if (!en)       fb_on <= 3'd0;
        end
    end

    assign FB_EN     = fb_on[2];
    assign FB_FORMAT = 5'b00110;
    assign FB_WIDTH  = W;
    assign FB_HEIGHT = H;
    assign FB_BASE   = {MEM_BASE, o_fb, 23'd0};
    assign FB_STRIDE = STRIDE;

    function [31:0] px32(input [14:0] c);
        px32 = {8'd0, c[4:0], c[4:2], c[9:5], c[9:7], c[14:10], c[14:12]};
    endfunction

    reg  [31:0] px_even;

    reg  [85:0] fifo [0:255];
    reg  [7:0]  wp, rp;
    wire [8:0]  used = {1'b0, wp} - {1'b0, rp};
    wire        full = (used == 9'd255);
    reg         ovf;

    wire [22:0] byte_addr = ({14'd0, pix_y} * {9'd0, STRIDE}) + {12'd0, pix_x[8:1], 3'b000};

    always @(posedge clk) begin
        if (rst) begin
            wp <= 8'd0; ovf <= 1'b0;
        end else if (pix_we) begin
            if (!pix_x[0]) px_even <= px32(pix_rgb);
            else if (!full) begin
                fifo[wp] <= {i_fb, byte_addr[22:3], px32(pix_rgb), px_even};
                wp <= wp + 8'd1;
            end else ovf <= 1'b1;
        end
    end

    reg        we_r;
    reg [85:0] cur;
    always @(posedge clk) begin
        if (rst) begin
            rp <= 8'd0; we_r <= 1'b0;
        end else begin
            if (we_r && !DDRAM_BUSY) we_r <= 1'b0;
            if ((!we_r || !DDRAM_BUSY) && (wp != rp) && !(we_r && DDRAM_BUSY)) begin
                cur  <= fifo[rp];
                rp   <= rp + 8'd1;
                we_r <= 1'b1;
            end
        end
    end

    assign DDRAM_CLK      = clk;
    assign DDRAM_BURSTCNT = 8'd1;
    assign DDRAM_ADDR     = {MEM_BASE, cur[85:64]};
    assign DDRAM_DIN      = cur[63:0];
    assign DDRAM_BE       = 8'hFF;
    assign DDRAM_WE       = we_r;
    assign DDRAM_RD       = 1'b0;
endmodule
