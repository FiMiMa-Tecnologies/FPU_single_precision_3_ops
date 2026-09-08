module fpu_mult_exp_calc #(
    parameter   EXP_WID = 8,
                E_WID   = (EXP_WID - 1)
)(
    input   wire                    clk,
    input   wire                    rst,
    input   wire        [E_WID:0]   a_e,
    input   wire        [E_WID:0]   b_e,
    input   wire                    norm_inc,

    output  wire signed [EXP_WID:0] exp_final,
    output  reg                     underflow,
    output  reg                     overflow
);

localparam signed [EXP_WID+1:0] BIAS    = 10'sd127;
localparam signed [EXP_WID+1:0] MAX_EXP = 10'sd254;

wire signed [EXP_WID+1:0] a_e_ext;
wire signed [EXP_WID+1:0] b_e_ext;
wire signed [EXP_WID+1:0] exp_calc;

assign a_e_ext = $signed({2'b00, a_e});
assign b_e_ext = $signed({2'b00, b_e});

// Ea + Eb - Bias + ajuste da normalização
assign exp_calc = a_e_ext + b_e_ext - BIAS + norm_inc;
assign exp_final = exp_calc[EXP_WID:0];

always @(posedge clk or negedge rst)
    begin
        if(!rst)
            begin
                overflow  <= 1'b0;
                underflow <= 1'b0;
            end
        else
            begin
                if(exp_calc > MAX_EXP)
                    begin
                        overflow  <= 1'b1;
                        underflow <= 1'b0;
                    end

                else if(exp_calc <= 0)
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