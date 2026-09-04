module fpu_norm #(
    parameter   WIDTH = 24,
                T_WID = (WIDTH - 1),
                I_WID = (T_WID -1),
                R_WID = ((WIDTH*2)-1)
)(
    input  wire    [R_WID:0]    n_anorm,
    input  wire                 qtd_s,
    output reg     [I_WID:0]    mantissa
);

wire [T_WID:0] shift_reg = n_anorm >> qtd_s;

assign mantissa  = shift_reg[I_WID:0];

endmodule: fpu_mult