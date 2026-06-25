// ============================================================================
//  TH Strikes Back (thoop2) — ensamblado de puertos de entrada del 68000.
//
//  Mapa MAME (thoop2.cpp INPUT_PORTS thoop2):
//    0x700000 DSW2  0x700002 DSW1  0x700004 P1  0x700006 P2  0x700008 SYSTEM  (todos ACTIVO-BAJO)
//
//  P1: b0=up b1=down b2=right b3=left b4=BTN2 b5=BTN1 b6=COIN1  b7=COIN2
//  P2: b0=up b1=down b2=right b3=left b4=BTN2 b5=BTN1 b6=START1 b7=START2
//  SYSTEM: b0=SERVICE1(boton servicio) b1=SERVICE2(test) b2=BTN3 P1 b3=BTN3 P2  b4-7=unused
//  DSW1: b0-2 Coin B, b3-5 Coin A, b6 credit cfg, b7 Free Play.
//  DSW2: b0-1 Difficulty, b2 Unknown, b3-4 Lives, b5 Demo Sounds, b6 Unknown, b7 SERVICE MODE (dip).
//
//  Entradas en formato jtframe ACTIVO-BAJO (0=pulsado), igual que los puertos del 68k.
//  joystick jtframe (BUTTONS=3): b0=right b1=left b2=down b3=up b4=BTN1 b5=BTN2 b6=BTN3.
//
//  OJO (vs el clon de thoop): el BOTON de servicio va en SYSTEM b0; DSW2 b7 es el DIP de modo
//  servicio (de la .mra) -> NO mezclar (antes se metia el boton en DSW2 b7 = modo servicio permanente).
// ============================================================================
`default_nettype none

module thoop2_inputs (
    // DIP (de la .mra; DSW1 = byte bajo, DSW2 = byte alto)
    input  wire [15:0] dipsw,
    // jtframe activo-bajo (0 = pulsado). 7 bits: 3 botones (b4..b6) + 4 direcciones (b0..b3).
    input  wire [6:0]  joystick1,   // b0=right b1=left b2=down b3=up b4=BTN1 b5=BTN2 b6=BTN3
    input  wire [6:0]  joystick2,
    input  wire [1:0]  coin,        // coin[0]=coin1 coin[1]=coin2
    input  wire [1:0]  start,       // start[0]=start1 start[1]=start2
    input  wire        service,     // boton de servicio (activo-bajo)

    output wire [15:0] port_dsw2,
    output wire [15:0] port_dsw1,
    output wire [15:0] port_p1,
    output wire [15:0] port_p2,
    output wire [15:0] port_system
);
    wire [7:0] dsw1 = dipsw[7:0];
    wire [7:0] dsw2 = dipsw[15:8];

    // DSW: byte alto = 0xFF (bits sin mapear, activo-bajo). DSW2 b7 = dip de modo servicio (de la .mra) TAL CUAL.
    assign port_dsw1 = {8'hFF, dsw1};
    assign port_dsw2 = {8'hFF, dsw2};

    // P1: {coin2,coin1,btn2,btn1,left,right,down,up} (todos activo-bajo)
    assign port_p1 = {8'hFF, coin[1], coin[0],
                      joystick1[5], joystick1[4], joystick1[1], joystick1[0], joystick1[2], joystick1[3]};
    // P2: {start2,start1,btn2,btn1,left,right,down,up}
    assign port_p2 = {8'hFF, start[1], start[0],
                      joystick2[5], joystick2[4], joystick2[1], joystick2[0], joystick2[2], joystick2[3]};
    // SYSTEM: {unused(4)=1, btn3_p2, btn3_p1, test=1, service} (activo-bajo; unpressed = 1)
    assign port_system = {8'hFF, 4'hF, joystick2[6], joystick1[6], 1'b1, service};
endmodule

`default_nettype wire
