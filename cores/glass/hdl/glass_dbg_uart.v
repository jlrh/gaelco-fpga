// ============================================================================
//  glass_dbg_uart.v — transmisor UART de DEBUG (clon EXACTO de wrally2_dbg_uart.v).
//  Envia repetidamente un paquete de NB bytes (8N1, 9600 baud), @clk48 (DIV=5000).
//  MiSTer enruta el UART del core a /dev/ttyS1:  stty -F /dev/ttyS1 9600 raw; cat /dev/ttyS1 | xxd
//  Bytes 0,1 = sync (0x55 0xAA); ultimo = 0x0A. `pkt_start` pulsa al iniciar cada paquete.
//  Glass usa 1 sola pagina (16 bytes) -> no rota; pkt_start sólo marca inicio.
// ============================================================================
`default_nettype none

module glass_dbg_uart #(
    parameter integer NB  = 16,        // numero de bytes del paquete
    parameter integer DIV = 5000       // clk / 9600 baud (clk48 -> 5000)
) (
    input  wire              clk,
    input  wire              rst,
    input  wire [8*NB-1:0]   data,      // data[8*i +: 8] = byte i (i=0,1 = sync 0x55,0xAA)
    output reg               pkt_start, // pulso de 1 clk al ARRANCAR un paquete
    output reg               txd
);
    reg [13:0]      divcnt = 0;
    reg [3:0]       bitcnt = 0; // 0=start, 1..8=datos (LSB first), 9=stop
    reg [7:0]       shreg  = 8'hFF;
    reg [5:0]       bidx   = 0; // indice de byte 0..NB-1
    reg [15:0]      gap    = 0; // espera entre paquetes (~1.4 ms @clk48)
    reg             busy   = 0;
    reg [8*NB-1:0]  buf_q  = 0; // paquete LATCHEADO al arrancar

    always @(posedge clk) begin
        pkt_start <= 1'b0;
        if (rst) begin
            txd<=1'b1; bitcnt<=0; bidx<=0; gap<=0; busy<=0; divcnt<=0; shreg<=8'hFF;
        end else if (!busy) begin
            txd <= 1'b1;                       // idle alto
            gap <= gap + 1'b1;
            if (&gap) begin                    // arranca un paquete nuevo
                busy<=1'b1; bidx<=0; bitcnt<=0; divcnt<=0;
                buf_q <= data; shreg <= data[7:0];
                pkt_start <= 1'b1;
            end
        end else begin
            if (divcnt < DIV-1) divcnt <= divcnt + 1'b1;
            else begin
                divcnt <= 0;
                if      (bitcnt==4'd0) txd <= 1'b0;          // start
                else if (bitcnt==4'd9) txd <= 1'b1;          // stop
                else begin txd <= shreg[0]; shreg <= {1'b0, shreg[7:1]}; end  // dato LSB first
                if (bitcnt==4'd9) begin
                    if (bidx==NB-1) begin busy<=1'b0; gap<=0; end
                    else begin bidx<=bidx+1'b1; bitcnt<=4'd0; shreg<=buf_q[8*(bidx+1) +: 8]; end
                end else bitcnt <= bitcnt + 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
