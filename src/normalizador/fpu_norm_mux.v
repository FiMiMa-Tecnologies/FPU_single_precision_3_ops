module fpu_norm_mux (
    input   wire op_mode,
    input   wire shifts,
    output  wire qtd_s
);

localparam  SUM_SUB = 1'b1,
            MULT    = 1'b0;

always@(*)
    begin
        if(op_mode == SUM_SUB)  qtd_s = shifts;
        else                    qtd_s = 24; 
    end

endmodule: fpu_norm_mux