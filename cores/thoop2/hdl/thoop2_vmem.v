// ============================================================================
//  Thunder Hoop (Gaelco) — thoop2_vmem.v: memorias de la "placa" en BRAM.
//
//  Cuatro regiones del bus del 68000 (almacenamiento + arbitraje con el vídeo):
//    videoram  (8KB, 0x1000 words)  — tile RAM de los 2 tilemaps. CPU R/W + lectura de
//                                     vídeo por PARES de word (w0=code/flip, w1=color/prio).
//                                     L0 = words 0x000-0x7FF, L1 = 0x800-0xFFF.
//    screenram (8KB, 0x1000 words)  — RAM descifrada; NO la lee el render (CPU R/W).
//    paleta    (1024 words)         — xBGR-555. CPU R/W + lectura de vídeo.
//    spriteRAM (0x800 words, 4KB)   — CPU R/W + lectura de vídeo.
//
//  Inferencia de BRAM: byte-lanes (hi/lo), escritura de byte completo, lectura REGISTRADA.
//  Cada memoria con puerto de vídeo se replica (copia CPU + copia vídeo) -> 1W/1R por copia.
//  videoram se guarda por PARIDAD de word (ve=words pares w0, vo=impares w1) para servir el
//  par {w0,w1} de un tile en una sola lectura de 32 bits: tile k -> {ve[k], vo[k]}.
// ============================================================================
`default_nettype none

module thoop2_vmem (
    input  wire        clk,
    input  wire        ce_pix,

    // -------- puerto CPU (de thoop2_main) --------
    input  wire [13:0] cpu_addr,        // direccion de BYTE
    input  wire        cpu_uds, cpu_lds,
    input  wire        cpu_we,
    input  wire        cs_vram, cs_pal, cs_spr,
    input  wire [15:0] io_wdata,        // dato crudo del bus (VRAM/paleta/sprite; thoop2 NO cifra)
    output reg  [15:0] cpu_vram_rdata,
    output reg  [15:0] cpu_pal_rdata,
    output reg  [15:0] cpu_spr_rdata,

    // -------- puertos de VÍDEO --------
    input  wire [10:0] tile_a0,         // tile L0 = (0<<10)|tile  (k = word_offset>>1)
    output reg  [31:0] tile_q0,         // {w0 (par/code), w1 (impar/color)}
    input  wire [10:0] tile_a1,         // tile L1 = (1<<10)|tile
    output reg  [31:0] tile_q1,
    input  wire [9:0]  pal_a,           // entrada de paleta tilemap (0..1023)
    output reg  [15:0] pal_q,
    input  wire [9:0]  palb_a,          // entrada de paleta SPRITE (puerto B)
    output reg  [15:0] palb_q,
    input  wire [10:0] spr_a,           // word de spriteRAM (0..0x7FF)
    output reg  [15:0] spr_q,
    input  wire        scene_dump       // SIM: pulso -> vuelca VRAM/paleta/spriteRAM a scene_*.hex
);
    // ===================== videoram (8KB) — por paridad de word =====================
    // ve = words pares (w0), vo = words impares (w1). k = word_offset>>1 (0..0x7FF).
    // 3 copias: vídeo L0 (lee tile_a0), vídeo L1 (lee tile_a1) y CPU. byte-lanes hi/lo.
    reg [7:0] e0_hi[0:2047], e0_lo[0:2047], o0_hi[0:2047], o0_lo[0:2047];  // copia vídeo L0
    reg [7:0] e1_hi[0:2047], e1_lo[0:2047], o1_hi[0:2047], o1_lo[0:2047];  // copia vídeo L1
    reg [7:0] ec_hi[0:2047], ec_lo[0:2047], oc_hi[0:2047], oc_lo[0:2047];  // copia CPU
    wire [11:0] vwo = cpu_addr[12:1];        // word offset en videoram (0..0xFFF)
    wire [10:0] vk  = vwo[11:1];             // k = offset>>1
    wire        vpar= vwo[0];                // 0=word par (ve/w0), 1=impar (vo/w1)
    wire vw_hi = cpu_we & cs_vram & cpu_uds;
    wire vw_lo = cpu_we & cs_vram & cpu_lds;
    always @(posedge clk) begin
        if (vw_hi & ~vpar) begin e0_hi[vk]<=io_wdata[15:8]; e1_hi[vk]<=io_wdata[15:8]; ec_hi[vk]<=io_wdata[15:8]; end
        if (vw_lo & ~vpar) begin e0_lo[vk]<=io_wdata[7:0];  e1_lo[vk]<=io_wdata[7:0];  ec_lo[vk]<=io_wdata[7:0];  end
        if (vw_hi &  vpar) begin o0_hi[vk]<=io_wdata[15:8]; o1_hi[vk]<=io_wdata[15:8]; oc_hi[vk]<=io_wdata[15:8]; end
        if (vw_lo &  vpar) begin o0_lo[vk]<=io_wdata[7:0];  o1_lo[vk]<=io_wdata[7:0];  oc_lo[vk]<=io_wdata[7:0];  end
    end
    // lectura de vídeo: par {w0,w1} del tile, una por capa (registrada en ce_pix)
    always @(posedge clk) if (ce_pix) begin
        tile_q0 <= {e0_hi[tile_a0], e0_lo[tile_a0], o0_hi[tile_a0], o0_lo[tile_a0]};
        tile_q1 <= {e1_hi[tile_a1], e1_lo[tile_a1], o1_hi[tile_a1], o1_lo[tile_a1]};
    end
    // lectura de CPU (16b: word par o impar segun paridad)
    always @(posedge clk)
        cpu_vram_rdata <= vpar ? {oc_hi[vk], oc_lo[vk]} : {ec_hi[vk], ec_lo[vk]};

    // ===================== paleta (1024 words) — CPU R/W + vídeo =====================
    reg [7:0] pv_hi[0:1023], pv_lo[0:1023];   // copia vídeo (tilemap, puerto A)
    reg [7:0] pb_hi[0:1023], pb_lo[0:1023];   // copia vídeo (sprite, puerto B)
    reg [7:0] pc_hi[0:1023], pc_lo[0:1023];   // copia CPU
    wire [9:0] pwo = cpu_addr[10:1];
    wire pw_hi = cpu_we & cs_pal & cpu_uds;
    wire pw_lo = cpu_we & cs_pal & cpu_lds;
    always @(posedge clk) begin
        if (pw_hi) begin pv_hi[pwo]<=io_wdata[15:8]; pb_hi[pwo]<=io_wdata[15:8]; pc_hi[pwo]<=io_wdata[15:8]; end
        if (pw_lo) begin pv_lo[pwo]<=io_wdata[7:0];  pb_lo[pwo]<=io_wdata[7:0];  pc_lo[pwo]<=io_wdata[7:0];  end
    end
    always @(posedge clk) if (ce_pix) pal_q  <= {pv_hi[pal_a],  pv_lo[pal_a]};
    always @(posedge clk) if (ce_pix) palb_q <= {pb_hi[palb_a], pb_lo[palb_a]};
    always @(posedge clk) cpu_pal_rdata <= {pc_hi[pwo], pc_lo[pwo]};

    // ===================== spriteRAM (0x800 words, 4KB) — CPU R/W + vídeo =====================
    reg [7:0] qv_hi[0:2047], qv_lo[0:2047];   // copia vídeo
    reg [7:0] qc_hi[0:2047], qc_lo[0:2047];   // copia CPU
    wire [10:0] qwo = cpu_addr[11:1];
    wire qw_hi = cpu_we & cs_spr & cpu_uds;
    wire qw_lo = cpu_we & cs_spr & cpu_lds;
    always @(posedge clk) begin
        if (qw_hi) begin qv_hi[qwo]<=io_wdata[15:8]; qc_hi[qwo]<=io_wdata[15:8]; end
        if (qw_lo) begin qv_lo[qwo]<=io_wdata[7:0];  qc_lo[qwo]<=io_wdata[7:0];  end
    end
    // FIX (2026-06-22, = squash): sprite-RAM NO gateada por ce_pix (el motor de sprites corre a ce=1 y lee
    // w0/w2/w3 en ciclos consecutivos; con ce_pix leia dato rancio -> X=Y, color/code basura).
    always @(posedge clk) spr_q <= {qv_hi[spr_a], qv_lo[spr_a]};
    always @(posedge clk) cpu_spr_rdata <= {qc_hi[qwo], qc_lo[qwo]};

`ifdef THOOP_SCENE
    // REPLAY: precarga la escena volcada (render sin bootear). En TODAS las copias (los 3 puertos leen).
    initial begin
        $readmemh("scene_ve_hi.hex", e0_hi); $readmemh("scene_ve_lo.hex", e0_lo);
        $readmemh("scene_vo_hi.hex", o0_hi); $readmemh("scene_vo_lo.hex", o0_lo);
        $readmemh("scene_ve_hi.hex", e1_hi); $readmemh("scene_ve_lo.hex", e1_lo);
        $readmemh("scene_vo_hi.hex", o1_hi); $readmemh("scene_vo_lo.hex", o1_lo);
        $readmemh("scene_ve_hi.hex", ec_hi); $readmemh("scene_ve_lo.hex", ec_lo);
        $readmemh("scene_vo_hi.hex", oc_hi); $readmemh("scene_vo_lo.hex", oc_lo);
        $readmemh("scene_pal_hi.hex", pv_hi); $readmemh("scene_pal_lo.hex", pv_lo);
        $readmemh("scene_pal_hi.hex", pb_hi); $readmemh("scene_pal_lo.hex", pb_lo);
        $readmemh("scene_pal_hi.hex", pc_hi); $readmemh("scene_pal_lo.hex", pc_lo);
        $readmemh("scene_spr_hi.hex", qv_hi); $readmemh("scene_spr_lo.hex", qv_lo);
        $readmemh("scene_spr_hi.hex", qc_hi); $readmemh("scene_spr_lo.hex", qc_lo);
        $display("THOOP_SCENE: VRAM/paleta/spriteRAM precargadas (replay)");
    end
`endif
`ifdef SIMULATION
    // DUMP de escena: al pulso scene_dump, vuelca la copia de vídeo a scene_*.hex (formato $readmemh).
    always @(posedge clk) if (scene_dump) begin
        $writememh("scene_ve_hi.hex", e0_hi); $writememh("scene_ve_lo.hex", e0_lo);
        $writememh("scene_vo_hi.hex", o0_hi); $writememh("scene_vo_lo.hex", o0_lo);
        $writememh("scene_pal_hi.hex", pv_hi); $writememh("scene_pal_lo.hex", pv_lo);
        $writememh("scene_spr_hi.hex", qv_hi); $writememh("scene_spr_lo.hex", qv_lo);
        $display("THOOP_SCENE DUMP: escena volcada a scene_*.hex");
    end
`endif
endmodule

`default_nettype wire
