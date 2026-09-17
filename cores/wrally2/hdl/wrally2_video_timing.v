`default_nettype none

module wrally2_video_timing #(

    parameter HFP  = 24,
    parameter HSW  = 48,

    parameter VVIS = 240,
    parameter VFP  = 10,
    parameter VSW  = 8,
    parameter VBP  = 6,
    parameter SYNC_ACTIVE = 1'b1

)(
    input  wire        clk,
    input  wire        rst,
    input  wire        ce_pix,
    input  wire        twin,

    output wire [9:0]  hpos,
    output wire [8:0]  vpos,
    output wire        frame_end,

    output reg         hsync,
    output reg         vsync,
    output reg         hblank,
    output reg         vblank,
    output wire        de,

    output reg         vblank_irq
);

    wire [10:0] HVIS   = twin ? 11'd768  : 11'd384;
    wire [10:0] HTOTAL = twin ? 11'd1024 : 11'd512;

    wire [10:0] HFP_eff = twin ? (HFP*2) : HFP;
    wire [10:0] HSW_eff = twin ? (HSW*2) : HSW;
    localparam VTOTAL = VVIS + VFP + VSW + VBP;

    reg [10:0] hcnt;
    reg [8:0] vcnt;

    wire hmax = (hcnt == HTOTAL-1'b1);
    wire vmax = (vcnt == VTOTAL-1);
    assign frame_end = vmax;

`ifdef SIMULATION
    initial begin
        hcnt = 0; vcnt = 0;
        hsync = ~SYNC_ACTIVE; vsync = ~SYNC_ACTIVE;
        hblank = 1'b1; vblank = 1'b1; vblank_irq = 1'b0;
    end
`endif
    always @(posedge clk) begin
        if (ce_pix) begin
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

            hsync <= (hcnt >= HVIS+HFP_eff && hcnt < HVIS+HFP_eff+HSW_eff) ? SYNC_ACTIVE : ~SYNC_ACTIVE;
            vsync <= (vcnt >= VVIS+VFP && vcnt < VVIS+VFP+VSW) ? SYNC_ACTIVE : ~SYNC_ACTIVE;

            if (hmax && vcnt == VVIS-1) vblank_irq <= 1'b1;
        end
    end

    assign hpos = hcnt[9:0];
    assign vpos = vcnt[8:0];

    assign de   = (hcnt <= HVIS) && (vcnt < VVIS);

endmodule

`default_nettype wire
