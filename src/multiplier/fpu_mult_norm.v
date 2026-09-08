`timescale 1ns/1ps

module fpu_mult_norm #(
    parameter   WIDTH = 24,
                T_WID = (WIDTH - 1),
                I_WID = (T_WID -1),
                R_WID = ((WIDTH*2)-1)
)(
    input  wire    [R_WID:0]    n_anorm,
    output wire    [I_WID:0]    n_norm,
    output reg                  guard, round, sticky
);

wire [T_WID:0] shift_reg;

always@(*)
    begin
        //Indentifica se o bit de estouro existe:
        if(n_anorm[(R_WID)] == 1'b1)
            begin
                guard    =  n_anorm[23];
                round    =  n_anorm[22];    
                sticky   = |n_anorm[21:0];           
            end
        //Sem ele:
        else
            begin
                guard    =  n_anorm[22];
                round    =  n_anorm[21];    
                sticky   = |n_anorm[20:0];  
            end    
    end

// Seleciona o significando de 24 bits conforme o bit de estouro.
assign shift_reg = n_anorm[R_WID] ? (n_anorm >> WIDTH)
                                     : (n_anorm >> T_WID);
assign n_norm  = shift_reg[I_WID:0];

endmodule: fpu_mult_norm
