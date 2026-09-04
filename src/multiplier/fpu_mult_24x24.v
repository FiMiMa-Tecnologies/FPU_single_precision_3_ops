module fpu_mult_24x24 #(
    parameter   WIDTH = 24,
                T_WID = (WIDTH - 1),
                I_WID = (T_WID -1),
                R_WID = ((WIDTH*2)-1)
)(
    input   wire    [I_WID:0]   a_m, b_m,
    input   wire                clk, rst,
    output  reg     [R_WID:0]   r_mant_s,
    output  reg                 done
);
// Wire declarations:
wire imp_bit = 1;
wire [T_WID:0] r_s;
wire [R_WID:0] r_parc;

// Signal Attach:
assign a_m_s = {imp_bit, a_m};
assign b_m_s = {imp_bit, b_m};

// Operation
assign r_parc = (a_m_s * b_ms)

always@(posedge clk or negedge rst)
    begin
        if(!rst)
            begin
               r_mant_s = 0;
               done     = 0;
            end
        else
            begin
                if(r_parc[R_WID] == 1)
                    begin
                        r_mant_s = r_parc;
                        done     = 1'b1;
                    end
                else
                    begin
                        r_mant_s = {R_WID{1'Z}};
                        done     = 1'b0;
                    end
            end
    end

endmodule: fpu_mult_24x24