// ============================================================================
//  Thunder Hoop (Gaelco) — Descifrado de VRAM (gaelco_vram_encryption, gaelcrpt.cpp)
//
//  IDENTICO al de WRally (mismo algoritmo gaelcrpt, verificado 1:1 vs gaelcrpt.cpp);
//  SOLO cambian los parametros: Thunder Hoop usa P1=0x0e, P2=0x4228
//  (squash=0x0f,0x4228 ; WRally=0x1f,0x522a). set_params(param1,param2) en gaelco.cpp.
//
//  Funcion `decrypt(enc_prev, dec_prev, enc)` -> dec, COMBINACIONAL. La CPU escribe la
//  VRAM (videoram Y screenram) CIFRADA; se almacena DESCIFRADA. La cadena 16/32-bit
//  (stateful: detecta la 2a palabra de un move.l por offset consecutivo) se maneja
//  fuera, en biomtoy_main (igual que WRally). bitswap16: 1er indice = bit MSB (15).
// ============================================================================
`default_nettype none

module biomtoy_vram_decrypt #(
    parameter [5:0]  P1 = 6'h0e,
    parameter [15:0] P2 = 16'h4228
) (
    input  wire [15:0] enc_prev,
    input  wire [15:0] dec_prev,
    input  wire [15:0] enc,
    output wire [15:0] dec
);
    wire [1:0] swap = {dec_prev[8], dec_prev[7]};
    wire [1:0] tp   = {dec_prev[12], dec_prev[2]};

    reg  [15:0] r0;          // tras bitswap por swap
    always @(*) case (swap)
        2'd0: r0 = {enc[1],enc[2],enc[0],enc[14],enc[12],enc[15],enc[4],enc[8],enc[13],enc[7],enc[3],enc[6],enc[11],enc[5],enc[10],enc[9]};
        2'd1: r0 = {enc[14],enc[10],enc[4],enc[15],enc[1],enc[6],enc[12],enc[11],enc[8],enc[0],enc[9],enc[13],enc[7],enc[3],enc[5],enc[2]};
        2'd2: r0 = {enc[2],enc[13],enc[15],enc[1],enc[12],enc[8],enc[14],enc[4],enc[6],enc[0],enc[9],enc[5],enc[10],enc[7],enc[3],enc[11]};
        2'd3: r0 = {enc[3],enc[8],enc[1],enc[13],enc[14],enc[4],enc[15],enc[0],enc[10],enc[2],enc[7],enc[12],enc[6],enc[11],enc[9],enc[5]};
    endcase
    wire [15:0] r1 = r0 ^ P2;

    // primer k (6 bits) por type
    reg  [5:0] k1;
    always @(*) case (tp)
        2'd0: k1 = 6'b111010;                                                            // 0,1,0,1,1,1
        2'd1: k1 = {enc_prev[15], enc_prev[8], enc_prev[3], dec_prev[1], dec_prev[1], dec_prev[0]};
        2'd2: k1 = {enc_prev[14], enc_prev[13], enc_prev[3], enc_prev[7], dec_prev[5], enc_prev[5]};
        2'd3: k1 = {dec_prev[11], enc_prev[2], dec_prev[4], enc_prev[6], enc_prev[9], enc_prev[0]};
    endcase
    wire [5:0] k1x = k1 ^ P1;
    wire [15:0] r2 = (r1 & 16'hffc0) | ((r1 + {10'b0,k1x}) & 16'h003f);
    wire [15:0] r3 = r2 ^ {10'b0, P1};

    // segundo k (5 bits) por type (usa bits de r3)
    reg  [4:0] k2;
    always @(*) case (tp)
        2'd0: k2 = {r3[4], r3[5], enc[5], r3[2], enc[9]};
        2'd1: k2 = {dec_prev[12], r3[1], dec_prev[14], enc_prev[4], dec_prev[2]};
        2'd2: k2 = {dec_prev[7], r3[0], dec_prev[15], dec_prev[6], enc_prev[6]};
        2'd3: k2 = {enc_prev[10], dec_prev[1], enc_prev[5], dec_prev[9], dec_prev[2]};
    endcase
    wire [4:0] k2x = k2 ^ P1[4:0];
    wire [15:0] k2_6  = {11'b0, k2x} << 6;
    wire [15:0] k2_11 = {11'b0, k2x} << 11;
    wire [15:0] r4 = (r3 & 16'h003f)
                   | ((r3 + k2_6)  & 16'h07c0)
                   | ((r3 + k2_11) & 16'hf800);
    wire [15:0] xormask = ({10'b0, P1} << 6) | ({10'b0, P1} << 11);   // (P1<<6)|(P1<<11)
    wire [15:0] r5 = r4 ^ xormask;

    assign dec = {r5[2],r5[6],r5[0],r5[11],r5[14],r5[12],r5[7],r5[10],r5[5],r5[4],r5[8],r5[3],r5[9],r5[1],r5[13],r5[15]};
endmodule

`default_nettype wire
