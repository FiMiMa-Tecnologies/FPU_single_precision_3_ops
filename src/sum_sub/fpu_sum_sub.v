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
    reg [7:0]  exp_a, exp_b, exp_res, exp_diff;

    // Mantissa de 28 bits:
    // mant_[27]    = overflow bit
    // mant_[26]    = hidden bit
    // mant_[25:3]  = fraction
    // mant_[2]     = Guard
    // mant_[1]     = Round
    // mant_[0]     = Sticky
    reg [27:0] mant_a, mant_b;       
    reg [27:0] mant_res;             
    reg        sticky_bit; 
    reg [28:0] shift_out;

    reg        sign_a, sign_b, sign_res;

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
            // Em espera do sinal de início, permanece no estado IDLE. Quando start é 1, transita para UNPACK.
            IDLE:      next_state = start ? UNPACK : IDLE;

            // Separação dos campos do número flutuante (sinal, expoente e mantissa)
            UNPACK:    next_state = ALIGN; 

            // Deslocamento das mantissas para alinhamento dos expoentes. Se os expoentes forem iguais, verifica se há cancelamento mútuo.
            ALIGN: begin
                if (exp_a == 8'd0 && exp_b == 8'd0) begin
                    if ((op == 2'b00 && sign_a != sign_b && mant_a == mant_b) ||
                        (op == 2'b01 && sign_a == sign_b && mant_a == mant_b))
                        next_state = FINISH; // Cancelamento mútuo -> resultado é Zero
                    else
                        next_state = EXECUTE;
                end else begin
                    next_state = EXECUTE;
                end
            end

            // Realiza a operação de soma ou subtração das mantissas, dependendo do sinal e da operação selecionada.
            EXECUTE:   next_state = NORMALIZE;

            // Normaliza o resultado da operação, ajustando a mantissa e o expoente conforme necessário.
            NORMALIZE: begin
                if (mant_res == 28'd0)
                    next_state = ROUND;
                else if (mant_res[27])
                    next_state = NORMALIZE;
                else if (!mant_res[26] && exp_res != 8'd0)
                    next_state = NORMALIZE;
                else
                    next_state = ROUND;
            end

            // Aplica o arredondamento ao resultado final, considerando o bit de guarda e o bit de arredondamento.
            ROUND:     next_state = FINISH;

            // Finaliza a operação, preparando o resultado final e sinalizando que a operação foi concluída.
            FINISH:    next_state = IDLE;
            default:   next_state = IDLE;
        endcase
    end

    // --- Function para Deslocamento com Retorno Separado de Sticky ---
    function [28:0] shift_right_with_sticky (
        input [27:0] in_mant,
        input [7:0]  shift_amount
    );
        reg [27:0] shifted;
        reg        sticky;
        integer    i;
        begin
            shifted = 28'd0;
            sticky  = 1'b0;

            // Caso 1 (expoentes iguais): se shift_amount for 0, não há deslocamento e sticky é 0
            if (shift_amount == 8'd0) begin
                shifted = in_mant;
                sticky  = 1'b0;
            end 
            // Caso 2 (deslocamento total): se shift_amount for maior ou igual a 28, o resultado é 0 e sticky é 1 se algum bit de in_mant for 1
            else if (shift_amount >= 8'd28) begin
                shifted = 28'd0;
                sticky  = |in_mant;
            end 
            // Caso 3 (deslocamento parcial): desloca in_mant para a direita e calcula sticky
            else begin
                shifted = in_mant >> shift_amount;
                for (i = 0; i < 28; i = i + 1) begin
                    if (i < shift_amount)
                        sticky = sticky | in_mant[i];
                end
            end

            shift_right_with_sticky = {shifted, sticky};
        end
    endfunction

    // --- Datapath ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result     <= 32'd0;
            done       <= 1'b0;
            overflow   <= 1'b0;
            underflow  <= 1'b0;
            exp_res    <= 8'd0;
            mant_a     <= 28'd0;
            mant_b     <= 28'd0;
            mant_res   <= 28'd0;
            sticky_bit <= 1'b0;
            sign_res   <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                end

                UNPACK: begin
                    sign_a     <= a_s;
                    sign_b     <= b_s; 
                    exp_a      <= a_e;
                    exp_b      <= b_e;
                    mant_a     <= {1'b0, 1'b1, a_m, 3'b000}; // [1'b0] = overflow bit, [1'b1] = hidden bit, [a_m] = fraction, [3'b000] = guard, round, sticky
                    mant_b     <= {1'b0, 1'b1, b_m, 3'b000}; // [1'b0] = overflow bit, [1'b1] = hidden bit, [b_m] = fraction, [3'b000] = guard, round, sticky
                    sticky_bit <= 1'b0;
                end

                ALIGN: begin
                    if (exp_a > exp_b) begin
                        exp_diff   = exp_a - exp_b;
                        exp_res    <= exp_a;
                        shift_out  = shift_right_with_sticky(mant_b, exp_diff);
                        mant_b     <= shift_out[28:1];
                        sticky_bit <= shift_out[0];
                    end else if (exp_a == exp_b) begin
                        exp_res    <= exp_a;
                        sticky_bit <= 1'b0;
                        if (mant_a == mant_b) begin
                            if ((op == 2'b01 && sign_a == sign_b) || (op == 2'b00 && sign_a != sign_b)) begin
                                mant_res <= 28'd0;
                                sign_res <= 1'b0; // Resultado é 0.0 positivo
                                exp_res  <= 8'd0;
                            end
                        end
                    end else begin
                        exp_diff   = exp_b - exp_a;
                        exp_res    <= exp_b;
                        shift_out  = shift_right_with_sticky(mant_a, exp_diff);
                        mant_a     <= shift_out[28:1];
                        sticky_bit <= shift_out[0];
                    end
                end

                EXECUTE: begin
                    if ((op == 2'b00 && sign_a == sign_b) || (op == 2'b01 && sign_a != sign_b)) begin
                        mant_res <= mant_a + mant_b + sticky_bit;
                        sign_res <= sign_a;
                    end else begin
                        if (mant_a >= mant_b) begin
                            mant_res <= (mant_a - mant_b) - sticky_bit;
                            sign_res <= sign_a;
                        end else begin
                            mant_res <= (mant_b - mant_a) - sticky_bit;
                            sign_res <= (op == 2'b01) ? ~sign_a : sign_b;
                        end
                    end
                end

                NORMALIZE: begin
                    if (mant_res[27]) begin
                        mant_res <= {1'b0, mant_res[27:1]};
                        exp_res  <= exp_res + 1'b1;
                    end
                    else if (mant_res[26] == 1'b0 && mant_res != 28'd0 && exp_res > 8'd0) begin
                        mant_res   <= {mant_res[26:0], sticky_bit};
                        sticky_bit <= 1'b0; 
                        exp_res    <= exp_res - 1'b1;
                    end
                end

                ROUND: begin
                    if (mant_res[2]) begin
                        mant_res <= mant_res + 28'h8; // Bit Guard (mant_res[2]) é 1, então arredonda para cima o resultado -> round half up
                    end
                end

                FINISH: begin
                    if (mant_res == 28'd0) begin
                        result <= 32'h00000000; // Force +0.0 (IEEE 754) para cancelamento perfeito
                    end else if (mant_res[27]) begin
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