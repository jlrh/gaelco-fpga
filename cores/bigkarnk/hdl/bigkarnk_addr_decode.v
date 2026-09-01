`default_nettype none

module bigkarnk_addr_decode (
    input  wire [23:0] addr,
    input  wire        as,

    output wire        cs_rom,
    output wire        cs_vram,
    output wire        cs_scrram,
    output wire        cs_vregs,
    output wire        cs_clrint,
    output wire        cs_pal,
    output wire        cs_spr,
    output wire        cs_dsw1,
    output wire        cs_dsw2,
    output wire        cs_p1,
    output wire        cs_p2,
    output wire        cs_service,
    output wire        cs_outlatch,
    output wire        cs_sndlatch,
    output wire        cs_wram
);
    assign cs_rom   = as & (addr[23:19] == 5'b00000);

    wire blk_1xxx   = as & (addr[23:20] == 4'h1) & (addr[19:14] == 6'b000000);
    assign cs_vram  = blk_1xxx & ~addr[13];
    assign cs_scrram= blk_1xxx &  addr[13];
    assign cs_pal   = as & (addr[23:20] == 4'h2) & (addr[19:11] == 9'b0);
    assign cs_spr   = as & (addr[23:16] == 8'h44) & (addr[15:12] == 4'h0);
    assign cs_wram  = as & (addr[23:16] == 8'hFF) & addr[15];

    wire blk_108 = as & (addr[23:12] == 12'h108);
    assign cs_vregs  = blk_108 & (addr[11:3] == 9'd0);
    assign cs_clrint = blk_108 & (addr[11:2] == 10'b0000000011);

    wire blk_70 = as & (addr[23:8] == 16'h7000);
    assign cs_dsw1     = blk_70 & (addr[7:1] == 7'h00);
    assign cs_dsw2     = blk_70 & (addr[7:1] == 7'h01);
    assign cs_p1       = blk_70 & (addr[7:1] == 7'h02);
    assign cs_p2       = blk_70 & (addr[7:1] == 7'h03);
    assign cs_service  = blk_70 & (addr[7:1] == 7'h04);

    assign cs_outlatch = blk_70 & ~addr[7] & (addr[3:0] == 4'hB);
    assign cs_sndlatch = blk_70 & (addr[7:1] == 7'h07);
endmodule

`default_nettype wire
