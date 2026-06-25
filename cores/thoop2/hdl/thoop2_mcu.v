// ============================================================================
//  Thunder Hoop 2 (Gaelco, Tipo-2 / chip GAE1) — Wrapper del DS5002FP (protección).
//
//  Clon del patrón PROBADO de WRally (`wrally_mcu.v`, swap-mc8051): core mc8051 de Oregano
//  (jtframe, COMPLETO: ALU/DA A/mul/div) con la ROM de programa (firmware DS5002, 32KB) externa
//  + IRAM 128B interna + MOVX al exterior, todo cen-paced. El routing del MOVX (0x8000-0xffff ->
//  RAM compartida del 68k ; <0x8000 -> SRAM scratch on-chip) se hace en aligator_main.
//
//  LECCIONES CRÍTICAS de WRally (verificadas en HW), aplican igual aquí:
//   - cen_eff = cen/12 (Oregano ~12x más rápido que un 8051 real -> velocidad real del DS5002 ~1MIPS).
//   - El rom_adr_o y el adrx_o del Oregano son COMBINACIONALES y oscilan dentro de un periodo de cen;
//     hay que RETENER rom_byte y datax_i en cen_eff o el core decodifica/lee BASURA (bucle de reset /
//     handshake atascado). Ver wrally-handoff-oraculo-r8051 / wrally-mc8051-swap-plan.
// ============================================================================
`default_nettype none

module thoop2_mcu #(
    parameter DIVCEN = 1              // 1 = dividir cen /12 (velocidad real del DS5002)
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        cen,           // mcu_cen base (= clk48/4 = 12 MHz, cristal del DS5002)

    // --- ROM de programa (firmware DS5002 32KB; BRAM/PROM externa en el game) ---
    output wire [15:0] rom_addr,
    output wire        rom_en,
    input  wire [ 7:0] rom_byte,      // dato 1 clk después de rom_addr

    // --- xdata (MOVX) -> routing en aligator_main (shram / scratch) ---
    output wire        xdata_rd,
    output wire        xdata_wr,
    output wire [15:0] xdata_addr,
    output wire [ 7:0] xdata_dout,
    input  wire [ 7:0] xdata_din
);
    // ===== divisor de cen /12 (idéntico a WRally) =====
    reg  [3:0] divcnt = 4'd0;
    reg        cen_div = 1'b0;
    always @(posedge clk) begin
        if (cen) divcnt <= (divcnt==4'd11) ? 4'd0 : divcnt + 4'd1;
        cen_div <= (divcnt==4'd1) && cen;
    end
    wire cen_eff = (DIVCEN!=0) ? cen_div : cen;

    // ---- señales del mc8051_core ----
    wire [15:0] core_rom_adr;
    wire [ 7:0] core_ram_q, core_ram_d, core_ram_adr;
    wire        core_ram_wr, core_ram_en;
    wire [ 7:0] core_datax_o;
    wire [15:0] core_adrx;
    wire        core_memx, core_wrx;

    // ===== ROM: dirección registrada 1 clk; dato RETENIDO en cen_eff (CRÍTICO) =====
    reg [15:0] rom_addr_r = 16'd0;
    always @(posedge clk) rom_addr_r <= core_rom_adr;
    assign rom_addr = rom_addr_r;
    assign rom_en   = 1'b1;
    reg [7:0] rom_data_q = 8'd0;
    always @(posedge clk) if (cen_eff) rom_data_q <= rom_byte;

    // ===== IRAM interna 128B (jtframe_ram_rst AW=8, CEN_RD=1) =====
    jtframe_ram_rst #(.AW(8),.CEN_RD(1)) u_iram (
        .rst(rst), .clk(clk), .cen(cen_eff),
        .addr(core_ram_adr), .data(core_ram_d), .we(core_ram_wr), .q(core_ram_q)
    );

    // ===== xdata (MOVX): salidas registradas 1 clk; dato RETENIDO en cen_eff (CRÍTICO) =====
    reg [15:0] x_addr_r = 16'd0;
    reg [ 7:0] x_dout_r = 8'd0;
    reg        x_wr_r = 1'b0, x_acc_r = 1'b0;
    always @(posedge clk) begin
        x_addr_r <= core_adrx;
        x_dout_r <= core_datax_o;
        x_wr_r   <= core_wrx;
        x_acc_r  <= core_memx;
    end
    assign xdata_addr = x_addr_r;
    assign xdata_dout = x_dout_r;
    assign xdata_rd   = x_acc_r & ~x_wr_r;
    assign xdata_wr   = x_acc_r &  x_wr_r;
    reg [7:0] xdata_din_q = 8'd0;
    always @(posedge clk) if (cen_eff) xdata_din_q <= xdata_din;

    // ===== el core (Oregano). int0/int1=1 (inactivos); puertos a 0xFF (el DS5002 no los usa) =====
    mc8051_core u_core (
        .clk(clk), .cen(cen_eff), .reset(rst),
        .rom_data_i(rom_data_q), .rom_adr_o(core_rom_adr),
        .ram_data_i(core_ram_q), .ram_data_o(core_ram_d), .ram_adr_o(core_ram_adr),
        .ram_wr_o(core_ram_wr), .ram_en_o(core_ram_en),
        .datax_i(xdata_din_q), .datax_o(core_datax_o), .adrx_o(core_adrx),
        .memx_o(core_memx), .wrx_o(core_wrx),
        .int0_i(1'b1), .int1_i(1'b1),
        .all_t0_i(1'b0), .all_t1_i(1'b0), .all_rxd_i(1'b0),
        .all_rxd_o(), .all_rxdwr_o(), .all_txd_o(),
        .p0_i(8'hFF), .p0_o(), .p1_i(8'hFF), .p1_o(),
        .p2_i(8'hFF), .p2_o(), .p3_i(8'hFF), .p3_o()
    );
endmodule

`default_nettype wire
