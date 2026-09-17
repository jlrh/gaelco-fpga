`default_nettype none

module wrally_tilemap (
    input  wire        clk,
    input  wire        ce,

    input  wire [9:0]  tmx,
    input  wire [8:0]  tmy,
    input  wire        layer,

    output wire [13:0] vram_a,
    input  wire [31:0] vram_q,

    output wire [18:0] rom_a,
    input  wire [7:0]  d_i07,
    input  wire [7:0]  d_i09,
    input  wire [7:0]  d_i11,
    input  wire [7:0]  d_i13,
    input  wire        gfx_ok,

    output reg  [3:0]  pen,
    output reg  [4:0]  color,
    output reg         prio
);

    reg [9:0] tmx_r; reg [8:0] tmy_r;
    always @(posedge clk) if (ce) begin tmx_r <= tmx; tmy_r <= tmy; end

    wire [5:0]  tx = tmx_r[9:4];
    wire [4:0]  ty = tmy_r[8:4];
    wire [10:0] T  = {ty, tx};
    assign vram_a  = {layer, T, 2'b00};

    reg [3:0] col0_d, row0_d;
    always @(posedge clk) if (ce) begin
        col0_d <= tmx_r[3:0];
        row0_d <= tmy_r[3:0];
    end

    wire [15:0] data  = vram_q[31:16];
    wire [15:0] data2 = vram_q[15:0];
    wire [13:0] code;
    wire [4:0]  color1;
    wire        prio1, flipx, flipy;
    wrally_tile_attr u_attr (
        .data (data), .data2(data2),
        .code (code), .color(color1), .prio(prio1),
        .flipx(flipx), .flipy(flipy)
    );

    wire [3:0] row1 = flipy ? ~row0_d : row0_d;
    wire [3:0] col1 = flipx ? ~col0_d : col0_d;

    assign rom_a = {code, 5'b00000} + {14'b0, col1[3], row1};

    localparam integer LEAD = 7;

    reg [7:0] gl07[0:1], gl09[0:1], gl11[0:1], gl13[0:1];
    reg [7:0] gh07[0:1], gh09[0:1], gh11[0:1], gh13[0:1];

    reg wpar;
    always @(posedge clk) if (ce) wpar <= tmx_r[4];
    always @(posedge clk) if (ce && gfx_ok) begin
        if (col1[3]) begin gh07[wpar]<=d_i07; gh09[wpar]<=d_i09; gh11[wpar]<=d_i11; gh13[wpar]<=d_i13; end
        else         begin gl07[wpar]<=d_i07; gl09[wpar]<=d_i09; gl11[wpar]<=d_i11; gl13[wpar]<=d_i13; end
    end

    reg [4:0] color_d; reg prio_d; reg [3:0] col_d; reg par_d;
    always @(posedge clk) if (ce) begin
        color_d <= color1; prio_d <= prio1; col_d <= col1; par_d <= wpar;
    end
    reg [4:0] color_sr [0:LEAD-1];
    reg       prio_sr  [0:LEAD-1];
    reg [3:0] col_sr   [0:LEAD-1];
    reg       par_sr   [0:LEAD-1];
    integer si;
    always @(posedge clk) if (ce) begin
        color_sr[0] <= color_d; prio_sr[0] <= prio_d; col_sr[0] <= col_d; par_sr[0] <= par_d;
        for (si = 1; si < LEAD; si = si + 1) begin
            color_sr[si] <= color_sr[si-1];
            prio_sr [si] <= prio_sr [si-1];
            col_sr  [si] <= col_sr  [si-1];
            par_sr  [si] <= par_sr  [si-1];
        end
    end
    wire [4:0] color_c = color_sr[LEAD-1];
    wire       prio_c  = prio_sr [LEAD-1];
    wire [3:0] col_c   = col_sr  [LEAD-1];
    wire       par_c   = par_sr  [LEAD-1];

    wire [7:0] db07 = col_c[3] ? gh07[par_c] : gl07[par_c];
    wire [7:0] db09 = col_c[3] ? gh09[par_c] : gl09[par_c];
    wire [7:0] db11 = col_c[3] ? gh11[par_c] : gl11[par_c];
    wire [7:0] db13 = col_c[3] ? gh13[par_c] : gl13[par_c];
    wire [2:0] bbit = 3'd7 - col_c[2:0];
    wire [3:0] pen2 = { db07[bbit], db09[bbit], db11[bbit], db13[bbit] };
    always @(posedge clk) if (ce) begin
        pen   <= pen2;
        color <= color_c;
        prio  <= prio_c;
    end

endmodule

`default_nettype wire
