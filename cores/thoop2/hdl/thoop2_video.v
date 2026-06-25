// ============================================================================
//  Thunder Hoop (Gaelco) — thoop2_video.v: compositor de los 2 tilemaps (Tipo-1).
//
//  Instancia 2 thoop2_tilemap (L0, L1) con scroll aplicado y resuelve la PRIORIDAD
//  multipasada de screen_update_squash (gaelco_v.cpp:250-292) por PIXEL via una tabla
//  de RANGO (orden painter's back->front; gana el rango mas alto).
//
//  Split-pen (set_transmask 0xff01/0x00ff): cada pixel de tile es
//    pen 0      -> transparente
//    pen 1-7    -> "front" (LAYER0)
//    pen 8-15   -> "back"  (LAYER1)   (isback = pen[3])
//  Rango por (capa T, isback, categoria) = posicion en el orden de dibujo de MAME
//  (cat3 abajo .. cat0 arriba; con el reorden de cat1 donde se intercalan sprites).
//  ⚠️ MAME marca la prioridad como NO verificada -> CALIBRAR contra captura.
//
//  Scroll (set_scrolly/set_scrollx): L0 sx=vregs[1]+4 sy=vregs[0]; L1 sx=vregs[3] sy=vregs[2].
//  Salida: indice de paleta del ganador (color*16+pen, 10b) + rango (para mezcla de sprite).
// ============================================================================
`default_nettype none

module thoop2_video (
    input  wire        clk,
    input  wire        ce,           // ce_pix
    input  wire [8:0]  hpos,         // 0..319
    input  wire [8:0]  vpos,         // 0..239

    input  wire [15:0] vreg_l0y, vreg_l0x, vreg_l1y, vreg_l1x,

    // tilemap L0 (videoram + gfx). rom_a 21b = gfx 8MB DW32.
    output wire [10:0] tile_a0, input wire [31:0] tile_q0,
    output wire [20:0] rom_a0,  input wire [7:0] d0_p0, d0_p1, d0_p2, d0_p3, input wire gfx0_ok,
    // tilemap L1
    output wire [10:0] tile_a1, input wire [31:0] tile_q1,
    output wire [20:0] rom_a1,  input wire [7:0] d1_p0, d1_p1, d1_p2, d1_p3, input wire gfx1_ok,

    // salida (registrada, alineada): indice de paleta del ganador + rango + opaco
    output reg  [9:0]  pal_index,    // color*16 + pen (0..1023). 0 = backdrop
    output reg  [4:0]  win_rank,     // rango del pixel ganador (para mezcla con sprite)
    output reg         win_opaque,
    // buffer de prioridad (= screen.priority() de MAME): OR de los CÓDIGOS de prioridad de
    // TODAS las capas de tilemap opacas en este pixel. El sprite lo testea con su pri_mask.
    output reg  [3:0]  prio_buf
);
    // ---- scroll: coordenada de tilemap (512x512, wrap) ----
    // +16 vertical = visarea Y de MAME empieza en 16 (igual que el sprite layer). FIX desplazamiento HW.
    // tilemap +1px a la DERECHA (medido vs MAME 0210: el tilemap salia 1px a la izquierda; sprites OK).
    // Se baja el offset en 1 en AMBAS capas (preserva el relativo L0-L1 = +4).
    wire [8:0] tmx0 = hpos + vreg_l0x[8:0] + 9'd3;
    wire [8:0] tmy0 = vpos + vreg_l0y[8:0] + 9'd16;
    wire [8:0] tmx1 = hpos + vreg_l1x[8:0] - 9'd1;
    wire [8:0] tmy1 = vpos + vreg_l1y[8:0] + 9'd16;

    // ---- 2 tilemaps (misma latencia -> salidas alineadas) ----
    wire [3:0] pen0, pen1; wire [5:0] color0, color1; wire [1:0] cat0, cat1;
    thoop2_tilemap u_l0 (
        .clk(clk), .ce(ce), .tmx(tmx0), .tmy(tmy0), .layer(1'b0),
        .tile_a(tile_a0), .tile_q(tile_q0),
        .rom_a(rom_a0), .d_p0(d0_p0), .d_p1(d0_p1), .d_p2(d0_p2), .d_p3(d0_p3), .gfx_ok(gfx0_ok),
        .pen(pen0), .color(color0), .category(cat0)
    );
    thoop2_tilemap u_l1 (
        .clk(clk), .ce(ce), .tmx(tmx1), .tmy(tmy1), .layer(1'b1),
        .tile_a(tile_a1), .tile_q(tile_q1),
        .rom_a(rom_a1), .d_p0(d1_p0), .d_p1(d1_p1), .d_p2(d1_p2), .d_p3(d1_p3), .gfx_ok(gfx1_ok),
        .pen(pen1), .color(color1), .category(cat1)
    );

    // ---- rango painter's: f(T, isback, cat) -> 0..15 (mayor = mas arriba) ----
    function [4:0] rank;
        input        t;        // 0=L0, 1=L1
        input        isback;   // 1 = pen 8-15 (LAYER1), 0 = pen 1-7 (LAYER0)
        input [1:0]  cat;
        case ({cat, t, isback})
            {2'd3,1'b1,1'b1}: rank=5'd0;  {2'd3,1'b1,1'b0}: rank=5'd1;
            {2'd3,1'b0,1'b1}: rank=5'd2;  {2'd3,1'b0,1'b0}: rank=5'd3;
            {2'd2,1'b1,1'b1}: rank=5'd4;  {2'd2,1'b1,1'b0}: rank=5'd5;
            {2'd2,1'b0,1'b1}: rank=5'd6;  {2'd2,1'b0,1'b0}: rank=5'd7;
            {2'd1,1'b1,1'b1}: rank=5'd8;  {2'd1,1'b0,1'b1}: rank=5'd9;
            {2'd1,1'b1,1'b0}: rank=5'd10; {2'd1,1'b0,1'b0}: rank=5'd11;
            {2'd0,1'b1,1'b1}: rank=5'd12; {2'd0,1'b1,1'b0}: rank=5'd13;
            {2'd0,1'b0,1'b1}: rank=5'd14; default:           rank=5'd15;
        endcase
    endfunction

    // ---- código de prioridad que MAME escribe en screen.priority() por (isback, cat) ----
    // EXACTO de thoop2_state::screen_update (thoop2.cpp:307-329 — thoop2 tiene su PROPIO update, NO el de
    // squash/gaelco_v.cpp). El último arg de cada pant->draw() = código OReado en screen.priority() donde
    // el pixel es opaco. LAYER1 = back pens 8-15, LAYER0 = front pens 1-7. Valores de thoop2.cpp:
    //   cat3: back=0 front=1 | cat2: back=1 front=2 | cat1: back=2 front=4 | cat0: back=4 front=8
    // (Esta tabla YA era correcta; el cambio de V003 a valores de squash fue un error -> revertido.)
    function [3:0] pcode;
        input        isback;
        input [1:0]  cat;
        case ({cat, isback})
            {2'd3,1'b1}: pcode=4'd0;  {2'd3,1'b0}: pcode=4'd1;
            {2'd2,1'b1}: pcode=4'd1;  {2'd2,1'b0}: pcode=4'd2;
            {2'd1,1'b1}: pcode=4'd2;  {2'd1,1'b0}: pcode=4'd4;
            {2'd0,1'b1}: pcode=4'd4;  default:      pcode=4'd8;  // cat0 front = 8
        endcase
    endfunction

`ifdef THOOP_L1ONLY
    wire op0 = 1'b0;                 // diag: solo capa L1
`elsif THOOP_L0ONLY
    wire op0 = (pen0 != 4'd0);
`else
    wire op0 = (pen0 != 4'd0);
`endif
`ifdef THOOP_L0ONLY
    wire op1 = 1'b0;                 // diag: solo capa L0
`else
    wire op1 = (pen1 != 4'd0);
`endif

`ifdef THOOP_LINETRACE
    // DIAG: traza pen0/op0 por hpos en una scanline de barras (vpos fijo) -> patron de huecos en X.
    always @(posedge clk) if (ce && vpos==9'd85) begin
        $display("LT hpos=%0d pen0=%h op0=%b col0=%h g0ok=%b rom0=%h ta0=%h", hpos, pen0, op0, color0, gfx0_ok, rom_a0, tile_a0);
    end
`endif
`ifdef SIMULATION
    integer n_ce=0, n_g0=0, n_g1=0, n_op0=0, n_op1=0;
    always @(posedge clk) if (ce) begin
        n_ce<=n_ce+1;
        if (gfx0_ok) n_g0<=n_g0+1;
        if (gfx1_ok) n_g1<=n_g1+1;
        if (op0) n_op0<=n_op0+1;
        if (op1) n_op1<=n_op1+1;
        if (n_ce[18:0]==0) $display("VIDDBG ce=%0d g0ok=%0d g1ok=%0d op0=%0d op1=%0d | pen0=%h pen1=%h col0=%h col1=%h gfx0d=%h rom0=%h",
            n_ce, n_g0, n_g1, n_op0, n_op1, pen0, pen1, color0, color1, {d0_p3,d0_p2,d0_p1,d0_p0}, rom_a0);
    end
`endif
    wire [4:0] r0 = rank(1'b0, pen0[3], cat0);
    wire [4:0] r1 = rank(1'b1, pen1[3], cat1);

    // buffer de prioridad = OR de los códigos de TODAS las capas opacas (= |= de MAME)
    wire [3:0] pc0 = op0 ? pcode(pen0[3], cat0) : 4'd0;
    wire [3:0] pc1 = op1 ? pcode(pen1[3], cat1) : 4'd0;
    wire [3:0] prio_buf_c = pc0 | pc1;

    // gana el opaco de mayor rango; si ambos transparentes -> backdrop (indice 0)
    wire l0_wins = op0 & (~op1 | (r0 >= r1));
    always @(posedge clk) if (ce) begin
        prio_buf <= prio_buf_c;          // registrado junto a pal_index (mismo stage)
        if (op0 & l0_wins) begin
            pal_index <= {color0, pen0}; win_rank <= r0; win_opaque <= 1'b1;
        end else if (op1) begin
            pal_index <= {color1, pen1}; win_rank <= r1; win_opaque <= 1'b1;
        end else begin
            pal_index <= 10'd0; win_rank <= 5'd0; win_opaque <= 1'b0;
        end
    end
endmodule

`default_nettype wire
