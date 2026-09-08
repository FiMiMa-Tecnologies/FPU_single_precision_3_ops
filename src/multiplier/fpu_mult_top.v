module fpu_mult_top #(

    parameter   WIDTH   = 24,
                T_WID   = (WIDTH - 1),
                I_WID   = (T_WID -1),
                R_WID   = ((WIDTH*2)-1),
                EXP_WID = 8,
                E_WID   = (EXP_WID - 1),
                F_WID   = WIDTH + EXP_WID - 1

)(
    //Entradas
    input   wire                clk, rst,
    input   wire    [1:0]       op,
    input   wire    [E_WID:0]   a_e, b_e,
    input   wire                a_s, b_s,
    input   wire    [I_WID:0]   a_m, b_m,

    //Saídas:
    output wire                 done,
    output wire     [F_WID:0]   result,
    output wire                 guard, round, sticky, overflow, underflow
);

wire [R_WID:0]  r_w;
wire signed [EXP_WID:0] exp_w;
wire            sig_w;
wire [I_WID:0]  mant_w;

fpu_mult_24x24 #(
                .WIDTH      (WIDTH),
                .T_WID      (T_WID),
                .I_WID      (I_WID),
                .R_WID      (R_WID)
                ) fpu_m2424 (
                .a_m        (a_m), 
                .b_m        (b_m),
                .clk        (clk),
                .rst        (rst),
                .op         (op),
                .r_mant_s   (r_w),
                .done       (done)
                );

fpu_mult_exp_calc #(
                .EXP_WID        (EXP_WID),
                .E_WID          (E_WID)
                ) fpu_me (
                .a_e            (a_e),
                .b_e            (b_e),
                .clk            (clk),
                .rst            (rst),
                .norm_inc       (r_w[R_WID]),
                .exp_final      (exp_w),
                .overflow       (overflow),
                .underflow      (underflow)
            );

fpu_mult_norm #(
                .WIDTH          (WIDTH),
                .T_WID          (T_WID),
                .I_WID          (I_WID),
                .R_WID          (R_WID)
                ) fpu_nr (
                .n_anorm        (r_w),
                .n_norm         (mant_w),
                .guard          (guard),
                .round          (round),
                .sticky         (sticky)
                );

fpu_mult_signal fpu_sg 
                (
                .a_s        (a_s), 
                .b_s        (b_s),
                .sig_final  (sig_w)
                );

assign result = {sig_w, exp_w[E_WID:0], mant_w};

endmodule: fpu_mult_top
