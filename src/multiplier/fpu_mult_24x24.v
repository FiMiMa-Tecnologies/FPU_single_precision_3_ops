module fpu_mult_24x24 #(
    parameter   WIDTH = 24,
                T_WID = (WIDTH - 1),
                I_WID = (T_WID -1),
                R_WID = ((WIDTH*2)-1)
)(
    input   wire    [I_WID:0]   a_m, b_m,
    output  wire    [R_WID:0]   r_parc
   //output  wire                done
);
// Wire declarations:
wire imp_bit = 1;
wire [T_WID:0] r_s;

// Signal Attach:
assign a_m_s = {imp_bit, a_m};
assign b_m_s = {imp_bit, b_m};

// Operation
assign r_parc = (a_m_s * b_ms)

endmodule: fpu_mult