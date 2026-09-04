module fpu_exp_calc #(
    parameter   EXP_WID = 8,
                E_WID   = (EXP_WID - 1)
)(
    input   wire                    clk, rst,
    input   wire        [E_WID:0]   a_e, b_e,
    output  wire signed [EXP_WID:0] exp_final,
    output  reg                     underflow, overflow
);

localparam signed [E_WID:0] BIAS = 8'b10000001;

//wire [7:0] exp_sum = a_e + b_e;
//wire [7:0] exp_sub = exp_sum - BIAS;

assign exp_final = a_e + b_e + BIAS;

always@(posedge clk or negedge rst)
    begin
        if(!rst)
            begin
                overflow  <= 1'b0;
                underflow <= 1'b0;
            end
        else
        begin
            if(exp_final[8]==1)
                begin
                    overflow  <= 1'b1;
                    underflow <= 1'b0;
                end

            else
            if((8'b10000010 <= exp_final) && (exp_final <= 8'b11111111))
                begin
                    overflow  <= 1'b0;
                    underflow <= 1'b1;
                end

            else
                begin
                    overflow  <= 1'b0;
                    underflow <= 1'b0;
                end
        end
    end

endmodule