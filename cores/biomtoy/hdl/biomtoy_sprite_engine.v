// ============================================================================
//  Thunder Hoop (Gaelco) — Motor de SPRITES por LINEA (Tipo-1, line buffer doble).
//
//  Modelo MAME (gaelco_v.cpp draw_sprites): spriteRAM 0x800 words, 4 words/sprite,
//  lista i = 0x7FB..3 step -4 (indice BAJO = dibujado ULTIMO = encima -> "last write wins"
//  iterando de ALTO a BAJO). 3 words usados:
//    w0(i)  : [7:0]=Y  [11]=size(1=8x8 / 0=16x16, code&=~3)  [13:12]=priority  [14]=flipx  [15]=flipy
//    w2(i+2): [8:0]=X  [14:9]=color
//    w3(i+3): [15:0]=code (number)
//  Geometria: sy=(240-Y)&0xff ; celdas 8x8: cell = number + xoff[ex] + yoff[ey],
//    xoff[2]={0,2} yoff[2]={0,1} ; screenX = sx - 0x0f + cx*8 + px ; screenY = sy + cy*8.
//  force_high: si color>=0x38 -> priority=4. gfx 8x8: rom_a = code*8 + row (biomtoy_gfx_decode is8).
//
//  Line buffer (13b): {priority[2:0], color[5:0], pen[3:0]}. pen 0 = transparente.
//  Doble buffer ping-pong (render linea N+1 mientras se muestra N). Motor a clk pleno (ce=1).
// ============================================================================
`default_nettype none

module biomtoy_sprite_engine (
    input  wire        clk,
    input  wire        ce,
    input  wire        start,        // pulso: renderiza la linea `line`
    input  wire [8:0]  line,         // screenY a renderizar
    output reg         busy,

    // spriteRAM (lectura REGISTRADA +1; word 0..2047)
    output wire [10:0] spr_a,
    input  wire [15:0] spr_q,
    // gfx ROM (registrada/slot SDRAM con gfx_ok)
    output wire [19:0] rom_a,
    input  wire [7:0]  d_p0, d_p1, d_p2, d_p3,
    input  wire        gfx_ok,

    // line buffer: lectura async para el compositor (por X visible 0..319)
    input  wire [8:0]  lb_x,
    output wire [12:0] lb_q,         // {priority[2:0], color[5:0], pen[3:0]}

    input  wire        wbank,
    input  wire        rbank
);
    localparam [3:0] IDLE=0, CLR=1, RDW0=2, RDW2=3, RDW3=4, TEST=5, CADDR=6, PADDR=7, PWR=8, NEXT=9, DON=10;

    reg [3:0]  state;
    reg [10:0] spr_idx;
    reg [9:0]  clr_i;
    reg [8:0]  line_r;
    reg [15:0] w0_r, w2_r, w3_r;
    reg        flipx_r, flipy_r, size16_r;
    reg [8:0]  sx_r;
    reg [5:0]  color_r;
    reg [2:0]  prio_r;
    reg [15:0] code_r;        // codigo de sprite COMPLETO (16b, como MAME number=spriteram[i+3])
    reg [3:0]  rowq_r;        // fila dentro de la celda 8x8 (con flipY)
    reg        cellrow_r;     // fila de celda (cy: 0 o 1) que toca esta linea
    reg        cellcol;       // columna de celda actual (cx: 0..size-1)
    reg [2:0]  px;            // pixel dentro de la celda (0..7)

    // line buffer doble (2 x 320 x 13)
    reg [12:0] lb0 [0:319];
    reg [12:0] lb1 [0:319];
    reg        wbank_r;
    assign lb_q = rbank ? lb1[lb_x] : lb0[lb_x];

    // --- spriteRAM (registrada +1): presentar addr 1 ciclo antes (como WRally) ---
    assign spr_a = (state==CLR && clr_i==10'd319) ? 11'd2043 :   // preload w0 del PRIMER sprite (idx 2043)
                   (state==NEXT) ? (spr_idx - 11'd4) :     // sig. sprite (lista descendente) -> w0
                   (state==RDW0) ? (spr_idx + 11'd2) :     // w2
                   (state==RDW2) ? (spr_idx + 11'd3) : 11'd0;  // w3

    // --- celda y direccion gfx ---
    wire [1:0] xoff = cellcol ? 2'd2 : 2'd0;               // x_offset[cx] = {0,2}
    wire       ex   = flipx_r ? (size16_r & ~cellcol) : cellcol;  // ex (col de celda con flip; size16 -> 0/1)
    wire [1:0] xoff_e = (flipx_r & size16_r) ? (cellcol ? 2'd0 : 2'd2) : xoff;
    wire [15:0] cell_code = code_r + {14'b0, xoff_e} + {15'b0, cellrow_r}; // + y_offset (cy=0->0,1->1)
    wire [2:0]  gpx = flipx_r ? (3'd7 - px) : px;
    wire [19:0] rom_a_lin = {1'b0, cell_code, 3'b000} + {17'b0, rowq_r[2:0]}; // code*8 + row (8x8), code 16b
    // DE-INTERLEAVE [0,2,1,3] del gfx (igual que el tilemap): swap bits de bloque 0x40000 ([19]<->[18]).
    // El .mra carga c-ROMs CRUDAS -> el blob del sim DEBE venir del romset RAW (no biomtoy_di).
    assign rom_a = { rom_a_lin[18], rom_a_lin[19], rom_a_lin[17:0] };

    // --- decodificacion del pixel ---
    wire [2:0] bsel = 3'd7 - gpx;
    wire [3:0] pen  = { d_p3[bsel], d_p2[bsel], d_p1[bsel], d_p0[bsel] };
    // screenX = sx - 0x0f + cx*8 + px
    wire [9:0] xbase = {1'b0,sx_r} + (cellcol ? 10'd8 : 10'd0) - 10'd15;
    wire [9:0] xpos  = xbase + {7'b0, px};
    wire       xin   = (xpos < 10'd320);
    wire [8:0] lb_wa = xpos[8:0];

    // --- interseccion sprite/linea (sobre w0 en RDW0 early-out) ---
    wire [7:0] sy0    = 8'd240 - spr_q[7:0];
    wire [8:0] py0    = (line_r - {1'b0, sy0}) & 9'h1ff;
    wire [4:0] sprh0  = spr_q[11] ? 5'd8 : 5'd16;          // alto: 8 (8x8) o 16 (16x16). 5 bits: 16 NO cabe en 4 (BUG: 16x16 nunca online)
    wire       online0= (py0 < {4'b0, sprh0});
    // py para el sprite latcheado (TEST) + fila dentro del sprite (con flipY)
    wire [7:0] sy_c   = 8'd240 - w0_r[7:0];
    wire [8:0] py_c   = (line_r - {1'b0, sy_c}) & 9'h1ff;
    wire [4:0] spr_h  = w0_r[11] ? 5'd8 : 5'd16;                          // alto del sprite
    wire [4:0] spr_row= w0_r[15] ? (spr_h - 5'd1 - py_c[4:0]) : py_c[4:0]; // fila con flipY

    // --- escritura del line buffer ---
    always @(posedge clk) if (ce) begin
        if (state==CLR) begin
            if (wbank_r) lb1[clr_i[8:0]] <= 13'd0; else lb0[clr_i[8:0]] <= 13'd0;
        end else if (state==PWR && (pen != 4'd0) && xin) begin
            if (wbank_r) lb1[lb_wa] <= {prio_r, color_r, pen};
            else         lb0[lb_wa] <= {prio_r, color_r, pen};
        end
    end

    // --- FSM ---
    always @(posedge clk) if (ce) begin
        if (start) begin
            line_r <= line; clr_i <= 10'd0; busy <= 1'b1; wbank_r <= wbank; state <= CLR;
        end else case (state)
            IDLE: ;
            CLR:  begin clr_i <= clr_i + 1'b1; if (clr_i == 10'd319) begin spr_idx <= 11'd2043; state <= RDW0; end end
            RDW0: begin w0_r <= spr_q; state <= online0 ? RDW2 : NEXT; end
            RDW2: begin w2_r <= spr_q; state <= RDW3; end
            RDW3: begin w3_r <= spr_q; state <= TEST; end
            TEST: begin
                flipx_r  <= w0_r[14]; flipy_r <= w0_r[15];
                size16_r <= ~w0_r[11];                       // bit11=1 -> 8x8 ; =0 -> 16x16
                sx_r     <= w2_r[8:0];
                color_r  <= w2_r[14:9];
                // force_high: color>=0x38 -> prioridad 4
                prio_r   <= (w2_r[14:9] >= 6'h38) ? 3'd4 : {1'b0, w0_r[13:12]};
                code_r   <= w0_r[11] ? w3_r[15:0] : {w3_r[15:2], 2'b00};  // codigo 16b (16x16: code&=~3)
                cellrow_r <= spr_row[3];          // cy (0 o 1) = fila de celda
                rowq_r    <= {1'b0, spr_row[2:0]}; // fila dentro de la celda 8x8
                cellcol <= 1'b0; px <= 3'd0;
                state <= (py_c < (w0_r[11] ? 9'd8 : 9'd16)) ? CADDR : NEXT;
            end
            CADDR: state <= PADDR;                 // (rom_a ya combinacional desde cell_code/rowq)
            PADDR: if (gfx_ok) state <= PWR;        // espera dato gfx de la celda (rom_a estable 8 px)
            PWR: begin
                if (px == 3'd7) begin
                    // fin de celda: si 16x16 y aun no hecha la 2a columna -> siguiente celda
                    if (size16_r && (cellcol==1'b0)) begin cellcol <= 1'b1; px <= 3'd0; state <= CADDR; end
                    else state <= NEXT;
                end else begin px <= px + 1'b1; state <= PWR; end
            end
            NEXT: if (spr_idx >= 11'd7) begin spr_idx <= spr_idx - 11'd4; state <= RDW0; end
                  else state <= DON;
            DON:  begin busy <= 1'b0; state <= IDLE; end
            default: state <= IDLE;
        endcase
    end

    // synthesis translate_off
    integer k;
    initial begin state=IDLE; busy=0; spr_idx=2043; px=0; clr_i=0; wbank_r=0; cellcol=0;
        for (k=0;k<320;k=k+1) begin lb0[k]=0; lb1[k]=0; end end
    // synthesis translate_on
endmodule

`default_nettype wire
