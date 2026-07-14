// ============================================================================
//  Thunder Hoop (Gaelco) — glass_video_top.v: TOP de vídeo (timing + tilemaps + paleta).
//
//  Une glass_video_timing + glass_video (2 tilemaps con prioridad Tipo-1) + paleta
//  (xBGR_555) y entrega RGB 5-5-5 + sync/blank/DE + vblank_irq.
//
//  FASE 4d (parcial): camino de TILEMAP completo. Los SPRITES (glass_sprite_engine, fase 4c)
//  se intercalaran aqui con el mezclador por rango. De momento gfxs (sprites) sin pedir.
//
//  Latencia hpos->RGB ~= LAT ce_pix (tilemap pipeline 11 + video reg 1 + paleta 1 = 13).
//  Calibrable con DEADJ contra captura (como WRally).
// ============================================================================
`default_nettype none

module glass_video_top #(
    parameter integer LAT   = 13,
    parameter integer DEADJ = 0,    // ajuste fino de fase sync/DE vs RGB
    parameter integer SPN   = 12,
    parameter integer BPN   = 11,   // alineacion camino BITMAP (lat bitmap 3+BPN = LAT 13)
    parameter integer VTOTAL= 272   // 2026-06-23 FIX CRT: VTOTAL=512x272 (debe = el del video_timing)
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        ce_pix,

    input  wire [15:0] vreg_l0y, vreg_l0x, vreg_l1y, vreg_l1x,
    input  wire [19:0] blit_base,            // capa BITMAP (blitter): base en H9 + enable
    input  wire        blit_active,

    // tilemap L0/L1: videoram (de glass_vmem) + gfx (SDRAM)
    output wire [10:0] tile_a0, input wire [31:0] tile_q0,
    output wire [19:0] rom_a0,  input wire [31:0] gfx0_data, input wire gfx0_ok,
    output wire [10:0] tile_a1, input wire [31:0] tile_q1,
    output wire [19:0] rom_a1,  input wire [31:0] gfx1_data, input wire gfx1_ok,
    // paleta tilemap (puerto A) + sprite (puerto B) + bitmap (puerto C) (de glass_vmem)
    output wire [9:0]  pal_a,   input wire [15:0] pal_q,
    output wire [9:0]  palb_a,  input wire [15:0] palb_q,
    output wire [9:0]  palc_a,  input wire [15:0] palc_q,
    // spriteRAM + gfx de sprites (de glass_vmem / SDRAM)
    output wire [10:0] spr_a,   input wire [15:0] spr_q,
    output wire [19:0] srom_a,  input wire [31:0] gfxs_data, input wire spr_gfx_ok,
    // bitmap H9 (SDRAM bus bmap, DW8) con handshake (line buffer)
    output wire [19:0] bmap_addr, output wire bmap_cs, input wire [7:0] bmap_data, input wire bmap_ok,

    // salida de vídeo (interfaz jtframe), COLORW=5
    output wire [4:0]  vga_r, vga_g, vga_b,
    output wire        hsync, vsync, hblank, vblank, de,
    output wire        vblank_irq
);
    // ---- timing ----
    wire [9:0] hpos; wire [8:0] vpos;
    wire hs_i, vs_i, hb_i, vb_i, de_i;
    glass_video_timing u_timing (
        .clk(clk), .rst(rst), .ce_pix(ce_pix),
        .hpos(hpos), .vpos(vpos),
        .hsync(hs_i), .vsync(vs_i), .hblank(hb_i), .vblank(vb_i),
        .de(de_i), .vblank_irq(vblank_irq)
    );

    // ---- 4 byte-lanes de la lectura DW32 de gfx -> planos p0..p3 ----
    // ORDEN RECTO (3,2,1,0): el blob de descarga empaqueta byte3=c09 .. byte0=c12 (.mra), y gfx_data[31:24]=byte3.
    // pen[0]=c09 (byte[31:24]) .. pen[3]=c12 (byte[7:0]). CORRECTO (verificado byte-a-byte vs glass.rom 2026-06-22).
    wire [7:0] d0_p0=gfx0_data[31:24], d0_p1=gfx0_data[23:16], d0_p2=gfx0_data[15:8], d0_p3=gfx0_data[7:0];
    wire [7:0] d1_p0=gfx1_data[31:24], d1_p1=gfx1_data[23:16], d1_p2=gfx1_data[15:8], d1_p3=gfx1_data[7:0];

    // ---- compositor de tilemaps -> indice de paleta del ganador ----
    wire [9:0] pal_index; wire [4:0] win_rank; wire win_opaque;
    glass_video u_video (
        .clk(clk), .ce(ce_pix), .hpos(hpos[8:0]), .vpos(vpos),
        .vreg_l0y(vreg_l0y), .vreg_l0x(vreg_l0x), .vreg_l1y(vreg_l1y), .vreg_l1x(vreg_l1x),
        .tile_a0(tile_a0), .tile_q0(tile_q0),
        .rom_a0(rom_a0), .d0_p0(d0_p0), .d0_p1(d0_p1), .d0_p2(d0_p2), .d0_p3(d0_p3), .gfx0_ok(gfx0_ok),
        .tile_a1(tile_a1), .tile_q1(tile_q1),
        .rom_a1(rom_a1), .d1_p0(d1_p0), .d1_p1(d1_p1), .d1_p2(d1_p2), .d1_p3(d1_p3), .gfx1_ok(gfx1_ok),
        .pal_index(pal_index), .win_rank(win_rank), .win_opaque(win_opaque)
    );

    // ---- paleta tilemap: pal_a = indice del ganador -> pal_q (1 ce) -> RGB ----
    assign pal_a = pal_index;
    wire [4:0] r5, g5, b5;
    glass_palette u_pal (.pal_word(pal_q), .r(r5), .g(g5), .b(b5));

    // ===================== SPRITES (8x8, line buffer doble) =====================
    // 4 planos del gfx de sprites (MISMO orden recto que el tilemap; comparten el gfx ROM).
    wire [7:0] sp0=gfxs_data[31:24], sp1=gfxs_data[23:16], sp2=gfxs_data[15:8], sp3=gfxs_data[7:0];
    wire [12:0] spr_lb;     // {prio[2:0], color[5:0], pen[3:0]} del pixel de sprite en hpos
    glass_sprite_layer #(.VTOTAL(VTOTAL)) u_spr (
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
    wire [4:0] rs5, gs5, bs5;
    glass_palette u_spal (.pal_word(palb_q), .r(rs5), .g(gs5), .b(bs5));
`ifdef GLASS_SPREDGE
    always @(posedge clk) if (ce_pix && vpos==9'd144 && hpos>=9'd360 && hpos<=9'd370)
        $display("SLB hpos=%0d spr_lb=%h pen=%h col=%h", hpos, spr_lb, spr_lb[3:0], spr_lb[9:4]);
`endif
    // ===================== CAPA BITMAP (blitter) — fondo, debajo de los tilemaps =====================
    wire [7:0] bmap_idx_raw; wire bmap_show_raw;
    glass_bitmap u_bmap (
        .clk(clk), .ce_pix(ce_pix), .hpos(hpos[8:0]), .vpos(vpos),
        .blit_base(blit_base), .blit_active(blit_active),
        .h9_addr(bmap_addr), .h9_cs(bmap_cs), .h9_data(bmap_data), .h9_ok(bmap_ok),
        .bmap_index(bmap_idx_raw), .bmap_show(bmap_show_raw)
    );
    // alinear el camino bitmap (BPN) con la etapa pal_index del tilemap; palc_q llega 1 ce despues (=rb5)
    reg [7:0] bidx_sr [0:BPN+1];
    reg       bshow_sr [0:BPN+1];
    integer bb;
    always @(posedge clk) if (ce_pix) begin
        bidx_sr[0] <= bmap_idx_raw; bshow_sr[0] <= bmap_show_raw;
        for (bb=1; bb<=BPN+1; bb=bb+1) begin bidx_sr[bb]<=bidx_sr[bb-1]; bshow_sr[bb]<=bshow_sr[bb-1]; end
    end
    assign palc_a = {2'b00, bidx_sr[BPN]};          // indice 0..255 (alineado con pal_a)
    wire   bmap_show_a = bshow_sr[BPN+1];           // alineado con palc_q
    wire [4:0] rb5, gb5, bb5;
    glass_palette u_bpal (.pal_word(palc_q), .r(rb5), .g(gb5), .b(bb5));

    // win_opaque del compositor de tilemaps, alineado con r5 (pal_q va 1 ce tras pal_index/win_opaque)
    reg win_op_d; always @(posedge clk) if (ce_pix) win_op_d <= win_opaque;

    // ===================== MEZCLA por capas: sprite > tilemap(opaco) > bitmap(region) > negro =====================
`ifdef GLASS_NOSPR
    wire spr_show = 1'b0;          // DIAG: desactiva overlay de sprites para aislar tilemap
`else
    wire spr_show = (spr_pen != 4'd0);
`endif
    wire [4:0] base_r = win_op_d ? r5 : (bmap_show_a ? rb5 : 5'd0);
    wire [4:0] base_g = win_op_d ? g5 : (bmap_show_a ? gb5 : 5'd0);
    wire [4:0] base_b = win_op_d ? b5 : (bmap_show_a ? bb5 : 5'd0);
    wire [4:0] mr = spr_show ? rs5 : base_r;
    wire [4:0] mg = spr_show ? gs5 : base_g;
    wire [4:0] mb = spr_show ? bs5 : base_b;

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

`ifdef GLASS_VGATRACE
    // DIAG: cuenta PIXELES de-activos (= la x del frame) y traza la ULTIMA columna en la fila 144.
    reg [9:0] dx=0, dline=0; reg de_d=0, vs_d2=0;
    always @(posedge clk) if (ce_pix) begin
        de_d<=de; vs_d2<=vsync;
        if (vsync & ~vs_d2) dline<=0;
        else if (de & ~de_d) begin dx<=0; dline<=dline+1'b1; end
        else if (de) dx<=dx+1'b1;
        if (de & (dline==10'd144) & (dx>=10'd362) & (dx<=10'd368))
            $display("VG x=%0d de=%b mr=%h mg=%h mb=%h vga=%h%h%h winopd=%b bshow=%b", dx, de, mr, mg, mb, vga_r, vga_g, vga_b, win_op_d, bmap_show_a);
    end
`endif
endmodule

`default_nettype wire
