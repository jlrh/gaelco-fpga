// ============================================================================
//  Squash (Gaelco) — Latch direccionable LS259 (outlatch) + banco OKI
//
//  LS259 @ 0x70000B (MAME gaelco.cpp): es un latch direccionable de 8 bits.
//    direccion = A[6:4] (offset>>4 del select 0x70), dato = D0 del bus.
//    Salidas Q0..Q7:
//      Q0,Q1 = coin lockout 0/1     Q2,Q3 = coin counter 0/1
//      Q4    = sound muting          Q5    = FLIP SCREEN
//      Q6,Q7 = ADC ENA/D, CKA/D (volante de pot; SIN USO en modo joystick)
//
//  Banco OKI @ 0x70000D: registro de 4 bits = data[3:0] (16 bancos de 64 KB).
//
//  Stateful sencillo -> verificable (ver tb_iolatch).
// ============================================================================
`default_nettype none

module squash_iolatch (
    input  wire        clk,
    input  wire        reset,

    // LS259 outlatch (0x70000B): escribe D0 en la posicion direccionada por A[6:4]
    input  wire        cs_outlatch,   // strobe de escritura
    input  wire [2:0]  outlatch_a,    // A[6:4]
    input  wire        outlatch_d0,   // bit 0 del bus de datos
    output reg  [7:0]  outlatch,      // Q0..Q7

    // Banco OKI (0x70000D): data[3:0]
    input  wire        cs_okibank,
    input  wire [3:0]  okibank_in,
    output reg  [3:0]  okibank,

    // Alias util
    output wire        flip_screen    // = Q5
);
    assign flip_screen = outlatch[5];

    always @(posedge clk) begin
        if (reset) begin
            outlatch <= 8'd0;
            okibank  <= 4'd0;
        end else begin
            if (cs_outlatch) outlatch[outlatch_a] <= outlatch_d0;
            if (cs_okibank)  okibank <= okibank_in;
        end
    end
endmodule

`default_nettype wire
