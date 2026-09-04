module fpu_norm #(
    parameter   WIDTH = 24,
                T_WID = (WIDTH - 1),
                I_WID = (T_WID -1),
                R_WID = ((WIDTH*2)-1)
)(
    input  wire    [R_WID:0]    n_anorm,
    input  wire                 qtd_s,
    output wire    [I_WID:0]    r_parc_s,
    output reg                  guard, round, sticky
);

reg [T_WID:0] shift_reg;

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

always@(*)
    begin
        shift_reg = n_anorm >> 24;
    end

assign r_parc_s  = shift_reg[I_WID:0];

endmodule: fpu_mult