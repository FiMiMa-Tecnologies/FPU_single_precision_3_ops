module fpu_mult_24x24 #(
    parameter   WIDTH = 24,
                T_WID = (WIDTH - 1),
                I_WID = (T_WID -1),
                R_WID = ((WIDTH*2)-1)
)(
    input   wire    [I_WID:0]   a_m, b_m,
    input   wire    [1:0]       op, 
    input   wire                clk, rst,
    output  reg     [R_WID:0]   r_mant_s,
    output  reg                 done
);
// Operation codes:
localparam  ADD = 2'b00,
            SUB = 2'b01,
            MUL = 2'b10,
            RES = 2'b11;

// Wire declarations:
wire imp_bit = 1;
wire [T_WID:0] r_s;
wire [R_WID:0] r_parc;

// Signal Attach:
wire   [T_WID:0] a_m_s;
wire   [T_WID:0] b_m_s;
wire enable;
reg  start_op;


assign  a_m_s[23]      = imp_bit;
assign  a_m_s[22:0]    = a_m;

assign  b_m_s[23]      = imp_bit;
assign  b_m_s[22:0]    = b_m;

//wire b_m_s = {imp_bit, b_m};

// Operation
assign r_parc = (a_m_s * b_m_s);

//r_parc[R_WID] == 1

//assign end_op = |r_parc;

always@(*)
    begin
        case(op)
            ADD:     start_op = 1'b0;
            SUB:     start_op = 1'b0;
            MUL:     start_op = 1'b1;
            RES:     start_op = 1'b0;
            default: start_op = 1'b0;
        endcase
    end 

/*
always@(posedge clk or negedge rst)
    begin
        if(!rst)                  done     <= 1'b0;
        else
            begin
                if(start_op == 1) done     <= 1'b1;
                else              done     <= 1'b0;
            end
    end
*/

always@(posedge clk or negedge rst)
    begin
        if(!rst)    
            begin
                r_mant_s <= 0;
                done     <= 1'b0;
            end
        else
            begin
                if(start_op == 1)
                    begin
                        r_mant_s <= r_parc;
                        done     <= 1'b1;
                    end
                else
                    begin
                        r_mant_s <= {R_WID{1'b0}};                
                        done     <= 1'b0;
                    end
            end
    end

/*
always@(posedge clk or negedge rst)
    begin
        if(!rst) r_mant_s <= 0;
        else
            begin
                if(done == 1) r_mant_s <= r_parc;
                else          r_mant_s <= {R_WID{1'b0}};
            end 
    end
*/

endmodule: fpu_mult_24x24