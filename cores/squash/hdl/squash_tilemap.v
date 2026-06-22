// ============================================================================
//  Squash (Gaelco) — Motor de TILEMAP de una capa (Tipo-1: 32x32, tiles 16x16, 4bpp)
//
//  Genera el pixel de UNA capa para una coordenada del espacio del tilemap (512x512).
//  El SCROLL es un offset que aplica el llamante antes de pasar (tmx,tmy) -> motor
//  agnostico al scroll (igual que WRally; arquitectura de pipeline reutilizada verbatim).
//
//  Formato de tile (gaelco_v.cpp get_tile_info):
//    data  = videoram[par]:   code=data[15:2], flipx=data[0], flipy=data[1]
//    data2 = videoram[impar]: color=data2[5:0] (64 bloques), categoria=data2[7:6] (0..3)
//    gfx base = 0x4000 + code  (los primeros 0x4000 tiles no se usan en pantalla)
//  gfx 16x16 4bpp: rom_a = code*32 + (col>=8?16:0) + row ; pen={p3,p2,p1,p0}[7-col[2:0]].
//
//  Pipeline (mismo esquema que wrally_tilemap, con prefetch gfx_ok + LEAD para la SDRAM):
//    -1 : registra (tmx,tmy)
//     0 : tile_a = {layer, ty, tx}              (lee el par {data,data2} de squash_vmem)
//     1 : tile_q -> attrs -> rom_a (gfx)
//   1.5 : prefetch de gfx en buffer lo/hi con gfx_ok, retraso LEAD
//     2 : decodifica pen del buffer -> salida (pen,color,categoria)
// ============================================================================
`default_nettype none

module squash_tilemap (
    input  wire        clk,
    input  wire        ce,          // pixel clock enable

    input  wire [8:0]  tmx,         // 0..511 (scroll ya aplicado, mod 512)
    input  wire [8:0]  tmy,         // 0..511
    input  wire        layer,       // 0 = L0, 1 = L1

    // puerto de lectura de tile de squash_vmem (par {data, data2}), latencia 1 ce
    output wire [10:0] tile_a,      // {layer, tile_index}  (tile_index = ty*32+tx)
    input  wire [31:0] tile_q,      // {data[31:16], data2[15:0]}

    // puerto de lectura ROM gfx (4 planos DW32), latencia variable con handshake
    output wire [19:0] rom_a,      // byte index intra-plano (0..0xFFFFF)
    input  wire [7:0]  d_p0, d_p1, d_p2, d_p3,
    input  wire        gfx_ok,

    input  wire [8:0]  dbg_hpos,    // DIAG: hpos crudo (para trazar el borde derecho)

    // salida (latencia fija; el compositor la alinea con el resto de capas)
    output reg  [3:0]  pen,         // 0..15 (pen 0 = transparente)
    output reg  [5:0]  color,       // bloque de paleta (64)
    output reg  [1:0]  category     // categoria/prioridad de la capa (0..3)
);
    // ---- Etapa -1 : registrar la coordenada (robusto a fuente sincrona; +1 ce) ----
    reg [8:0] tmx_r, tmy_r;
    always @(posedge clk) if (ce) begin tmx_r <= tmx; tmy_r <= tmy; end

    // ---- Etapa 0 : pedir el par de words del tile que contiene (tmx_r,tmy_r) ----
    wire [4:0]  tx = tmx_r[8:4];
    wire [4:0]  ty = tmy_r[8:4];
    wire [9:0]  tile_index = {ty, tx};        // fila*32 + col
    assign tile_a = {layer, tile_index};

    reg [3:0] col0_d, row0_d;
    always @(posedge clk) if (ce) begin
        col0_d <= tmx_r[3:0];
        row0_d <= tmy_r[3:0];
    end

    // ---- Etapa 1 : tile_q disponible -> attrs -> direccion de gfx ----
    wire [15:0] data  = tile_q[31:16];
    wire [15:0] data2 = tile_q[15:0];
    wire [14:0] code  = 15'h4000 + {1'b0, data[15:2]};   // base gfx 0x4000 + code (15b: 0x4000..0x7FFF)
    wire        flipx = data[0];
    wire        flipy = data[1];
    wire [5:0]  color1= data2[5:0];
    wire [1:0]  cat1  = data2[7:6];

    wire [3:0] row1 = flipy ? ~row0_d : row0_d;
    wire [3:0] col1 = flipx ? ~col0_d : col0_d;

    // rom_a = code*32 + (col>=8?16:0) + row   (code 15b -> code*32 cabe en 20b)
    assign rom_a = {code, 5'b00000} + {15'b0, col1[3], row1};

    // ---- Etapa 1.5 : prefetch de gfx (doble buffer lo/hi por col[3]) con gfx_ok ----
    localparam integer LEAD = 7;
    reg [7:0] gl0, gl1, gl2, gl3;     // buffer mitad LO (col[3]=0)
    reg [7:0] gh0, gh1, gh2, gh3;     // buffer mitad HI (col[3]=1)
    always @(posedge clk) if (ce && gfx_ok) begin
        if (col1[3]) begin gh0<=d_p0; gh1<=d_p1; gh2<=d_p2; gh3<=d_p3; end
        else         begin gl0<=d_p0; gl1<=d_p1; gl2<=d_p2; gl3<=d_p3; end
    end

    reg [5:0] color_d; reg [1:0] cat_d; reg [3:0] col_d;
    always @(posedge clk) if (ce) begin
        color_d <= color1; cat_d <= cat1; col_d <= col1;
    end
    reg [5:0] color_sr [0:LEAD-1];
    reg [1:0] cat_sr   [0:LEAD-1];
    reg [3:0] col_sr   [0:LEAD-1];
    integer si;
    always @(posedge clk) if (ce) begin
        color_sr[0] <= color_d; cat_sr[0] <= cat_d; col_sr[0] <= col_d;
        for (si = 1; si < LEAD; si = si + 1) begin
            color_sr[si] <= color_sr[si-1];
            cat_sr  [si] <= cat_sr  [si-1];
            col_sr  [si] <= col_sr  [si-1];
        end
    end
    wire [5:0] color_c = color_sr[LEAD-1];
    wire [1:0] cat_c   = cat_sr  [LEAD-1];
    wire [3:0] col_c   = col_sr  [LEAD-1];

    // ---- Etapa 2 : decodificar pen del buffer (mitad por col_c[3], bit por col_c[2:0]) ----
    wire [7:0] db0 = col_c[3] ? gh0 : gl0;
    wire [7:0] db1 = col_c[3] ? gh1 : gl1;
    wire [7:0] db2 = col_c[3] ? gh2 : gl2;
    wire [7:0] db3 = col_c[3] ? gh3 : gl3;
    wire [2:0] bbit = 3'd7 - col_c[2:0];
    wire [3:0] pen2 = { db3[bbit], db2[bbit], db1[bbit], db0[bbit] };  // p0=LSB..p3=MSB
    always @(posedge clk) if (ce) begin
        pen      <= pen2;
        color    <= color_c;
        category <= cat_c;
    end

`ifdef SQUASH_EDGETRACE
    // DIAG borde derecho: retrasar dbg_hpos ~LEAD+3 etapas para alinear con col_c (decode).
    localparam integer DBGD = LEAD + 3;
    reg [8:0] dbgh_sr [0:DBGD-1];
    integer di;
    always @(posedge clk) if (ce) begin
        dbgh_sr[0] <= dbg_hpos;
        for (di=1; di<DBGD; di=di+1) dbgh_sr[di] <= dbgh_sr[di-1];
    end
    wire [8:0] dbgh_c = dbgh_sr[DBGD-1];
    integer etn=0; reg seen_grad=0;
    // gate robusto: empezar a trazar SOLO cuando ya se ha dibujado contenido (tile no-vacio = la pantalla
    // de check ya esta), no por ciclos de clk (que disparaba en el arranque negro).
    always @(posedge clk) if (ce && layer==1'b0 && code!=15'h4000) seen_grad<=1'b1;
    always @(posedge clk) if (ce && layer==1'b0 && seen_grad && dbgh_c>=9'd300 && dbgh_c<=9'd320 && etn<90) begin
        $display("ET hpos=%0d colc=%0d gfxok=%b gl=%h%h%h%h gh=%h%h%h%h pen2=%h color=%h code=%h",
                 dbgh_c, col_c, gfx_ok, gl3,gl2,gl1,gl0, gh3,gh2,gh1,gh0, pen2, color_c, code);
        etn<=etn+1;
    end
`endif

`ifdef SQUASH_PENTRACE
    // DIAG: traza pen a lo largo de una scanline con contenido real (buffer gfx no-cero) en L0.
    integer ptn=0;
    // gradiente = tile multi-pen: los 4 bytes de plano (mitad baja) NO son todos iguales
    wire grad_tile = !(gl0==gl1 && gl1==gl2 && gl2==gl3) || !(gh0==gh1 && gh1==gh2 && gh2==gh3);
    always @(posedge clk) if (ce && grad_tile && col_c[2:0]==3'd0 && ptn<60) begin
        $display("PT %0d lay=%b colc=%0d code=%h gl=%h%h%h%h gh=%h%h%h%h pen2=%h color=%h",
                 ptn, layer, col_c, code, gl3,gl2,gl1,gl0, gh3,gh2,gh1,gh0, pen2, color_c);
        ptn<=ptn+1;
    end
`endif
endmodule

`default_nettype wire
