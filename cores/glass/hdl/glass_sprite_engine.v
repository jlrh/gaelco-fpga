// ============================================================================
//  Glass (Gaelco) — Motor de SPRITES por LINEA (line buffer doble).
//
//  Modelo MAME (glass.cpp draw_sprites): spriteRAM 0x800 words, 4 words/sprite,
//  lista i = 3,7,...,2043 (FORWARD; transpen plano -> el ULTIMO dibujado = i mas ALTO = ENCIMA).
//  3 words usados:
//    w0(i)  : [7:0]=Y  [14]=flipx  [15]=flipy           (attr=w0>>9: bit5=flipx, bit6=flipy)
//    w2(i+2): [8:0]=X  [12:9]=color(4b)
//    w3(i+3): [15:0]=number -> code15 = {number[0], number[15:2]}  (mismo decode que el tile)
//  Geometria: cada sprite = 1 TILE 16x16 (gfx 0 = tilelayout16 glass, igual que el tilemap).
//    sy=(240-Y)&0xff ; screenX = sx - 0x0f + col(0..15) ; screenY = sy + row(0..15).
//    color de paleta = 0x10 + (color&0xf)  -> bloque 0x10..0x1f.
//  gfx 16x16 4bpp (two-halves h13+h11): rom_a = code15*32 + col3*16 + row ; pen={p3,p2,p1,p0}[7-col[2:0]].
//    SDRAM bank1 word[a]={h13[2a],h13[2a+1],h11[2a],h11[2a+1]} -> rom_a = a directo (sin swap).
//
//  Line buffer (13b): {prio[2:0]=0, color[5:0], pen[3:0]}. pen 0 = transparente.
//  Para "i mas alto ENCIMA" itero spr_idx de ALTO a BAJO con FIRST-WRITE-WINS (el primero que reclama
//  el pixel = el i mas alto). Doble buffer ping-pong. Motor a clk pleno (ce=1).
// ============================================================================
`default_nettype none

module glass_sprite_engine (
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
    output wire [12:0] lb_q,         // {prio[2:0], color[5:0], pen[3:0]}

    input  wire        wbank,
    input  wire        rbank
);
    localparam [3:0] IDLE=0, CLR=1, RDW0=2, RDW2=3, RDW3=4, TEST=5, CADDR=6, PADDR=7, PWR=8, NEXT=9, DON=10, CWAIT=11;

    reg [3:0]  state;
    reg [10:0] spr_idx;
    reg [9:0]  clr_i;
    reg [8:0]  line_r;
    reg [15:0] w0_r, w2_r, w3_r;
    reg        flipx_r, flipy_r;
    reg [8:0]  sx_r;
    reg [5:0]  color_r;
    reg [2:0]  prio_r;
    reg [14:0] code_r;        // codigo de sprite glass (15b, mascarado a 32768 tiles)
    reg [3:0]  rowq_r;        // fila dentro del tile 16x16 (con flipY)
    reg        cellcol;       // mitad de salida: 0 = izquierda(col 0..7), 1 = derecha(col 8..15)
    reg [2:0]  px;            // pixel dentro de la mitad (0..7)

    // line buffer doble (2 x 320 x 13)
    reg [12:0] lb0 [0:367];   // glass: visarea 368 ancho
    reg [12:0] lb1 [0:367];
    reg        wbank_r;
    assign lb_q = rbank ? lb1[lb_x] : lb0[lb_x];

    // --- spriteRAM (registrada +1): presentar addr 1 ciclo antes ---
    assign spr_a = (state==CLR && clr_i==10'd367) ? 11'd2043 :   // preload w0 del PRIMER sprite (idx 2043)
                   (state==NEXT) ? (spr_idx - 11'd4) :     // sig. sprite (lista descendente) -> w0
                   (state==RDW0) ? (spr_idx + 11'd2) :     // w2
                   (state==RDW2) ? (spr_idx + 11'd3) : 11'd0;  // w3

    // --- direccion gfx (tile 16x16; col3 = mitad del tile a leer, con flipX) ---
    wire       col3 = flipx_r ? ~cellcol : cellcol;
    wire [19:0] rom_a_lin = {code_r, 5'b00000} + {15'b0, col3, rowq_r};  // code15*32 + col3*16 + row
    assign rom_a = rom_a_lin;     // bank1 ya de-interleaveado (sin swap de bloque)

    // --- decodificacion del pixel ---
    wire [2:0] gpx  = flipx_r ? (3'd7 - px) : px;
    wire [2:0] bsel = 3'd7 - gpx;
    wire [3:0] pen  = { d_p3[bsel], d_p2[bsel], d_p1[bsel], d_p0[bsel] };
    // screenX = sx - 0x0f + (mitad)*8 + px
    wire [9:0] xbase = {1'b0,sx_r} + (cellcol ? 10'd8 : 10'd0) - 10'd15;
    wire [9:0] xpos  = xbase + {7'b0, px};
    wire       xin   = (xpos < 10'd368);
    wire [8:0] lb_wa = xpos[8:0];

    // --- interseccion sprite/linea (16x16 siempre) ---
    wire [7:0] sy0    = 8'd240 - spr_q[7:0];
    wire [8:0] py0    = (line_r - {1'b0, sy0}) & 9'h1ff;
    wire       online0= (py0 < 9'd16);
    wire [7:0] sy_c   = 8'd240 - w0_r[7:0];
    wire [8:0] py_c   = (line_r - {1'b0, sy_c}) & 9'h1ff;
    wire [3:0] spr_row= w0_r[15] ? (4'd15 - py_c[3:0]) : py_c[3:0];   // fila con flipY (16)

    // --- escritura del line buffer (FIRST WRITE WINS = i mas alto ENCIMA, como glass transpen) ---
    wire [12:0] lb_cur   = wbank_r ? lb1[lb_wa] : lb0[lb_wa];
    wire        lb_empty = (lb_cur[3:0] == 4'd0);
    always @(posedge clk) if (ce) begin
        if (state==CLR) begin
            if (wbank_r) lb1[clr_i[8:0]] <= 13'd0; else lb0[clr_i[8:0]] <= 13'd0;
        end else if (state==PWR && (pen != 4'd0) && xin && lb_empty) begin
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
            CLR:  begin clr_i <= clr_i + 1'b1; if (clr_i == 10'd367) begin spr_idx <= 11'd2043; state <= RDW0; end end
            RDW0: begin w0_r <= spr_q; state <= online0 ? RDW2 : NEXT; end
            RDW2: begin w2_r <= spr_q; state <= RDW3; end
            RDW3: begin w3_r <= spr_q; state <= TEST; end
            TEST: begin
                flipx_r <= w0_r[14]; flipy_r <= w0_r[15];
                sx_r    <= w2_r[8:0];
                color_r <= {2'b01, w2_r[12:9]};          // 0x10 + (color&0xf)
                prio_r  <= 3'd0;                          // glass: sprites sin prioridad
                code_r  <= {w3_r[0], w3_r[15:2]};         // glass code15 = {number[0], number[15:2]}
                rowq_r  <= spr_row;                       // fila 0..15 (flipY aplicado)
                cellcol <= 1'b0; px <= 3'd0;
                state <= (py_c < 9'd16) ? CADDR : NEXT;
            end
            CADDR: state <= PADDR;                 // (rom_a ya combinacional desde code_r/col3/rowq)
            PADDR: if (gfx_ok) state <= PWR;        // espera dato gfx de la mitad (rom_a estable 8 px)
            PWR: begin
                if (px == 3'd7) begin
                    if (cellcol==1'b0) begin cellcol <= 1'b1; px <= 3'd0; state <= CADDR; end  // mitad derecha
                    else state <= NEXT;
                end else begin px <= px + 1'b1; state <= PWR; end
            end
            NEXT: if (spr_idx >= 11'd7) begin spr_idx <= spr_idx - 11'd4; state <= RDW0; end
                  else state <= DON;
            DON:  begin busy <= 1'b0; state <= IDLE; end
            default: state <= IDLE;
        endcase
    end

`ifdef GLASS_SPRDBG
    // DIAG: cuenta sprites on-line procesados por linea y detecta over-budget (start con busy alto).
    integer non=0;
    always @(posedge clk) if (ce) begin
        if (start) begin
            if (busy) $display("SPR OVERBUDGET! start con busy line=%0d non_prev=%0d state=%0d spr_idx=%0d", line, non, state, spr_idx);
            non <= 0;
        end else if (state==TEST && (py_c < 9'd16)) non <= non + 1;
        else if (state==DON) $display("SPR line=%0d on-line=%0d (fin OK)", line_r, non);
    end
`endif
    // synthesis translate_off
    integer k;
    initial begin state=IDLE; busy=0; spr_idx=2043; px=0; clr_i=0; wbank_r=0; cellcol=0;
        for (k=0;k<368;k=k+1) begin lb0[k]=0; lb1[k]=0; end end
    // synthesis translate_on
endmodule

`default_nettype wire
