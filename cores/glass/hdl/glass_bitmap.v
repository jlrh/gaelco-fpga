`default_nettype none

module glass_bitmap #(
    parameter [8:0] XOFF = 9'd24,
    parameter [8:0] YOFF = 9'd20
)(
    input  wire        clk,
    input  wire        ce_pix,
    input  wire [8:0]  hpos,
    input  wire [8:0]  vpos,
    input  wire [19:0] blit_base,
    input  wire        blit_active,

    output wire [19:0] h9_addr,
    output reg         h9_cs,
    input  wire [7:0]  h9_data,
    input  wire        h9_ok,

    output reg  [7:0]  bmap_index,
    output reg         bmap_show
);

    reg [7:0] lb0 [0:319];
    reg [7:0] lb1 [0:319];
    reg       wbank;
    wire      rbank = vpos[0];

    wire in_x = (hpos >= XOFF) && (hpos < XOFF + 9'd320);
    wire in_y = (vpos >= YOFF) && (vpos < YOFF + 9'd200);
    wire in_region = in_x && in_y && blit_active;
    wire [8:0] rx = hpos - XOFF;
    wire [7:0] rd = rbank ? lb1[rx[8:0]] : lb0[rx[8:0]];
    always @(posedge clk) if (ce_pix) begin
        bmap_index <= rd;
        bmap_show  <= in_region;
    end
`ifdef GLASS_BMTRACE
    always @(posedge clk) if (ce_pix && vpos==9'd150 && hpos>=9'd100 && hpos<=9'd115)
        $display("BMDISP vpos=150 hpos=%0d rx=%0d rd=%02x", hpos, rx, rd);
`endif

    reg        fbusy;
    reg [8:0]  fi;
    reg [19:0] frow;
    assign h9_addr = frow + {11'd0, fi};

    reg [8:0]  vpos_d;
    always @(posedge clk) vpos_d <= vpos;
    wire line_change = (vpos != vpos_d);
    wire [8:0] vnext = (vpos==9'd239) ? 9'd0 : (vpos + 9'd1);
    wire       next_in_y = blit_active && (vnext >= YOFF) && (vnext < YOFF + 9'd200);
    wire [7:0] jnext = vnext[7:0] - YOFF[7:0];
    wire [19:0] jrow = {jnext, 8'd0} + {2'd0, jnext, 6'd0};

    always @(posedge clk) begin
        if (line_change) begin
`ifdef GLASS_BMTRACE
            if (fbusy && fi != 9'd319) $display("BMINCOMPLETE vpos=%0d fi=%0d (fetch no completo)", vpos, fi);
`endif
            wbank <= ~vpos[0];
            fi    <= 9'd0;
            frow  <= blit_base + jrow;
            fbusy <= next_in_y;
            h9_cs <= next_in_y;
        end else if (fbusy) begin
            if (h9_ok) begin
                if (wbank) lb1[fi[8:0]] <= h9_data; else lb0[fi[8:0]] <= h9_data;
                if (fi == 9'd319) begin fbusy <= 1'b0; h9_cs <= 1'b0; end
                else fi <= fi + 9'd1;
            end
        end
    end

    // synthesis translate_off
    integer k;
    initial begin fbusy=0; fi=0; wbank=0; h9_cs=0;
        for(k=0;k<320;k=k+1) begin lb0[k]=0; lb1[k]=0; end end
    // synthesis translate_on
endmodule

`default_nettype wire
