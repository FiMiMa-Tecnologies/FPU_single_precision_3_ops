module fpu_sum_sub (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] op, // 2'b00: ADD, 2'b01: SUB
    input wire [31:0] a,
    input wire [31:0] b,
    output reg [31:0] result,
    output reg done,
    output reg overflow,
    output reg underflow
);

    // --- Extração dos Campos IEEE-754 ---
    wire        a_s = a[31];
    wire        b_s = b[31];
    wire [7:0]  a_e = a[30:23];
    wire [7:0]  b_e = b[30:23];
    wire [22:0] a_m = a[22:0];
    wire [22:0] b_m = b[22:0];

    // --- Registradores de Trabalho Internos ---
    reg [7:0]  exp_a, exp_b, exp_res;
    reg [27:0] mant_a, mant_b;       
    reg [27:0] mant_res;             
    
    reg        sign_a, sign_b, sign_res;
    reg [7:0]  exp_diff;
    reg        round_up;

    // --- Codificação de Estados ---
    localparam IDLE      = 3'b000;
    localparam UNPACK    = 3'b001;
    localparam ALIGN     = 3'b010;
    localparam EXECUTE   = 3'b011;
    localparam NORMALIZE = 3'b100;
    localparam ROUND     = 3'b101;
    localparam FINISH    = 3'b110;

    reg [2:0] current_state, next_state;

    // --- Atualização do Estado Atual ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // --- Lógica do Próximo Estado ---
    always @(*) begin
        case (current_state)
            IDLE:      next_state = start ? UNPACK : IDLE;
            UNPACK:    next_state = ALIGN;
            ALIGN:     next_state = EXECUTE;
            EXECUTE:   next_state = NORMALIZE;
            NORMALIZE: begin
                if (mant_res[27] == 1'b0 && mant_res[26] == 1'b0 && mant_res != 28'd0 && exp_res > 8'd0)
                    next_state = NORMALIZE;
                else
                    next_state = ROUND;
            end
            ROUND:     next_state = FINISH;
            FINISH:    next_state = IDLE;
            default:   next_state = IDLE;
        endcase
    end

    // --- Function para Deslocamento à Direita com Cálculo do Bit Sticky ---
    function [27:0] shift_right_sticky (input [27:0] in_mant, input [7:0] shift_amount);
        reg [27:0] shifted;
        reg        sticky;
        begin
            if (shift_amount >= 8'd28) begin
                shifted = 28'd0;
                sticky  = |in_mant;
            end else if (shift_amount == 0) begin
                shifted = in_mant;
                sticky  = 1'b0;
            end else begin
                shifted = in_mant >> shift_amount;
                sticky  = |(in_mant & ((1 << shift_amount) - 1));
            end
            shift_right_sticky = {shifted[27:1], shifted[0] | sticky};
        end
    endfunction

    // --- Datapath ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result    <= 32'd0;
            done      <= 1'b0;
            overflow  <= 1'b0;
            underflow <= 1'b0;
            exp_res   <= 8'd0;
            round_up  <= 1'b0;
            mant_a    <= 28'd0;
            mant_b    <= 28'd0;
            mant_res  <= 28'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                end

                UNPACK: begin
                    sign_a  <= a_s;
                    sign_b  <= b_s; 
                    exp_a   <= a_e;
                    exp_b   <= b_e;
                    // Bit [27]=0 | [26]=1 (implícito) | [25:3]=mantissa | [2:0]=000 (GRS)
                    mant_a  <= {1'b0, 1'b1, a_m, 3'b000};
                    mant_b  <= {1'b0, 1'b1, b_m, 3'b000};
                end

                ALIGN: begin
                    if (exp_a >= exp_b) begin
                        exp_diff = exp_a - exp_b;
                        exp_res  <= exp_a;
                        mant_b   <= shift_right_sticky(mant_b, exp_diff);
                    end else begin
                        exp_diff = exp_b - exp_a;
                        exp_res  <= exp_b;
                        mant_a   <= shift_right_sticky(mant_a, exp_diff);
                    end
                end

                EXECUTE: begin
                    if (op == 2'b00) begin // Adição
                        if (sign_a == sign_b) begin
                            mant_res <= mant_a + mant_b;
                            sign_res <= sign_a;
                        end else begin
                            if (mant_a >= mant_b) begin
                                mant_res <= mant_a - mant_b;
                                sign_res <= sign_a;
                            end else begin
                                mant_res <= mant_b - mant_a;
                                sign_res <= sign_b;
                            end
                        end
                    end
                    else if (op == 2'b01) begin // Subtração
                        if (sign_a != sign_b) begin
                            mant_res <= mant_a + mant_b;
                            sign_res <= sign_a;
                        end else begin
                            if (mant_a >= mant_b) begin
                                mant_res <= mant_a - mant_b;
                                sign_res <= sign_a;
                            end else begin
                                mant_res <= mant_b - mant_a;
                                sign_res <= ~sign_a;
                            end
                        end
                    end
                end

                NORMALIZE: begin
                    if (mant_res[27]) begin
                        mant_res <= shift_right_sticky(mant_res, 8'd1);
                        exp_res  <= exp_res + 1'b1;
                    end
                    else if (mant_res[26] == 1'b0 && mant_res != 28'd0 && exp_res > 8'd0) begin
                        mant_res <= {mant_res[26:0], 1'b0};
                        exp_res  <= exp_res - 1'b1;
                    end
                end

                ROUND: begin
                    round_up <= mant_res[2];
                    if (mant_res[2]) begin
                        mant_res <= mant_res + (1'b1 << 3);
                    end
                end

                FINISH: begin
                    if (mant_res[27]) begin
                        result <= {sign_res, exp_res + 1'b1, mant_res[26:4]};
                    end else begin
                        result <= {sign_res, exp_res, mant_res[25:3]};
                    end
                    
                    done      <= 1'b1;
                    overflow  <= (exp_res == 8'hFF);
                    underflow <= (exp_res == 8'h00);
                end
            endcase
        end
    end

endmodule