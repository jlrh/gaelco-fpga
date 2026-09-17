`default_nettype none

module glass_tilemap (
    input  wire        clk,
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
    reg       tx0_d;
    always @(posedge clk) if (ce) begin
        col0_d <= tmx_r[3:0];
        row0_d <= tmy_r[3:0];
        tx0_d  <= tmx_r[4];
    end

    wire [15:0] data  = tile_q[31:16];
    wire [15:0] data2 = tile_q[15:0];

    wire [14:0] code  = {data[0], data[15:2]};
    wire        flipx = data2[6];
    wire        flipy = data2[7];
    wire [5:0]  color1= {1'b1, data2[4:0]};
    wire [1:0]  cat1  = 2'b00;

    wire [3:0] row1 = flipy ? ~row0_d : row0_d;
    wire [3:0] col1 = flipx ? ~col0_d : col0_d;

    wire [19:0] rom_a_lin = {code, 5'b00000} + {15'b0, col1[3], row1};
    assign rom_a = rom_a_lin;

    localparam integer LEAD = 7;
    reg [31:0] glA, ghA, glB, ghB;
    always @(posedge clk) if (ce && gfx_ok) begin
        case ({tx0_d, col1[3]})
            2'b00: glA <= {d_p0,d_p1,d_p2,d_p3};
            2'b01: ghA <= {d_p0,d_p1,d_p2,d_p3};
            2'b10: glB <= {d_p0,d_p1,d_p2,d_p3};
            2'b11: ghB <= {d_p0,d_p1,d_p2,d_p3};
        endcase
    end

    reg [5:0] color_d; reg [1:0] cat_d; reg [3:0] col_d; reg tx0_dd;
    always @(posedge clk) if (ce) begin
        color_d <= color1; cat_d <= cat1; col_d <= col1; tx0_dd <= tx0_d;
    end
    reg [5:0] color_sr [0:LEAD-1];
    reg [1:0] cat_sr   [0:LEAD-1];
    reg [3:0] col_sr   [0:LEAD-1];
    reg       tx0_sr   [0:LEAD-1];
    integer si;
    always @(posedge clk) if (ce) begin
        color_sr[0] <= color_d; cat_sr[0] <= cat_d; col_sr[0] <= col_d; tx0_sr[0] <= tx0_dd;
        for (si = 1; si < LEAD; si = si + 1) begin
            color_sr[si] <= color_sr[si-1];
            cat_sr  [si] <= cat_sr  [si-1];
            col_sr  [si] <= col_sr  [si-1];
            tx0_sr  [si] <= tx0_sr  [si-1];
        end
    end
    wire [5:0] color_c = color_sr[LEAD-1];
    wire [1:0] cat_c   = cat_sr  [LEAD-1];
    wire [3:0] col_c   = col_sr  [LEAD-1];
    wire       tx0_c   = tx0_sr  [LEAD-1];

    wire [31:0] hb = col_c[3] ? (tx0_c ? ghB : ghA) : (tx0_c ? glB : glA);
    wire [7:0] db0 = hb[31:24], db1 = hb[23:16], db2 = hb[15:8], db3 = hb[7:0];
    wire [2:0] bbit = 3'd7 - col_c[2:0];
    wire [3:0] pen2 = { db3[bbit], db2[bbit], db1[bbit], db0[bbit] };
    always @(posedge clk) if (ce) begin
        pen      <= pen2;
        color    <= color_c;
        category <= cat_c;
    end

`ifdef GLASS_PENTRACE

    integer ptn=0;
    always @(posedge clk) if (ce && layer==1'b0 && (color_c>=6'd1 && color_c<=6'd4) && ptn<60) begin
        $display("PT %0d colc=%0d tx0c=%b code=%h glA=%h ghA=%h glB=%h ghB=%h pen2=%h color=%h",
                 ptn, col_c, tx0_c, code, glA, ghA, glB, ghB, pen2, color_c);
        ptn<=ptn+1;
    end
`endif
endmodule

`default_nettype wire
