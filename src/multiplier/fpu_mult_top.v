module fpu_mult_top (

    parameter   WIDTH   = 24,
                T_WID   = (WIDTH - 1),
                I_WID   = (T_WID -1),
                R_WID   = ((WIDTH*2)-1),
                EXP_WID = 7,
                E_WID   = (EXP_WID - 1)
                F_WID   = WIDTH + EXP_WID;

)(
    //Entradas
    input   wire    [E_WID:0]   a_e, b_e,
    input   wire                a_s, b_s,
    input   wire    [I_WID:0]   a_m, b_m,

    //Saídas:
    output wire     [F_WID:0]   result
);

wire [R_WID:0]  r_w;
wire            exp_w;
wire            sig_w,
wire [I_WID:0]  mant_w;

fpu_mult_24x24 #(
                .WIDTH      (WIDTH),
                .T_WID      (T_WID),
                .I_WID      (I_WID),
                .R_WID      (R_WID)
                ) fpu_m2424 (
                .a_m        (a_m), 
                .b_m        (a_m),
                .r_parc     (r_w)
                );

fpu_exp_calc #(
                .EXP_WID        (EXP_WID),
                .E_WID          (E_WID)
                ) fpu_me (
                .a_e            (a_e), 
                .b_e            (b_e),
                .exp_final      (exp_w)
            );

fpu_norm #(
                .WIDTH          (WIDTH),
                .T_WID          (T_WID),
                .I_WID          (I_WID),
                .R_WID          (R_WID)
                ) fpu_nr (
                .r_parc         (r_parc),
                .mantissa       (mant_w)
                );

fpu_norm_mux #(
                .WIDTH          (WIDTH),
                .T_WID          (T_WID),
                .I_WID          (I_WID),
                .R_WID          (R_WID)
                ) fpu_nm (
                .r_parc         (r_parc),
                .mantissa       (mant_w)
                );

fpu_signal fpu_sg 
                (
                .a_s        (a_s), 
                .b_s        (b_s),
                .sig_final  (sig)
                );

assign result = {sig_w, exp_w, mant_w};

endmodule: fpu_mult_top