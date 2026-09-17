`default_nettype none

module aligator_gae1_sound #(
    parameter integer CLKDIV = 6144
)(
    input  wire        clk,
    input  wire        rst,

    input  wire        cs_sound,
    input  wire [6:0]  cpu_aw,
    input  wire        cpu_we,
    input  wire        cpu_uds, cpu_lds,
    input  wire [15:0] cpu_wdata,
    output wire [15:0] cpu_rdata,

    output reg  [21:0] rom_addr,
    output reg         rom_cs,
    input  wire [31:0] rom_data,
    input  wire        rom_ok,

    output reg signed [15:0] snd_l, snd_r,
    output reg         sample
);

    reg [15:0] sndregs [0:55];
    reg        active [0:6];
    reg        loop   [0:6];
    reg        chunkNum [0:6];

    wire [6:0] cpu_reg = cpu_aw - 7'h48;
    wire       cpu_inrange = cs_sound & (cpu_reg < 7'd56);
    assign cpu_rdata = sndregs[cpu_reg[5:0]];

    reg [12:0] divcnt;
    reg        cen;
    always @(posedge clk) begin
        if (rst) begin divcnt <= 0; cen <= 0; end
        else if (divcnt == CLKDIV-1) begin divcnt <= 0; cen <= 1; end
        else begin divcnt <= divcnt + 1'b1; cen <= 0; end
    end

    reg signed [15:0] voltab [0:4095];
    initial $readmemh("volume_table.mem", voltab);
    reg [11:0] vol_a;
    reg signed [15:0] vol_q;
    always @(posedge clk) vol_q <= voltab[vol_a];

    localparam [3:0] IDLE=0, CHK=1, A1SET=2, A1WAIT=3, VL=4, VLW=5, RDEC=6,
                     A2WAIT=7, VR=8, VRW=9, ACC=10, NXT=11, OUTP=12, VLB=13;
    reg [3:0]  st;
    reg [2:0]  ch;
    reg [5:0]  base;
    reg [3:0]  vl, vr, typ;
    reg [1:0]  bank;
    reg [15:0] endp;
    reg [23:0] endpos;
    reg [15:0] rem;
    reg [7:0]  data1;
    reg signed [15:0] chl, chr;
    reg signed [31:0] accl, accr;

    function [7:0] selbyte(input [31:0] d, input [1:0] bk);
        case (bk)
            2'd0: selbyte = d[15:8];
            2'd1: selbyte = d[7:0];
            2'd2: selbyte = d[31:24];
            2'd3: selbyte = d[23:16];
        endcase
    endfunction

    wire [23:0] saddr = endpos + {8'b0, rem};

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            st <= IDLE; rom_cs <= 0; sample <= 0; ch <= 0;
            snd_l <= 0; snd_r <= 0;
            for (i=0;i<7;i=i+1) begin active[i]<=0; loop[i]<=0; chunkNum[i]<=0; end
        end else begin
            sample <= 0;

            if (cpu_inrange & cpu_we) begin
                if (cpu_uds) sndregs[cpu_reg[5:0]][15:8] <= cpu_wdata[15:8];
                if (cpu_lds) sndregs[cpu_reg[5:0]][7:0]  <= cpu_wdata[7:0];

                if (cpu_reg[2:0]==3'd3 || cpu_reg[2:0]==3'd7) begin

                    if (sndregs[cpu_reg[5:0] - 6'd1] != 16'd0 && cpu_wdata != 16'd0) begin
                        active[cpu_reg[5:3]] <= 1'b1;
                        loop[cpu_reg[5:3]]   <= 1'b1;
                        if (!active[cpu_reg[5:3]]) chunkNum[cpu_reg[5:3]] <= cpu_reg[2];
                    end else begin
                        if (cpu_reg[2:0]==3'd3) active[cpu_reg[5:3]] <= 1'b0;
                        else                    loop[cpu_reg[5:3]]   <= 1'b0;
                    end
                end
            end

            case (st)
                IDLE: if (cen) begin accl<=0; accr<=0; ch<=0; st<=CHK; end
                CHK: begin
                    if (active[ch]) begin
                        base   <= {ch, (loop[ch]?chunkNum[ch]:1'b0), 2'b00};
                        st <= A1SET;
                    end else st <= NXT;
                end
                A1SET: begin
                    vl  <= sndregs[base+6'd1][15:12];
                    vr  <= sndregs[base+6'd1][11:8];
                    typ <= sndregs[base+6'd1][7:4];
                    bank<= sndregs[base+6'd1][1:0];
                    endpos <= {sndregs[base+6'd2], 8'd0} - 24'd1;
                    rem <= sndregs[base+6'd3];
                    st <= A1WAIT;
                end
                A1WAIT: begin
                    rom_addr <= saddr[21:0]; rom_cs <= 1'b1;
                    if (rom_ok) begin
                        data1 <= selbyte(rom_data, bank);
                        rom_cs <= 1'b0;
                        st <= VL;
                    end
                end
                VL:  begin vol_a <= {vl, data1}; st <= VLB; end
                VLB: st <= VLW;
                VLW: begin
                    chl <= (typ==4'h8 || typ==4'hc) ? vol_q : 16'sd0;
                    rem <= rem - 16'd1;
                    st  <= RDEC;
                end
                RDEC: begin
                    if (typ==4'h8) begin
                        vol_a <= {vr, data1}; st <= VR;
                    end else if (typ==4'hc) begin
                        if (rem != 16'd0) begin st <= A2WAIT; end
                        else begin chr <= 16'sd0; st <= ACC; end
                    end else begin
                        chl <= 16'sd0; chr <= 16'sd0; st <= ACC;
                    end
                end
                A2WAIT: begin
                    rom_addr <= saddr[21:0]; rom_cs <= 1'b1;
                    if (rom_ok) begin
                        vol_a <= {vr, selbyte(rom_data, bank)};
                        rom_cs <= 1'b0;
                        rem <= rem - 16'd1;
                        st <= VR;
                    end
                end
                VR:  st <= VRW;
                VRW: begin chr <= vol_q; st <= ACC; end
                ACC: begin
                    accl <= accl + {{16{chl[15]}}, chl};
                    accr <= accr + {{16{chr[15]}}, chr};

                    sndregs[base+6'd3] <= rem;
                    if (rem == 16'd0) begin
                        if (loop[ch]==1'b0) active[ch] <= 1'b0;
                        else begin
                            chunkNum[ch] <= ~chunkNum[ch];

                            if (sndregs[{ch, ~chunkNum[ch], 2'b11}] == 16'd0) active[ch] <= 1'b0;
                        end
                    end
                    st <= NXT;
                end
                NXT: begin
                    if (ch == 3'd6) st <= OUTP;
                    else begin ch <= ch + 3'd1; st <= CHK; end
                end
                OUTP: begin

                    snd_l <= (accl > 32'sd32767) ? 16'sh7fff : (accl < -32'sd32768) ? 16'sh8000 : accl[15:0];
                    snd_r <= (accr > 32'sd32767) ? 16'sh7fff : (accr < -32'sd32768) ? 16'sh8000 : accr[15:0];
                    sample <= 1'b1;
                    st <= IDLE;
                end
                default: st <= IDLE;
            endcase
        end
    end

    // synthesis translate_off
    initial begin st=IDLE; rom_cs=0; sample=0; ch=0; snd_l=0; snd_r=0;
        for (i=0;i<7;i=i+1) begin active[i]=0; loop[i]=0; chunkNum[i]=0; end
        for (i=0;i<56;i=i+1) sndregs[i]=0; end
    // synthesis translate_on
endmodule

`default_nettype wire
