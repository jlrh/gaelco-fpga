`default_nettype none

module bigkarnk_sound(
    input              clk,
    input              rst,

    input              cen_cpu,
    input              cen_fm,
    input              cen_oki,

    input              snd_irq,
    input      [ 7:0]  snd_latch,

    output     [15:0]  rom_addr,
    output reg         rom_cs,
    input      [ 7:0]  rom_data,
    input              rom_ok,

    output     [17:0]  pcm_addr,
    output             pcm_cs,
    input      [ 7:0]  pcm_data,
    input              pcm_ok,

    output signed [13:0] pcm,
    output signed [15:0] fm,
    output             sample
);
`ifndef NOSOUND
    wire [15:0] A;
    wire        cpu_rnw;
    wire [ 7:0] cpu_dout, ram_dout, fm_dout, oki_dout;
    reg  [ 7:0] cpu_din;
    wire        firq_n;

    reg         ram_cs, oki_cs, fm_cs, latch_cs;

    always @(*) begin
        ram_cs   = 0;
        oki_cs   = 0;
        fm_cs    = 0;
        latch_cs = 0;
        rom_cs   = 0;
        if      ( A < 16'h0800 )            ram_cs   = 1;
        else if ( A[15:8] == 8'h08 )        oki_cs   = 1;
        else if ( A[15:8] == 8'h0a )        fm_cs    = 1;
        else if ( A[15:8] == 8'h0b )        latch_cs = 1;
        else if ( A >= 16'h0c00 )           rom_cs   = 1;
    end

    assign rom_addr = A;

    always @(*) begin
        cpu_din = rom_cs   ? rom_data  :
                  ram_cs   ? ram_dout  :
                  fm_cs    ? fm_dout   :
                  oki_cs   ? oki_dout  :
                  latch_cs ? snd_latch :
                  8'hff;
    end

    jtframe_ff u_firq(
        .clk     ( clk      ),
        .rst     ( rst      ),
        .cen     ( 1'b1     ),
        .din     ( 1'b1     ),
        .q       (          ),
        .qn      ( firq_n   ),
        .set     ( 1'b0     ),
        .clr     ( latch_cs ),
        .sigedge ( snd_irq  )
    );

    jtframe_sys6809 #(.RAM_AW(11),.CENDIV(0)) u_cpu(
        .rstn       ( ~rst     ),
        .clk        ( clk      ),
        .cen        ( cen_cpu  ),
        .cpu_cen    (          ),
        .VMA        (          ),

        .nIRQ       ( 1'b1     ),
        .nFIRQ      ( firq_n   ),
        .nNMI       ( 1'b1     ),
        .irq_ack    (          ),

        .bus_busy   ( 1'b0     ),

        .A          ( A        ),
        .RnW        ( cpu_rnw  ),
        .ram_cs     ( ram_cs   ),
        .rom_cs     ( rom_cs   ),
        .rom_ok     ( rom_ok   ),
        .ram_dout   ( ram_dout ),
        .cpu_dout   ( cpu_dout ),
        .cpu_din    ( cpu_din  )
    );

    jtopl2 u_opl(
        .rst    ( rst      ),
        .clk    ( clk      ),
        .cen    ( cen_fm   ),
        .din    ( cpu_dout ),
        .addr   ( A[0]     ),
        .cs_n   ( ~fm_cs   ),
        .wr_n   ( cpu_rnw  ),
        .dout   ( fm_dout  ),
        .irq_n  (          ),
        .snd    ( fm       ),
        .sample (          )
    );

    reg oki_wr_d;
    always @(posedge clk) oki_wr_d <= oki_cs & ~cpu_rnw;
    wire oki_wr_pulse = (oki_cs & ~cpu_rnw) & ~oki_wr_d;
    wire oki_wrn = ~oki_wr_pulse;

    assign pcm_cs = 1'b1;

    jt6295 #(.INTERPOL(0), .SAMPLE(0)) u_oki(
        .rst      ( rst      ),
        .clk      ( clk      ),
        .cen      ( cen_oki  ),
        .ss       ( 1'b1     ),
        .wrn      ( oki_wrn  ),
        .din      ( cpu_dout ),
        .dout     ( oki_dout ),
        .rom_addr ( pcm_addr ),
        .rom_data ( pcm_data ),
        .rom_ok   ( pcm_ok   ),
        .sound    ( pcm      ),
        .sample   ( sample   )
    );
`else
    assign rom_addr = 0;  initial rom_cs = 0;
    assign pcm_addr = 0;  assign pcm_cs = 0;
    assign pcm = 0;       assign fm = 0;  assign sample = 0;
`endif
endmodule

`default_nettype wire
