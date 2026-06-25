// ============================================================================
//  Thunder Hoop (Gaelco) — thoop2_video_top.v: TOP de vídeo (timing + tilemaps + paleta).
//
//  Une thoop2_video_timing + thoop2_video (2 tilemaps con prioridad Tipo-1) + paleta
//  (xBGR_555) y entrega RGB 5-5-5 + sync/blank/DE + vblank_irq.
//
//  FASE 4d (parcial): camino de TILEMAP completo. Los SPRITES (thoop2_sprite_engine, fase 4c)
//  se intercalaran aqui con el mezclador por rango. De momento gfxs (sprites) sin pedir.
//
//  Latencia hpos->RGB ~= LAT ce_pix (tilemap pipeline 11 + video reg 1 + paleta 1 = 13).
//  Calibrable con DEADJ contra captura (como WRally).
// ============================================================================
`default_nettype none

module thoop2_video_top #(
    parameter integer LAT   = 13,   // latencia hpos->RGB (ce_pix)
    parameter integer DEADJ = 0,    // ajuste fino de fase sync/DE vs RGB
    parameter integer SPN   = 12,   // alineacion del camino de sprite (calibrable; ~LAT-1)
    parameter integer VTOTAL= 272   // 2026-06-23 FIX CRT: VTOTAL=512x272 (debe = el del video_timing)
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        ce_pix,

    input  wire [15:0] vreg_l0y, vreg_l0x, vreg_l1y, vreg_l1x,

    // tilemap L0/L1: videoram (de thoop2_vmem) + gfx (SDRAM). rom_a 21b = gfx 8MB DW32.
    output wire [10:0] tile_a0, input wire [31:0] tile_q0,
    output wire [20:0] rom_a0,  input wire [31:0] gfx0_data, input wire gfx0_ok,
    output wire [10:0] tile_a1, input wire [31:0] tile_q1,
    output wire [20:0] rom_a1,  input wire [31:0] gfx1_data, input wire gfx1_ok,
    // paleta tilemap (puerto A) + sprite (puerto B) (de thoop2_vmem)
    output wire [9:0]  pal_a,   input wire [15:0] pal_q,
    output wire [9:0]  palb_a,  input wire [15:0] palb_q,
    // spriteRAM + gfx de sprites (de thoop2_vmem / SDRAM)
    output wire [10:0] spr_a,   input wire [15:0] spr_q,
    output wire [20:0] srom_a,  input wire [31:0] gfxs_data, input wire spr_gfx_ok,

    // salida de vídeo (interfaz jtframe), COLORW=5
    output wire [4:0]  vga_r, vga_g, vga_b,
    output wire        hsync, vsync, hblank, vblank, de,
    output wire        vblank_irq
);
    // ---- timing ----
    wire [9:0] hpos; wire [8:0] vpos;
    wire hs_i, vs_i, hb_i, vb_i, de_i;
    thoop2_video_timing u_timing (
        .clk(clk), .rst(rst), .ce_pix(ce_pix),
        .hpos(hpos), .vpos(vpos),
        .hsync(hs_i), .vsync(vs_i), .hblank(hb_i), .vblank(vb_i),
        .de(de_i), .vblank_irq(vblank_irq)
    );

    // ---- 4 byte-lanes de la lectura DW32 de gfx -> planos p0..p3 ----
    // ORDEN RECTO (3,2,1,0): el blob de descarga empaqueta byte3=c09 .. byte0=c12 (.mra), y gfx_data[31:24]=byte3.
    // pen[0]=c09 (byte[31:24]) .. pen[3]=c12 (byte[7:0]). CORRECTO (verificado byte-a-byte vs thoop.rom 2026-06-22).
    wire [7:0] d0_p0=gfx0_data[31:24], d0_p1=gfx0_data[23:16], d0_p2=gfx0_data[15:8], d0_p3=gfx0_data[7:0];
    wire [7:0] d1_p0=gfx1_data[31:24], d1_p1=gfx1_data[23:16], d1_p2=gfx1_data[15:8], d1_p3=gfx1_data[7:0];

    // ---- compositor de tilemaps -> indice de paleta del ganador ----
    wire [9:0] pal_index; wire [4:0] win_rank; wire win_opaque; wire [3:0] prio_buf_tm;
    thoop2_video u_video (
        .clk(clk), .ce(ce_pix), .hpos(hpos[8:0]), .vpos(vpos),
        .vreg_l0y(vreg_l0y), .vreg_l0x(vreg_l0x), .vreg_l1y(vreg_l1y), .vreg_l1x(vreg_l1x),
        .tile_a0(tile_a0), .tile_q0(tile_q0),
        .rom_a0(rom_a0), .d0_p0(d0_p0), .d0_p1(d0_p1), .d0_p2(d0_p2), .d0_p3(d0_p3), .gfx0_ok(gfx0_ok),
        .tile_a1(tile_a1), .tile_q1(tile_q1),
        .rom_a1(rom_a1), .d1_p0(d1_p0), .d1_p1(d1_p1), .d1_p2(d1_p2), .d1_p3(d1_p3), .gfx1_ok(gfx1_ok),
        .pal_index(pal_index), .win_rank(win_rank), .win_opaque(win_opaque), .prio_buf(prio_buf_tm)
    );

    // ---- paleta tilemap: pal_a = indice del ganador -> pal_q (1 ce) -> RGB ----
    assign pal_a = pal_index;
    wire [4:0] r5, g5, b5;
    thoop2_palette u_pal (.pal_word(pal_q), .r(r5), .g(g5), .b(b5));
    // prio_buf sale registrado con pal_index; r5 llega 1 ce despues (pal_q) -> retrasar 1 ce para alinear.
    reg [3:0] prio_buf_d;
    always @(posedge clk) if (ce_pix) prio_buf_d <= prio_buf_tm;

    // ===================== SPRITES (8x8, line buffer doble) =====================
    // 4 planos del gfx de sprites (MISMO orden recto que el tilemap; comparten el gfx ROM).
    wire [7:0] sp0=gfxs_data[31:24], sp1=gfxs_data[23:16], sp2=gfxs_data[15:8], sp3=gfxs_data[7:0];
    wire [12:0] spr_lb;     // {prio[2:0], color[5:0], pen[3:0]} del pixel de sprite en hpos
    thoop2_sprite_layer #(.VTOTAL(VTOTAL)) u_spr (
        .clk(clk), .rst(rst), .vpos(vpos), .hpos(hpos[8:0]),
        .spr_a(spr_a), .spr_q(spr_q),
        .rom_a(srom_a), .d_p0(sp0), .d_p1(sp1), .d_p2(sp2), .d_p3(sp3), .gfx_ok(spr_gfx_ok),
        .lb_q(spr_lb), .busy()
    );
    // Alinear el camino de sprite (lb leido en hpos) con la latencia del tilemap (LAT): shift SPN.
    // palb_a sale del tap SPN (combinacional); palb_q llega 1 ce despues, alineado con el tap SPN+1.
    reg [12:0] spr_sr [0:SPN+1];
    integer ss;
    always @(posedge clk) if (ce_pix) begin
        spr_sr[0] <= spr_lb;
        for (ss=1; ss<=SPN+1; ss=ss+1) spr_sr[ss] <= spr_sr[ss-1];
    end
    wire [5:0] spr_color_a = spr_sr[SPN][9:4];
    wire [3:0] spr_pen_a   = spr_sr[SPN][3:0];
    assign palb_a = {spr_color_a, spr_pen_a};            // indice de paleta del sprite
    wire [3:0] spr_pen   = spr_sr[SPN+1][3:0];           // pen alineado con palb_q
    wire [5:0] spr_col_f = spr_sr[SPN+1][9:4];           // color del sprite (0..63)
    wire [2:0] spr_pri_f = spr_sr[SPN+1][12:10];         // prioridad del sprite (0..7; usados 0..4)
    wire [4:0] rs5, gs5, bs5;
    thoop2_palette u_spal (.pal_word(palb_q), .r(rs5), .g(gs5), .b(bs5));
    // ---- mezcla con PRIORIDAD (= draw_sprites/prio_transpen de MAME) ----
    // pri_mask por prioridad de sprite: 0->0xff00,1->0xfff0,2->0xfffc,3->0xfffe,4->0 (todo bits contiguos
    // desde el umbral hasta 15) => ocluido sii prio_buf >= umbral. color>=0x38 fuerza prioridad 4 (arriba).
    wire spr_force_top = (spr_col_f >= 6'h38);
    reg [4:0] spr_thresh;
    always @* begin
        if (spr_force_top) spr_thresh = 5'd31;          // nunca ocluido
        else case (spr_pri_f)
            3'd0:    spr_thresh = 5'd8;
            3'd1:    spr_thresh = 5'd4;
            3'd2:    spr_thresh = 5'd2;
            3'd3:    spr_thresh = 5'd1;
            default: spr_thresh = 5'd31;                // prio>=4: nunca ocluido
        endcase
    end
    wire spr_occluded = ({1'b0, prio_buf_d} >= spr_thresh);
    wire spr_show_raw = (spr_pen != 4'd0) & ~spr_occluded;
    // DIAG aislado de capas (debug): THOOP_NOSPR = sin sprites (tilemap-solo) ; THOOP_NOTM = sin tilemap (sprite-solo)
`ifdef THOOP_NOSPR
    wire spr_show = 1'b0;
`else
    wire spr_show = spr_show_raw;
`endif
`ifdef THOOP_NOTM
    wire [4:0] tr5=5'd0, tg5=5'd0, tb5=5'd0;
`else
    wire [4:0] tr5=r5, tg5=g5, tb5=b5;
`endif
    wire [4:0] mr = spr_show ? rs5 : tr5;
    wire [4:0] mg = spr_show ? gs5 : tg5;
    wire [4:0] mb = spr_show ? bs5 : tb5;

    // ---- sync/blank/DE retrasados LAT (+DEADJ) para alinear con el RGB ----
    localparam integer SD = LAT + DEADJ;
    reg [SD-1:0] hs_sr, vs_sr, hb_sr, vb_sr, de_sr;
    always @(posedge clk) if (ce_pix) begin
        hs_sr <= {hs_sr[SD-2:0], hs_i};
        vs_sr <= {vs_sr[SD-2:0], vs_i};
        hb_sr <= {hb_sr[SD-2:0], hb_i};
        vb_sr <= {vb_sr[SD-2:0], vb_i};
        de_sr <= {de_sr[SD-2:0], de_i};
    end
    assign hsync  = hs_sr[SD-1];
    assign vsync  = vs_sr[SD-1];
    assign hblank = hb_sr[SD-1];
    assign vblank = vb_sr[SD-1];
    assign de     = de_sr[SD-1];

    // negro fuera del area visible (mr/mg/mb = tilemap con sprite encima)
    assign vga_r = de ? mr : 5'd0;
    assign vga_g = de ? mg : 5'd0;
    assign vga_b = de ? mb : 5'd0;

`ifdef THOOP_VGATRACE
    // DIAG: traza la SALIDA (vga/de) en coords de salida (ox/oy via hsync/vsync) en una scanline de barras.
    reg [9:0] ox=0, oy=0; reg hs_d=0, vs_d=0;
    always @(posedge clk) if (ce_pix) begin
        hs_d<=hsync; vs_d<=vsync;
        if (vsync & ~vs_d) oy<=0;
        else if (hsync & ~hs_d) begin ox<=0; oy<=oy+1'b1; end
        else ox<=ox+1'b1;
        if (oy==10'd190) $display("VG ox=%0d de=%b palidx=%h palq=%h rgb=%h%h%h", ox, de, pal_index, pal_q, vga_r, vga_g, vga_b);
    end
`endif
endmodule

`default_nettype wire
