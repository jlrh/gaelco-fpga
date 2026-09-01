`default_nettype none

module thoop_tilemap (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,

    input  wire [8:0]  tmx,
    input  wire [8:0]  tmy,
    input  wire        layer,

    output wire [10:0] tile_a,
    input  wire [31:0] tile_q,

    output wire [19:0] rom_a,
    input  wire [7:0]  d_p0, d_p1, d_p2, d_p3,
    input  wire        gfx_ok,

    output reg  [3:0]  pen,
    output reg  [5:0]  color,
    output reg  [1:0]  category
);

    reg [8:0] tmx_r, tmy_r;
    always @(posedge clk) if (ce) begin tmx_r <= tmx; tmy_r <= tmy; end

    wire [4:0]  tx = tmx_r[8:4];
    wire [4:0]  ty = tmy_r[8:4];
    wire [9:0]  tile_index = {ty, tx};
    assign tile_a = {layer, tile_index};

    reg [3:0] col0_d, row0_d;
    always @(posedge clk) if (ce) begin
        col0_d <= tmx_r[3:0];
        row0_d <= tmy_r[3:0];
    end

    wire [15:0] data  = tile_q[31:16];
    wire [15:0] data2 = tile_q[15:0];
    wire [14:0] code  = 15'h4000 + {1'b0, data[15:2]};
    wire        flipx = data[0];
    wire        flipy = data[1];
    wire [5:0]  color1= data2[5:0];
    wire [1:0]  cat1  = data2[7:6];

    wire [3:0] row1 = flipy ? ~row0_d : row0_d;
    wire [3:0] col1 = flipx ? ~col0_d : col0_d;

    wire [19:0] rom_a_lin = {code, 5'b00000} + {15'b0, col1[3], row1};

    assign rom_a = { rom_a_lin[18], rom_a_lin[19], rom_a_lin[17:0] };

    localparam integer LEAD = 7;

    reg [7:0] gl0[0:1], gl1[0:1], gl2[0:1], gl3[0:1];
    reg [7:0] gh0[0:1], gh1[0:1], gh2[0:1], gh3[0:1];

    reg wpar;
    always @(posedge clk) if (ce) wpar <= tmx_r[4];
    always @(posedge clk) if (ce && gfx_ok) begin
        if (col1[3]) begin gh0[wpar]<=d_p0; gh1[wpar]<=d_p1; gh2[wpar]<=d_p2; gh3[wpar]<=d_p3; end
        else         begin gl0[wpar]<=d_p0; gl1[wpar]<=d_p1; gl2[wpar]<=d_p2; gl3[wpar]<=d_p3; end
    end

    reg [5:0] color_d; reg [1:0] cat_d; reg [3:0] col_d; reg par_d;
    always @(posedge clk) if (ce) begin
        color_d <= color1; cat_d <= cat1; col_d <= col1; par_d <= wpar;
    end
    reg [5:0] color_sr [0:LEAD-1];
    reg [1:0] cat_sr   [0:LEAD-1];
    reg [3:0] col_sr   [0:LEAD-1];
    reg       par_sr   [0:LEAD-1];
    integer si;
    always @(posedge clk) if (ce) begin
        color_sr[0] <= color_d; cat_sr[0] <= cat_d; col_sr[0] <= col_d; par_sr[0] <= par_d;
        for (si = 1; si < LEAD; si = si + 1) begin
            color_sr[si] <= color_sr[si-1];
            cat_sr  [si] <= cat_sr  [si-1];
            col_sr  [si] <= col_sr  [si-1];
            par_sr  [si] <= par_sr  [si-1];
        end
    end
    wire [5:0] color_c = color_sr[LEAD-1];
    wire [1:0] cat_c   = cat_sr  [LEAD-1];
    wire [3:0] col_c   = col_sr  [LEAD-1];
    wire       par_c   = par_sr  [LEAD-1];

    wire [7:0] db0 = col_c[3] ? gh0[par_c] : gl0[par_c];
    wire [7:0] db1 = col_c[3] ? gh1[par_c] : gl1[par_c];
    wire [7:0] db2 = col_c[3] ? gh2[par_c] : gl2[par_c];
    wire [7:0] db3 = col_c[3] ? gh3[par_c] : gl3[par_c];
    wire [2:0] bbit = 3'd7 - col_c[2:0];
    wire [3:0] pen2 = { db3[bbit], db2[bbit], db1[bbit], db0[bbit] };

    always @(posedge clk) begin
        if (rst) begin
            pen      <= 4'd0;
            color    <= 6'd0;
            category <= 2'd0;
        end else if (ce) begin
            pen      <= pen2;
            color    <= color_c;
            category <= cat_c;
        end
    end

`ifdef THOOP_PENTRACE

    integer ptn=0;
    always @(posedge clk) if (ce && layer==1'b0 && (color_c>=6'd1 && color_c<=6'd4) && ptn<60) begin
        $display("PT %0d colc=%0d code=%h gl=%h%h%h%h gh=%h%h%h%h pen2=%h color=%h",
                 ptn, col_c, code, gl3,gl2,gl1,gl0, gh3,gh2,gh1,gh0, pen2, color_c);
        ptn<=ptn+1;
    end
`endif
endmodule

`default_nettype wire
