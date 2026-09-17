`default_nettype none

module wrally2_adc (
    input  wire        clk,
    input  wire        rst,
    input  wire        latch_we,
    input  wire [2:0]  latch_sel,
    input  wire        latch_dat,
    input  wire [7:0]  analog0,
    input  wire [7:0]  analog1,
    output wire        adc1_bit,
    output wire        adc2_bit
);
    reg [7:0] ls259 = 8'd0;
    reg [7:0] sh0 = 8'd0, sh1 = 8'd0;
    reg       q5p = 1'b0, q6p = 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            ls259 <= 8'd0; sh0 <= 8'd0; sh1 <= 8'd0; q5p <= 1'b0; q6p <= 1'b0;
        end else begin
            if (latch_we) ls259[latch_sel] <= latch_dat;
            q5p <= ls259[5];
            q6p <= ls259[6];

            if      (q6p & ~ls259[6]) begin sh0 <= analog0;           sh1 <= analog1;           end
            else if (q5p & ~ls259[5]) begin sh0 <= {sh0[6:0],1'b0};   sh1 <= {sh1[6:0],1'b0};   end
        end
    end

    assign adc1_bit = sh0[7];
    assign adc2_bit = sh1[7];
endmodule

`default_nettype wire
