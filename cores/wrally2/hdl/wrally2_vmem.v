`default_nettype none

module wrally2_vmem (
    input  wire        clk,
    input  wire        clk96,

    input  wire [15:0] cpu_addr,
    input  wire        cpu_uds, cpu_lds,
    input  wire        cpu_we,
    input  wire        cs_vram,
    input  wire        cs_pal,
    input  wire [15:0] cpu_wdata,
    output reg  [15:0] cpu_vram_rdata,
    output reg  [15:0] cpu_pal_rdata,

    input  wire [13:0] tp0_idx,
    output reg  [31:0] tp0_q,
    input  wire [13:0] tp1_idx,
    output reg  [31:0] tp1_q,
    input  wire [14:0] wrd_a,
    output wire [15:0] wrd_q,
    input  wire [14:0] spr_a,
    output wire [15:0] spr_q,
    input  wire [14:0] spr2_a,
    output wire [15:0] spr2_q,
    input  wire [11:0] pal_a,
    output reg  [15:0] pal_q
);

    (* ramstyle = "no_rw_check" *) reg [7:0] ce_hi[0:16383], ce_lo[0:16383], co_hi[0:16383], co_lo[0:16383];

    (* ramstyle = "no_rw_check" *) reg [7:0] t0e_hi[0:16383], t0e_lo[0:16383], t0o_hi[0:16383], t0o_lo[0:16383];

    (* ramstyle = "no_rw_check" *) reg [7:0] t1e_hi[0:16383], t1e_lo[0:16383], t1o_hi[0:16383], t1o_lo[0:16383];

    (* ramstyle = "no_rw_check" *) reg [7:0] we_hi[0:16383], we_lo[0:16383], wo_hi[0:16383], wo_lo[0:16383];

    (* ramstyle = "no_rw_check" *) reg [7:0] se_hi[0:16383], se_lo[0:16383], so_hi[0:16383], so_lo[0:16383];

    (* ramstyle = "no_rw_check" *) reg [7:0] s2e_hi[0:16383], s2e_lo[0:16383], s2o_hi[0:16383], s2o_lo[0:16383];

    wire        par   = cpu_addr[1];
    wire [13:0] hidx  = cpu_addr[15:2];
    wire vw_e_hi = cpu_we & cs_vram & ~par & cpu_uds;
    wire vw_e_lo = cpu_we & cs_vram & ~par & cpu_lds;
    wire vw_o_hi = cpu_we & cs_vram &  par & cpu_uds;
    wire vw_o_lo = cpu_we & cs_vram &  par & cpu_lds;
    wire        w_par  = wrd_a[0];
    wire [13:0] w_hidx = wrd_a[14:1];
    wire        s_par  = spr_a[0];
    wire [13:0] s_hidx = spr_a[14:1];
    wire        s2_par  = spr2_a[0];
    wire [13:0] s2_hidx = spr2_a[14:1];

    always @(posedge clk) begin
        if (vw_e_hi) ce_hi[hidx]<=cpu_wdata[15:8];
        if (vw_e_lo) ce_lo[hidx]<=cpu_wdata[7:0];
        if (vw_o_hi) co_hi[hidx]<=cpu_wdata[15:8];
        if (vw_o_lo) co_lo[hidx]<=cpu_wdata[7:0];
        cpu_vram_rdata <= par ? {co_hi[hidx], co_lo[hidx]} : {ce_hi[hidx], ce_lo[hidx]};
    end
    always @(posedge clk) begin
        if (vw_e_hi) t0e_hi[hidx]<=cpu_wdata[15:8];
        if (vw_e_lo) t0e_lo[hidx]<=cpu_wdata[7:0];
        if (vw_o_hi) t0o_hi[hidx]<=cpu_wdata[15:8];
        if (vw_o_lo) t0o_lo[hidx]<=cpu_wdata[7:0];
        tp0_q <= {t0e_hi[tp0_idx], t0e_lo[tp0_idx], t0o_hi[tp0_idx], t0o_lo[tp0_idx]};
    end
    always @(posedge clk) begin
        if (vw_e_hi) t1e_hi[hidx]<=cpu_wdata[15:8];
        if (vw_e_lo) t1e_lo[hidx]<=cpu_wdata[7:0];
        if (vw_o_hi) t1o_hi[hidx]<=cpu_wdata[15:8];
        if (vw_o_lo) t1o_lo[hidx]<=cpu_wdata[7:0];
        tp1_q <= {t1e_hi[tp1_idx], t1e_lo[tp1_idx], t1o_hi[tp1_idx], t1o_lo[tp1_idx]};
    end

    reg [7:0] we_hi_q, we_lo_q, wo_hi_q, wo_lo_q; reg w_par_q;
    always @(posedge clk) begin
        if (vw_e_hi) we_hi[hidx]<=cpu_wdata[15:8];
        if (vw_e_lo) we_lo[hidx]<=cpu_wdata[7:0];
        if (vw_o_hi) wo_hi[hidx]<=cpu_wdata[15:8];
        if (vw_o_lo) wo_lo[hidx]<=cpu_wdata[7:0];
        we_hi_q <= we_hi[w_hidx]; we_lo_q <= we_lo[w_hidx];
        wo_hi_q <= wo_hi[w_hidx]; wo_lo_q <= wo_lo[w_hidx];
        w_par_q <= w_par;
    end
    assign wrd_q = w_par_q ? {wo_hi_q, wo_lo_q} : {we_hi_q, we_lo_q};

    reg [7:0] se_hi_q, se_lo_q, so_hi_q, so_lo_q; reg s_par_q;
    always @(posedge clk) begin
        if (vw_e_hi) se_hi[hidx]<=cpu_wdata[15:8];
        if (vw_e_lo) se_lo[hidx]<=cpu_wdata[7:0];
        if (vw_o_hi) so_hi[hidx]<=cpu_wdata[15:8];
        if (vw_o_lo) so_lo[hidx]<=cpu_wdata[7:0];
    end
    always @(posedge clk96) begin
        se_hi_q <= se_hi[s_hidx]; se_lo_q <= se_lo[s_hidx];
        so_hi_q <= so_hi[s_hidx]; so_lo_q <= so_lo[s_hidx];
        s_par_q <= s_par;
    end
    assign spr_q = s_par_q ? {so_hi_q, so_lo_q} : {se_hi_q, se_lo_q};

    reg [7:0] s2e_hi_q, s2e_lo_q, s2o_hi_q, s2o_lo_q; reg s2_par_q;
    always @(posedge clk) begin
        if (vw_e_hi) s2e_hi[hidx]<=cpu_wdata[15:8];
        if (vw_e_lo) s2e_lo[hidx]<=cpu_wdata[7:0];
        if (vw_o_hi) s2o_hi[hidx]<=cpu_wdata[15:8];
        if (vw_o_lo) s2o_lo[hidx]<=cpu_wdata[7:0];
    end
    always @(posedge clk96) begin
        s2e_hi_q <= s2e_hi[s2_hidx]; s2e_lo_q <= s2e_lo[s2_hidx];
        s2o_hi_q <= s2o_hi[s2_hidx]; s2o_lo_q <= s2o_lo[s2_hidx];
        s2_par_q <= s2_par;
    end
    assign spr2_q = s2_par_q ? {s2o_hi_q, s2o_lo_q} : {s2e_hi_q, s2e_lo_q};

    reg [7:0] pc_hi[0:4095], pc_lo[0:4095];
    reg [7:0] pv_hi[0:4095], pv_lo[0:4095];
    wire [11:0] pwo = cpu_addr[12:1];
    wire pw_hi = cpu_we & cs_pal & cpu_uds;
    wire pw_lo = cpu_we & cs_pal & cpu_lds;
    always @(posedge clk) begin
        if (pw_hi) begin pc_hi[pwo]<=cpu_wdata[15:8]; pv_hi[pwo]<=cpu_wdata[15:8]; end
        if (pw_lo) begin pc_lo[pwo]<=cpu_wdata[7:0];  pv_lo[pwo]<=cpu_wdata[7:0];  end
        cpu_pal_rdata <= {pc_hi[pwo], pc_lo[pwo]};
        pal_q <= {pv_hi[pal_a], pv_lo[pal_a]};
    end

`ifdef WRALLY2_SCENE

    initial begin
        $readmemh("scene_ve_hi.hex", ce_hi);  $readmemh("scene_ve_lo.hex", ce_lo);
        $readmemh("scene_vo_hi.hex", co_hi);  $readmemh("scene_vo_lo.hex", co_lo);
        $readmemh("scene_ve_hi.hex", t0e_hi); $readmemh("scene_ve_lo.hex", t0e_lo);
        $readmemh("scene_vo_hi.hex", t0o_hi); $readmemh("scene_vo_lo.hex", t0o_lo);
        $readmemh("scene_ve_hi.hex", t1e_hi); $readmemh("scene_ve_lo.hex", t1e_lo);
        $readmemh("scene_vo_hi.hex", t1o_hi); $readmemh("scene_vo_lo.hex", t1o_lo);
        $readmemh("scene_ve_hi.hex", we_hi);  $readmemh("scene_ve_lo.hex", we_lo);
        $readmemh("scene_vo_hi.hex", wo_hi);  $readmemh("scene_vo_lo.hex", wo_lo);
        $readmemh("scene_ve_hi.hex", se_hi);  $readmemh("scene_ve_lo.hex", se_lo);
        $readmemh("scene_vo_hi.hex", so_hi);  $readmemh("scene_vo_lo.hex", so_lo);
        $readmemh("scene_ve_hi.hex", s2e_hi); $readmemh("scene_ve_lo.hex", s2e_lo);
        $readmemh("scene_vo_hi.hex", s2o_hi); $readmemh("scene_vo_lo.hex", s2o_lo);
        $readmemh("scene_pal_hi.hex", pc_hi); $readmemh("scene_pal_lo.hex", pc_lo);
        $readmemh("scene_pal_hi.hex", pv_hi); $readmemh("scene_pal_lo.hex", pv_lo);
        $display("WRALLY2_SCENE: VRAM(paridad)/paleta precargadas (replay)");
    end
`endif
endmodule

`default_nettype wire
