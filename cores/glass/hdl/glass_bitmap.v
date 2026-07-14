// ============================================================================
//  Glass (Gaelco) — glass_bitmap.v: CAPA BITMAP del blitter (lo NUEVO de glass).
//
//  glass.cpp: m_screen_bitmap 320x200 indexado (1 byte/pixel) desde H9 (1MB=16 imgs) por el blitter.
//  screen_update: fill(black); copybitmap(@ 0x18,0x24); tm1; tm0; sprites. => bitmap = capa MAS DE FONDO,
//  opaca, region 320x200 en pantalla (destx=0x18=24, desty=0x24=36; visarea Y empieza en 16 -> fila 20).
//
//  Pixel: bmap_index(ox,oy) = H9[ blit_base + (oy-YOFF)*320 + (ox-XOFF) ]. blit_base ya incluye +0x140+imagen.
//
//  IMPLEMENTACION = LINE BUFFER ping-pong (robusto a la latencia SDRAM): un FSM a clk PLENO STREAMEA los
//  320 bytes de la linea SIGUIENTE (h9_addr COMBINACIONAL = frow+fi, cs=1, captura en h9_ok, ++fi) en el
//  buffer de escritura, mientras el display lee el buffer de la linea actual. El read per-pixel fallaba
//  ~7% porque a 1 read/ce_pix la SDRAM se atrasaba; aqui el fetch corre a clk pleno (320 reads << 1 linea).
//  OJO: el bank3 del sim necesita BYTESWAP de pares (sim[2k]=h9[2k+1]); lo hace glass_sim_prep.
// ============================================================================
`default_nettype none

module glass_bitmap #(
    parameter [8:0] XOFF = 9'd24,    // destx (pantalla)
    parameter [8:0] YOFF = 9'd20     // fila de salida (screen y 36 - visarea 16)
)(
    input  wire        clk,
    input  wire        ce_pix,
    input  wire [8:0]  hpos,         // 0..367
    input  wire [8:0]  vpos,         // 0..239
    input  wire [19:0] blit_base,    // base en H9 (incluye +0x140 + imagen)
    input  wire        blit_active,

    // SDRAM H9 (bus bmap, DW8) con handshake
    output wire [19:0] h9_addr,
    output reg         h9_cs,
    input  wire [7:0]  h9_data,
    input  wire        h9_ok,

    // salida (alinear en video_top con BPN): indice de paleta del bitmap + en-region
    output reg  [7:0]  bmap_index,
    output reg         bmap_show
);
    // ---- line buffers ping-pong (2 x 320 x 8) ----
    reg [7:0] lb0 [0:319];
    reg [7:0] lb1 [0:319];
    reg       wbank;                 // buffer que se ESCRIBE (linea siguiente)
    wire      rbank = vpos[0];       // buffer que se LEE (linea actual)

    // ---- display: lee el line buffer en la X visible de la region ----
    wire in_x = (hpos >= XOFF) && (hpos < XOFF + 9'd320);
    wire in_y = (vpos >= YOFF) && (vpos < YOFF + 9'd200);
    wire in_region = in_x && in_y && blit_active;
    wire [8:0] rx = hpos - XOFF;     // 0..319
    wire [7:0] rd = rbank ? lb1[rx[8:0]] : lb0[rx[8:0]];
    always @(posedge clk) if (ce_pix) begin
        bmap_index <= rd;
        bmap_show  <= in_region;
    end
`ifdef GLASS_BMTRACE
    always @(posedge clk) if (ce_pix && vpos==9'd150 && hpos>=9'd100 && hpos<=9'd115)
        $display("BMDISP vpos=150 hpos=%0d rx=%0d rd=%02x", hpos, rx, rd);
`endif

    // ---- FSM de fetch (a clk PLENO): STREAMEA la linea SIGUIENTE ----
    reg        fbusy;
    reg [8:0]  fi;                   // indice de fetch 0..319
    reg [19:0] frow;                 // blit_base + j_next*320
    assign h9_addr = frow + {11'd0, fi};   // COMBINACIONAL: estable mientras se espera ok

    reg [8:0]  vpos_d;
    always @(posedge clk) vpos_d <= vpos;
    wire line_change = (vpos != vpos_d);
    wire [8:0] vnext = (vpos==9'd239) ? 9'd0 : (vpos + 9'd1);
    wire       next_in_y = blit_active && (vnext >= YOFF) && (vnext < YOFF + 9'd200);
    wire [7:0] jnext = vnext[7:0] - YOFF[7:0];
    wire [19:0] jrow = {jnext, 8'd0} + {2'd0, jnext, 6'd0};   // j*320

    always @(posedge clk) begin
        if (line_change) begin
`ifdef GLASS_BMTRACE
            if (fbusy && fi != 9'd319) $display("BMINCOMPLETE vpos=%0d fi=%0d (fetch no completo)", vpos, fi);
`endif
            wbank <= ~vpos[0];           // el buffer NO leido = el de la linea siguiente
            fi    <= 9'd0;
            frow  <= blit_base + jrow;
            fbusy <= next_in_y;
            h9_cs <= next_in_y;
        end else if (fbusy) begin
            if (h9_ok) begin
                if (wbank) lb1[fi[8:0]] <= h9_data; else lb0[fi[8:0]] <= h9_data;
                if (fi == 9'd319) begin fbusy <= 1'b0; h9_cs <= 1'b0; end
                else fi <= fi + 9'd1;
            end
        end
    end

    // synthesis translate_off
    integer k;
    initial begin fbusy=0; fi=0; wbank=0; h9_cs=0;
        for(k=0;k<320;k=k+1) begin lb0[k]=0; lb1[k]=0; end end
    // synthesis translate_on
endmodule

`default_nettype wire
