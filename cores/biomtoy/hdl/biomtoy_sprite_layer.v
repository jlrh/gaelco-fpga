// ============================================================================
//  Thunder Hoop (Gaelco) — CAPA de sprites en tiempo real (doble buffer ping-pong).
//
//  Envuelve biomtoy_sprite_engine: mientras se MUESTRA la linea N (banco N[0]), RENDERIZA
//  la N+1 en el otro banco. Motor a clk pleno (ce=1) -> presupuesto de un scanline para
//  los ~512 sprites (con early-out de los fuera de linea). 1 pulso start por cambio de vpos.
//  line = next_vpos + 16 (visarea Y empieza en 16; calibrable).
// ============================================================================
`default_nettype none

module biomtoy_sprite_layer #(
    parameter VTOTAL = 348,
    parameter integer YOFFS = 16
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [8:0]  vpos,          // linea visible / vblank
    input  wire [8:0]  hpos,          // x visible (0..319) = lb_x

    output wire [10:0] spr_a,  input wire [15:0] spr_q,
    output wire [19:0] rom_a,  input wire [7:0] d_p0, d_p1, d_p2, d_p3, input wire gfx_ok,

    output wire [12:0] lb_q,          // {priority[2:0], color[5:0], pen[3:0]}
    output wire        busy
);
    reg [8:0] vpos_d;
    always @(posedge clk) vpos_d <= vpos;
    wire line_change = (vpos != vpos_d);

    wire [8:0] next_vpos = (vpos == VTOTAL-1) ? 9'd0 : (vpos + 9'd1);
    wire       rbank = vpos[0];
    wire       wbank = next_vpos[0];

    // SOLO-SIM: durante el boot la spriteRAM tiene basura del test de RAM; saltamos el procesado de
    // sprites hasta pasar el boot (frame ~150). NO afecta a HW. OFF en replay (escena limpia).
    wire boot_skip;
`ifdef BIOMTOY_SCENE
    assign boot_skip = 1'b0;
`elsif SIMULATION
    reg [15:0] frm = 0;
    always @(posedge clk) if (line_change && vpos==9'd0) frm <= frm + 16'd1;
    assign boot_skip = (frm < 16'd150);
`else
    assign boot_skip = 1'b0;
`endif

    reg start;
    always @(posedge clk or posedge rst) begin
        if (rst) start <= 1'b0; else start <= line_change & ~boot_skip;
    end

    biomtoy_sprite_engine u_spr (
        .clk(clk), .ce(1'b1), .start(start), .line(next_vpos + YOFFS[8:0]), .busy(busy),
        .spr_a(spr_a), .spr_q(spr_q),
        .rom_a(rom_a), .d_p0(d_p0), .d_p1(d_p1), .d_p2(d_p2), .d_p3(d_p3), .gfx_ok(gfx_ok),
        .lb_x(hpos), .lb_q(lb_q),
        .wbank(wbank), .rbank(rbank)
    );
endmodule

`default_nettype wire
