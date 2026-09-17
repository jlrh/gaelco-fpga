`default_nettype none

module wrally2_addr_decode (
    input  wire [23:0] addr,
    input  wire        as,

    output wire        cs_rom,
    output wire        cs_vram,
    output wire        cs_sound,
    output wire        cs_pal,
    output wire        cs_xram,
    output wire        cs_vregs,
    output wire        cs_in0,
    output wire        cs_in1,
    output wire        cs_in2,
    output wire        cs_in3,
    output wire        cs_latch,
    output wire        cs_wram,
    output wire        cs_shram
);
    assign cs_rom  = as & (addr[23:20] == 4'h0);

    wire blk_20    = as & (addr[23:16] == 8'h20);
    assign cs_sound= blk_20 & (addr[15:8] == 8'h28) & (addr[7:1] >= 7'h48);
    assign cs_vram = blk_20 & ~cs_sound;

    assign cs_pal  = as & (addr[23:16] == 8'h21) & (addr[15:13] == 3'b0);
    assign cs_xram = as & (addr[23:13] == 11'h109);

    wire blk_218   = as & (addr[23:12] == 12'h218);
    assign cs_vregs= blk_218 & (addr[11:1] >= 11'h002) & (addr[11:1] <= 11'h004);

    assign cs_in0  = as & (addr[23:1] == 23'h180000);
    assign cs_in1  = as & (addr[23:1] == 23'h180001);
    assign cs_in2  = as & (addr[23:1] == 23'h180002);
    assign cs_in3  = as & (addr[23:1] == 23'h180003);

    assign cs_latch= as & (addr[23:6] == 18'h10000);

    assign cs_wram = as & (addr[23:15] == 9'b1111_1110_0);
    assign cs_shram= as & (addr[23:15] == 9'b1111_1110_1);
endmodule

`default_nettype wire
