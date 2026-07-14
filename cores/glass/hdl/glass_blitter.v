// ============================================================================
//  Glass (Gaelco) — glass_blitter.v: captura del COMANDO SERIE del blitter (lo NUEVO de glass).
//
//  glass.cpp blitter_w (escrituras a 0x700008): el 68000 escribe 5 bits EN SERIE (1 bit por escritura,
//  bit0 del bus). El stream es P0 P1 B2 B1 B0:
//    cmd = ((cmd<<1) | (data&1)) & 0x1f;  cur_bit++;
//    if (cur_bit==5) { cur_bit=0;
//        base = (cmd&7)*0x10000 + (cmd&8)*0x10000 + 0x140;   // imagen + mitad de H9 + offset
//        if (cmd & 0x18) { capa ACTIVA con `base`; } else { capa OFF (bitmap a 0); }
//    }
//  Tras 5 bits: cmd[4]=P0, cmd[3]=P1, cmd[2:0]=B2B1B0. active = P0|P1 (cmd&0x18).
//  base (20b) = {cmd[3](P1=mitad), cmd[2:0](imagen), 16'h0140}.
//
//  `stb` = 1 pulso por escritura a 0x700008 (lo genera glass_main al final del ciclo de bus). `d0` = bit del bus.
// ============================================================================
`default_nettype none

module glass_blitter (
    input  wire        clk,
    input  wire        rst,
    input  wire        stb,          // 1 pulso por escritura a 0x700008
    input  wire        d0,           // bit del bus (data & 1)
    output reg  [19:0] blit_base,    // base en H9 (incluye +0x140 + imagen + mitad)
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
                if (cmd_next[4] | cmd_next[3]) begin       // cmd & 0x18 (P0|P1) -> ACTIVA
                    blit_active <= 1'b1;
                    blit_base   <= {cmd_next[3], cmd_next[2:0], 16'h0140};
                end else begin
                    blit_active <= 1'b0;                   // limpia la capa (bitmap a 0)
                end
            end else bitcnt <= bitcnt + 3'd1;
        end
    end
endmodule

`default_nettype wire
