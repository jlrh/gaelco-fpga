`default_nettype none

module glass_dbg_uart #(
    parameter integer NB  = 16,
    parameter integer DIV = 5000
) (
    input  wire              clk,
    input  wire              rst,
    input  wire [8*NB-1:0]   data,
    output reg               pkt_start,
    output reg               txd
);
    reg [13:0]      divcnt = 0;
    reg [3:0]       bitcnt = 0;
    reg [7:0]       shreg  = 8'hFF;
    reg [5:0]       bidx   = 0;
    reg [15:0]      gap    = 0;
    reg             busy   = 0;
    reg [8*NB-1:0]  buf_q  = 0;

    always @(posedge clk) begin
        pkt_start <= 1'b0;
        if (rst) begin
            txd<=1'b1; bitcnt<=0; bidx<=0; gap<=0; busy<=0; divcnt<=0; shreg<=8'hFF;
        end else if (!busy) begin
            txd <= 1'b1;
            gap <= gap + 1'b1;
            if (&gap) begin
                busy<=1'b1; bidx<=0; bitcnt<=0; divcnt<=0;
                buf_q <= data; shreg <= data[7:0];
                pkt_start <= 1'b1;
            end
        end else begin
            if (divcnt < DIV-1) divcnt <= divcnt + 1'b1;
            else begin
                divcnt <= 0;
                if      (bitcnt==4'd0) txd <= 1'b0;
                else if (bitcnt==4'd9) txd <= 1'b1;
                else begin txd <= shreg[0]; shreg <= {1'b0, shreg[7:1]}; end
                if (bitcnt==4'd9) begin
                    if (bidx==NB-1) begin busy<=1'b0; gap<=0; end
                    else begin bidx<=bidx+1'b1; bitcnt<=4'd0; shreg<=buf_q[8*(bidx+1) +: 8]; end
                end else bitcnt <= bitcnt + 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
