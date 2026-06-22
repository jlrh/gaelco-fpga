// ============================================================================
//  biomtoy_68kdtack.v — copia local de jtframe_68kdtack_cen (jotego, GPLv3) SIN el
//  jtframe_freqinfo (solo reporte de frecuencia, arrastra deps) y con MFREQ literal.
//
//  Genera /DTACK del 68000 Y los clock-enables (cpu_cen/cpu_cenb) CO-GENERADOS y
//  sincronizados con el DTACK. Esta co-generacion es CLAVE: el slot SDRAM de jtframe
//  tiene latencia + ventana de `ok` rancio al cambiar de direccion; el `wait1` interno
//  da 1 ciclo a bus_busy para conmutar (mata la carrera), y como el muestreo del 68000
//  (en los cens generados aqui) esta alineado con el DTACK, la CPU latchea el dato
//  FRESCO. (Con cens externos NO sincronizados, el 68000 muestreaba el dato rancio
//  -> desfase de 1 word -> reset vector roto. Ver memoria wrally-migracion-jtframe.)
//
//  cpu_cen/cpu_cenb -> fx68k enPhi1/enPhi2. Para 12 MHz desde clk=48 MHz: num=1, den=4.
// ============================================================================
module biomtoy_68kdtack
#(parameter W=8,
            RECOVERY=1,
            WD=6,
            WAIT1=0,
            MFREQ=48000  // kHz (clk=48MHz); solo para el (eliminado) reporte de frecuencia
)(
    input         rst,
    input         clk,
    output   reg  cpu_cen,
    output   reg  cpu_cenb,
    input         bus_cs,
    input         bus_busy,
    input         bus_legit,
    input         bus_ack,
    input         ASn,
    input [1:0]   DSn,
    input [W-2:0] num,
    input [W-1:0] den,
    input         wait2,
    input         wait3,
    output reg    DTACKn
);
/* verilator lint_off WIDTH */

localparam CW=W+WD;

reg [CW-1:0] cencnt=0;
reg  [1:0]   waitsh;
wire [W-1:0] num2 = { num, 1'b0 };
wire         recover, delayed;
wire         over = cencnt>den-num2;
reg  [CW:0] cencnt_nx=0;
reg         risefall=0, wait1;

`ifdef SIMULATION
    reg  rstl=0;
    always @(posedge clk) rstl <= rst;
`else
    wire rstl=0;
`endif

always @(posedge clk) begin : dtack_gen
    if( rst ) begin
        DTACKn <= 1;
        waitsh <= 0;
        wait1  <= 0;
    end else begin
        if( ASn | &DSn ) begin
            DTACKn <= 1;
            wait1  <= 1; // gives a clock cycle to bus_busy to toggle
            waitsh <= {wait3,wait2};
        end else if( !ASn && (cpu_cen || WAIT1==0) ) begin
            wait1 <= 0;
            if( cpu_cen ) waitsh <= waitsh>>1;
            if( waitsh==0 && !wait1 ) begin
                DTACKn <= DTACKn && bus_cs && bus_busy;
            end
        end
    end
end

always @* begin
    cencnt_nx = over ? {1'b0,cencnt}+num2-den : { 1'b0, cencnt}+num2;
end

generate if (RECOVERY==1) begin
    reg [CW-1:0] missing;
    assign recover =  ASn && missing>0 && !over && !bus_ack;
    assign delayed = !ASn && !rstl && {waitsh,wait1}==0 && (bus_cs && bus_busy && !bus_legit);

    always @(posedge clk) begin
        if( rst ) begin
            missing <= 0;
        end else begin
            if( delayed && (cpu_cen|cpu_cenb) ) begin
                missing <= missing + 1'b1;
            end
            if( recover ) begin
                missing <= missing - 1'b1;
            end
        end
    end
end else begin
    assign recover=0;
    assign delayed=0;
end endgenerate

always @(posedge clk) begin
    cencnt  <= cencnt_nx[CW] ? {CW{1'b1}} : cencnt_nx[CW-1:0];
    if( rst ) cencnt <= 0;
    if( over || rst || recover) begin
        cpu_cen  <=  risefall;
        cpu_cenb <= ~risefall;
        risefall <= ~risefall;
    end else begin
        cpu_cen  <= 0;
        cpu_cenb <= 0;
    end
end
/* verilator lint_on WIDTH */

endmodule
