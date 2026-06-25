// ============================================================================
//  Thunder Hoop (Gaelco) — generador de TIMING de vídeo (FASE 1 / camino a HW).
//
//  Contadores H/V que barren la trama y producen: coordenadas visibles (hpos/vpos)
//  para el datapath `thoop2_video` (que ya está verificado pixel-exacto), las señales
//  de sincronismo/blank/DE para el escalador de MiSTer, y el pulso `vblank_irq` que
//  dispara la IRQ6 del 68000 (= `irq6_line_hold` de MAME).
//
//  Ventana visible = la visarea de MAME (`gaelco.cpp`): 320×240, ROT0, 57.42 Hz.
//  ⚠️ Los porches/anchos de sync y el reloj de píxel EXACTOS son FASE 1 (pendiente
//  del esquemático / medida en HW real). Aquí van valores PROVISIONALES coherentes
//  (~60 Hz) que el escalador de MiSTer acepta; afinar luego para fidelidad CRT 1:1.
//
//  `ce_pix` = enable de reloj de píxel (lo entrega el PLL/wrally_clocks; 1 pulso/píxel).
// ============================================================================
`default_nettype none

module thoop2_video_timing #(
    // Horizontal (en píxeles). HTOTAL = HVIS+HFP+HSW+HBP.
    // 2026-06-16: ajustado a pixel clock 8 MHz (clk48/6). HTOTAL=512 -> hsync 15.6 KHz (estandar).
    // VTOTAL=269 -> refresco 8e6/(512*269) = 58.1 Hz. (Antes /7=6.857MHz, HTOTAL=448, VTOTAL=264.)
    parameter HVIS = 320,
    // 2026-06-23 FIX CRT 15kHz: HTOTAL=512 (hsync 8e6/512=15.625kHz) + VTOTAL=272 (57.45Hz ~57.42).
    parameter HFP  = 48,     // front porch
    parameter HSW  = 48,     // sync width
    parameter HBP  = 96,     // back porch   (HTOTAL = 320+48+48+96 = 512 -> hsync 15.625 kHz, CRT OK)
    // Vertical (en líneas). VTOTAL = VVIS+VFP+VSW+VBP.
    parameter VVIS = 240,
    parameter VFP  = 8,
    parameter VSW  = 8,
    parameter VBP  = 16,     // (VTOTAL = 240+8+8+16 = 272 -> 8e6/(512*272)=57.45Hz; CRT 15.6kHz)
    parameter SYNC_ACTIVE = 1'b1   // FIX 0x0 (2026-06-16): jtframe_resync espera hs/vs ACTIVO-ALTO
                                   // (mide el pulso por flanco de SUBIDA: hs_edge=hs&!last_hs, hs_len de
                                   // subida->bajada). Con activo-bajo media el periodo ACTIVO como ancho
                                   // de sync -> regenera un hsync de casi toda la linea -> scaler 0x0.
                                   // toki (que funciona) emite activo-alto. NO afecta a blanks/DE.
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        ce_pix,     // enable de reloj de píxel

    // coordenadas visibles para thoop2_video (válidas cuando de=1)
    output wire [9:0]  hpos,       // 0..HVIS-1
    output wire [8:0]  vpos,       // 0..VVIS-1

    // señales de salida de vídeo (para el sys/ de MiSTer)
    output reg         hsync,
    output reg         vsync,
    output reg         hblank,
    output reg         vblank,
    output wire        de,         // display enable (área visible)

    // a la CPU
    output reg         vblank_irq  // 1 pulso (1 ce_pix) al entrar en vblank
);
    localparam HTOTAL = HVIS + HFP + HSW + HBP;
    localparam VTOTAL = VVIS + VFP + VSW + VBP;

    reg [9:0] hcnt;
    reg [8:0] vcnt;

    wire hmax = (hcnt == HTOTAL-1);
    wire vmax = (vcnt == VTOTAL-1);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hcnt <= 0; vcnt <= 0;
            hsync <= ~SYNC_ACTIVE; vsync <= ~SYNC_ACTIVE;
            hblank <= 1'b1; vblank <= 1'b1; vblank_irq <= 1'b0;
        end else if (ce_pix) begin
            vblank_irq <= 1'b0;

            // contador horizontal
            if (hmax) begin
                hcnt <= 0;
                // contador vertical (avanza al final de cada línea)
                if (vmax) vcnt <= 0;
                else      vcnt <= vcnt + 1'b1;
            end else begin
                hcnt <= hcnt + 1'b1;
            end

            // blanks (área NO visible)
            // hblank SIN -1 (como vblank): el -1 recortaba 1 columna -> ancho 319 vs 320 de MAME.
            hblank <= (hcnt >= HVIS) ? 1'b1 : 1'b0;
            vblank <= (vcnt >= VVIS) ? 1'b1 : 1'b0;

            // sync (tras el front porch, durante SW)
            hsync <= (hcnt >= HVIS+HFP && hcnt < HVIS+HFP+HSW) ? SYNC_ACTIVE : ~SYNC_ACTIVE;
            vsync <= (vcnt >= VVIS+VFP && vcnt < VVIS+VFP+VSW) ? SYNC_ACTIVE : ~SYNC_ACTIVE;

            // IRQ6 de vblank: al entrar en la primera línea no visible
            if (hmax && vcnt == VVIS-1) vblank_irq <= 1'b1;
        end
    end

    assign hpos = hcnt;     // válido en 0..HVIS-1 (de=1)
    assign vpos = vcnt[8:0];
    assign de   = (hcnt < HVIS) && (vcnt < VVIS);

endmodule

`default_nettype wire
