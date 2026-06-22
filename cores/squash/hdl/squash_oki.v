// ============================================================================
//  Squash (Gaelco) — glue del OKI MSM6295 (jt6295) al mapa de samples.
//
//  Instancia jt6295 (INTERPOL=0) y traduce su `rom_addr` de 256 KB al espacio
//  REAL de samples de 1 MB de Squash (`oki_map` de gaelco.cpp):
//    0x00000-0x2FFFF  -> FIJO  (primeros 192 KB de la ROM de 1 MB)
//    0x30000-0x3FFFF  -> BANCO (64 KB) seleccionado por `okibank` (de 0x70000D)
//
//  Bus del 68000: 0x70000F = registro del OKI (escritura = comando, lectura = estado).
//  `cen` debe ser un enable de 1 MHz (el reloj del OKI). `ss`=1 (PIN7_HIGH en wrally).
// ============================================================================
`default_nettype none

module squash_oki (
    input  wire        clk,
    input  wire        rst,
    input  wire        cen,          // enable de 1 MHz (reloj del OKI)

    // --- bus del 68000 (0x70000F) ---
    input  wire        cs_oki,       // chip-select del registro OKI (0x70000F)
    input  wire        rwn,          // 1=lectura, 0=escritura
    input  wire [7:0]  din,          // dato del 68000 (escritura)
    output wire [7:0]  dout,         // estado del OKI (lectura)

    // --- banco (de wrally_iolatch, 0x70000D) ---
    input  wire [3:0]  okibank,

    // --- ROM de samples de 1 MB (oki ROM) ---
    output wire [19:0] sample_addr,  // direccion fisica en la ROM de 1 MB
    input  wire [7:0]  sample_data,
    input  wire        sample_ok,

    // --- salida de audio ---
    output wire signed [13:0] sound,
    output wire        sample_tick   // pulso de sample rate
);
    // --- generar el strobe de escritura (wrn activo bajo) ---
    // El 68000 escribe 0x70000F en un ciclo de bus; generamos un pulso wrn bajo
    // de 1 ciclo de `clk` cuando cs_oki & ~rwn (flanco), como hace el OKI real.
    reg  cs_d;
    always @(posedge clk) cs_d <= cs_oki & ~rwn;
    wire wr_pulse = (cs_oki & ~rwn) & ~cs_d;   // flanco de subida del acceso de escritura
    wire wrn = ~wr_pulse;

    // --- direccion del core (256 KB) -> ROM fisica de 1 MB ---
    wire [17:0] core_addr;
    assign sample_addr = (core_addr < 18'h30000)
                         ? {2'b00, core_addr}                 // fijo: 0x00000-0x2FFFF
                         : {okibank, core_addr[15:0]};        // banco: 64 KB

`ifdef SIMULATION
    // OKIDBG: cuenta y registra los comandos que el 68000 escribe al OKI (0x70000F). Si n_oki=0
    // el juego no dispara sonido (auto-test silencioso?) o el path de cs_oki/wr_pulse falla.
    integer n_oki=0;
    always @(posedge clk) if (wr_pulse) begin
        if (n_oki<24) $display("OKIDBG #%0d din=%h (cmd OKI)", n_oki, din);
        n_oki <= n_oki+1;
    end
`endif

    jt6295 #(.INTERPOL(0), .SAMPLE(0)) u_oki (
        .rst      ( rst         ),
        .clk      ( clk         ),
        .cen      ( cen         ),
        .ss       ( 1'b1        ),          // PIN7_HIGH en Squash
        .wrn      ( wrn         ),
        .din      ( din         ),
        .dout     ( dout        ),
        .rom_addr ( core_addr   ),
        .rom_data ( sample_data ),
        .rom_ok   ( sample_ok   ),
        .sound    ( sound       ),
        .sample   ( sample_tick )
    );
endmodule

`default_nettype wire
