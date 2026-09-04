module fpu_signal (
    input   wire a_s, b_s,
    output  wire sig_final
);

assign sig_final = a_s ^ b_s;

endmodule