module fpu_exp_calc #(
    parameter   EXP_WID = 7,
                E_WID   = (EXP_WID - 1),
)(
    input   wire    [E_WID:0]   a_e, b_e,
    output  wire    [E_WID:0]   exp_final
);

localparam BIAS = 127;

wire [7:0] exp_sum = a_e + b_e;
wire [7:0] exp_sub = exp_sum - BIAS;

assign exp_final = exp_sub;

endmodule