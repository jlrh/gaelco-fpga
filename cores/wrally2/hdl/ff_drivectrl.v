module ff_drivectrl #(
    parameter [7:0] CENTER      = 8'h80,
    parameter [7:0] LIM         = 8'h16,
    parameter [7:0] ANA_MUL     = 8'd24,
    parameter [7:0] ANA_DZ      = 8'd8,
    parameter [7:0] STEP_UNIT   = 8'd1,
    parameter [7:0] OPT_UNIT    = 8'd2,
    parameter [7:0] OPT_MUL     = 8'd40,
    parameter [7:0] GAS_REST    = 8'h00,
    parameter [7:0] GAS_FULL    = 8'h80,
    parameter [7:0] GAS_DZ      = 8'd8,
    parameter [7:0] BRK_TH      = 8'h40,
    parameter [9:0] BOOT_FRAMES = 10'd0
)(
    input             rst,
    input             clk,
    input             LVBL,
    input      [ 6:0] joystick1,
    input      [15:0] joyana_l1,
    input      [15:0] joyana_r1,
    input      [ 1:0] ctrl_type,
    input      [ 1:0] steer_mode,
    input      [ 1:0] ramp_spd,
    output reg [ 7:0] steer,
    output reg [ 7:0] accel,
    output reg        brake,
    output     [ 7:0] brk_mag,
    output reg        shift,
    output            optical,
    output     [ 6:0] opt_cnt
);

wire       right = ~joystick1[0], left = ~joystick1[1], down = ~joystick1[2], up = ~joystick1[3];
wire       btn1  = ~joystick1[4], btn2 = ~joystick1[5];
wire [7:0] ana_x = joyana_l1[7:0];

function [7:0] mag( input [7:0] v, input neg );
    mag = neg ? ( v[7] ? 8'd0 - v : 8'd0 ) : ( v[7] ? 8'd0 : v );
endfunction

reg  [7:0] gas_an, brk_an;
always @* begin
    case( ctrl_type )
        2'd0: begin gas_an = mag(joyana_l1[15:8],1); brk_an = mag(joyana_l1[15:8],0); end
        2'd1: begin gas_an = mag(joyana_r1[15:8],1); brk_an = mag(joyana_r1[15:8],0); end
        2'd2: begin gas_an = mag(joyana_r1[ 7:0],0); brk_an = mag(joyana_l1[15:8],0); end
        2'd3: begin gas_an = mag(joyana_l1[15:8],1); brk_an = mag(joyana_r1[15:8],1); end
    endcase
end
assign brk_mag = brk_an;

reg        LVBLl, btn3l, dirl, ana_l;
reg  [2:0] spd;
reg  [6:0] base;
reg  [9:0] boot;
wire       booting = boot != 10'd0;

wire        wheel  = ctrl_type == 2'd3;
wire        ana_on = wheel || ( $signed(ana_x) < -$signed({1'b0,ANA_DZ}) || $signed(ana_x) > $signed({1'b0,ANA_DZ}) - 9'sd1 );

wire signed [16:0] px_st  = $signed(ana_x) * $signed({1'b0, ANA_MUL});
wire signed [16:0] px_oc  = $signed(ana_x) * $signed({1'b0, OPT_MUL});
wire [7:0]  ana_st = CENTER + px_st[14:7];
wire [6:0]  ana_oc = ana_on ? 7'd0 - px_oc[13:7] : 7'd0;
wire [15:0] gas_sc = ( gas_an > 8'd128 ? 8'd128 : gas_an ) * ( GAS_FULL - GAS_REST );
wire [7:0]  gas_v  = GAS_REST + gas_sc[14:7];

assign      optical = steer_mode == 2'd3;
assign      opt_cnt = base + ana_oc;

wire [2:0]  rstep  = ramp_spd==2'd0 ? 3'd2 : ramp_spd==2'd1 ? 3'd1 : ramp_spd==2'd2 ? 3'd3 : 3'd4;
wire [2:0]  spd_nx = steer_mode==2'd0 ? rstep : ( dirl!=left || spd==0 ) ? 3'd1 : spd==3'd4 ? 3'd4 : spd+3'd1;
wire [7:0]  step   = spd_nx * STEP_UNIT;
wire [6:0]  ostep  = spd_nx * OPT_UNIT;
wire [7:0]  ret    = ( steer_mode==2'd0 ? {5'd0, rstep} : 8'd4 ) * STEP_UNIT;

always @(posedge clk) begin
    LVBLl <= LVBL;
    btn3l <= joystick1[6];
    accel <= booting ? GAS_REST : ( btn1 || up ) ? GAS_FULL : gas_an > GAS_DZ ? gas_v : GAS_REST;
    brake <= btn2 || down || brk_an > BRK_TH;
    if( rst ) begin
        steer <= CENTER; shift <= 0; spd <= 0; dirl <= 0; ana_l <= 0; base <= 0; boot <= BOOT_FRAMES;
    end else begin
        if( btn3l && !joystick1[6] ) shift <= ~shift;
        if( LVBLl && !LVBL ) begin
            ana_l <= 0;
            if( booting ) begin
                boot <= boot - 10'd1;
                steer <= CENTER;
            end else if( left || right ) begin
                spd  <= spd_nx; dirl <= left;
                if( optical ) base <= left ? base + ostep : base - ostep;
                else if( left ) steer <= steer < CENTER-LIM+step ? CENTER-LIM : steer - step;
                else            steer <= steer > CENTER+LIM-step ? CENTER+LIM : steer + step;
            end else begin
                spd <= 0;
                if( ana_on ) begin
                    steer <= ana_st; ana_l <= 1;
                end else if( ana_l && steer_mode==2'd2 ) begin
                    steer <= CENTER;
                end else if( steer_mode==2'd0 || steer_mode==2'd1 ) begin
                    if( steer > CENTER )      steer <= steer - CENTER < ret ? CENTER : steer - ret;
                    else if( steer < CENTER ) steer <= CENTER - steer < ret ? CENTER : steer + ret;
                end
            end
        end
    end
end

endmodule
