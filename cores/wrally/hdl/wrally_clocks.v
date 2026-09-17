`default_nettype none

module wrally_clocks #(
    parameter CPUDIV = 4,
    parameter OKIDIV = 48
)(
    input  wire clk,
    input  wire rst,
    output reg  cpu_cen_phi1 = 1'b0,
    output reg  cpu_cen_phi2 = 1'b0,
    output reg  mcu_cen = 1'b0,
    output reg  oki_cen = 1'b0
);

    reg [$clog2(CPUDIV)-1:0] cdiv = 0;

    reg [$clog2(OKIDIV)-1:0] odiv = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cdiv <= 0; odiv <= 0;
            cpu_cen_phi1 <= 1'b0; cpu_cen_phi2 <= 1'b0;
            mcu_cen <= 1'b0; oki_cen <= 1'b0;
        end else begin
            cdiv <= (cdiv == CPUDIV-1) ? 0 : cdiv + 1'b1;

            cpu_cen_phi1 <= (cdiv == 0);
            cpu_cen_phi2 <= (cdiv == (CPUDIV/2));
            mcu_cen      <= (cdiv == 0);
            odiv <= (odiv == OKIDIV-1) ? 0 : odiv + 1'b1;
            oki_cen <= (odiv == 0);
        end
    end
endmodule

`default_nettype wire
