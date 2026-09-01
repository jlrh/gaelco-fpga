`default_nettype none

module bigkarnk_video_timing #(

    parameter HVIS = 320,
    parameter HFP  = 8,
    parameter HSW  = 28,
    parameter HBP  = 28,

    parameter VVIS = 240,
    parameter VFP  = 14,
    parameter VSW  = 8,
    parameter VBP  = 10,
    parameter SYNC_ACTIVE = 1'b1

)(
    input  wire        clk,
    input  wire        rst,
    input  wire        ce_pix,

    output wire [9:0]  hpos,
    output wire [8:0]  vpos,

    output reg         hsync,
    output reg         vsync,
    output reg         hblank,
    output reg         vblank,
    output wire        de,

    output reg         vblank_irq
);
    localparam HTOTAL = HVIS + HFP + HSW + HBP;
    localparam VTOTAL = VVIS + VFP + VSW + VBP;

    reg [9:0] hcnt;
    reg [8:0] vcnt;

    wire hmax = (hcnt == HTOTAL-1);
    wire vmax = (vcnt == VTOTAL-1);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hcnt <= 0; vcnt <= 0;
            hsync <= ~SYNC_ACTIVE; vsync <= ~SYNC_ACTIVE;
            hblank <= 1'b1; vblank <= 1'b1; vblank_irq <= 1'b0;
        end else if (ce_pix) begin
            vblank_irq <= 1'b0;

            if (hmax) begin
                hcnt <= 0;

                if (vmax) vcnt <= 0;
                else      vcnt <= vcnt + 1'b1;
            end else begin
                hcnt <= hcnt + 1'b1;
            end

            hblank <= (hcnt >= HVIS) ? 1'b1 : 1'b0;
            vblank <= (vcnt >= VVIS) ? 1'b1 : 1'b0;

            hsync <= (hcnt >= HVIS+HFP && hcnt < HVIS+HFP+HSW) ? SYNC_ACTIVE : ~SYNC_ACTIVE;
            vsync <= (vcnt >= VVIS+VFP && vcnt < VVIS+VFP+VSW) ? SYNC_ACTIVE : ~SYNC_ACTIVE;

            if (hmax && vcnt == VVIS-1) vblank_irq <= 1'b1;
        end
    end

    assign hpos = hcnt;
    assign vpos = vcnt[8:0];

    assign de   = (hcnt <= HVIS) && (vcnt < VVIS);

endmodule

`default_nettype wire
