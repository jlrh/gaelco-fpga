`default_nettype none

module glass_blitter (
    input  wire        clk,
    input  wire        rst,
    input  wire        stb,
    input  wire        d0,
    output reg  [19:0] blit_base,
    output reg         blit_active
);
    reg [4:0] cmd;
    reg [2:0] bitcnt;
    wire [4:0] cmd_next = {cmd[3:0], d0};

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cmd <= 5'd0; bitcnt <= 3'd0; blit_base <= 20'd0; blit_active <= 1'b0;
        end else if (stb) begin
            cmd <= cmd_next;
            if (bitcnt == 3'd4) begin
                bitcnt <= 3'd0;
                if (cmd_next[4] | cmd_next[3]) begin
                    blit_active <= 1'b1;
                    blit_base   <= {cmd_next[3], cmd_next[2:0], 16'h0140};
                end else begin
                    blit_active <= 1'b0;
                end
            end else bitcnt <= bitcnt + 3'd1;
        end
    end
endmodule

`default_nettype wire
