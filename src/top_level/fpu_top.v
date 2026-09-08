module fpu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,

    input  wire [1:0]  op,

    input  wire [31:0] a,
    input  wire [31:0] b,

    output reg  [31:0] result,
    output reg         done,

    output reg         guard,
    output reg         round,
    output reg         sticky,

    output reg         overflow,
    output reg         underflow
);


// -----------------------------------------------------------------------------
// Códigos de operação
// -----------------------------------------------------------------------------

localparam ADD = 2'b00;
localparam SUB = 2'b01;
localparam MUL = 2'b10;
localparam RES = 2'b11;


// -----------------------------------------------------------------------------
// Registradores da operação atual
//
// Os operandos e a operação são armazenados quando start é recebido.
// Dessa forma, as entradas externas podem mudar enquanto a FPU processa
// a operação atual.
// -----------------------------------------------------------------------------

reg [31:0] a_reg;
reg [31:0] b_reg;
reg [1:0]  op_reg;

reg active;


// -----------------------------------------------------------------------------
// Campos IEEE 754 dos operandos registrados
// -----------------------------------------------------------------------------

wire        a_s;
wire        b_s;

wire [7:0]  a_e;
wire [7:0]  b_e;

wire [22:0] a_m;
wire [22:0] b_m;


assign a_s = a_reg[31];
assign b_s = b_reg[31];

assign a_e = a_reg[30:23];
assign b_e = b_reg[30:23];

assign a_m = a_reg[22:0];
assign b_m = b_reg[22:0];


// =============================================================================
// SOMADOR / SUBTRATOR
// =============================================================================

// -----------------------------------------------------------------------------
// Controle
// -----------------------------------------------------------------------------

reg sum_sub_start;

// -----------------------------------------------------------------------------
// Saídas internas
// -----------------------------------------------------------------------------

wire [31:0] sum_sub_result;
wire sum_sub_done;
wire sum_sub_overflow;
wire sum_sub_underflow;

// -----------------------------------------------------------------------------
// Instância
// -----------------------------------------------------------------------------

fpu_sum_sub fpu_ss (
                    .clk        (clk),
                    .rst_n      (rst_n),
                    .start      (sum_sub_start),
                    .op         (op_reg),
                    .a          (a_reg),
                    .b          (b_reg),
                    .result     (sum_sub_result),
                    .done       (sum_sub_done),
                    .overflow   (sum_sub_overflow),
                    .underflow  (sum_sub_underflow)
                    );


// =============================================================================
// MULTIPLICADOR
// =============================================================================

// -----------------------------------------------------------------------------
// Controle da operação enviada ao multiplicador
//
// O multiplicador somente recebe MUL enquanto uma operação de multiplicação
// estiver ativa.
//
// Nos demais momentos recebe RES.
// -----------------------------------------------------------------------------

wire [1:0] mult_op;

assign mult_op =
    (active && (op_reg == MUL))
    ? MUL
    : RES;


// -----------------------------------------------------------------------------
// Saídas internas
// -----------------------------------------------------------------------------

wire [31:0] mult_result;

wire mult_done;

wire mult_guard;
wire mult_round;
wire mult_sticky;

wire mult_overflow;
wire mult_underflow;


// -----------------------------------------------------------------------------
// Instância
// -----------------------------------------------------------------------------

fpu_mult_top fpu_mult (
                        .clk        (clk),
                        .rst        (rst_n),
                        .op         (mult_op),
                        .a_e        (a_e),
                        .b_e        (b_e),
                        .a_s        (a_s),
                        .b_s        (b_s),
                        .a_m        (a_m),
                        .b_m        (b_m),
                        .done       (mult_done),
                        .result     (mult_result),
                        .guard      (mult_guard),
                        .round      (mult_round),
                        .sticky     (mult_sticky),
                        .overflow   (mult_overflow),
                        .underflow  (mult_underflow)
                    );


// =============================================================================
// CONTROLE DO TOP LEVEL
// =============================================================================

always @(posedge clk or negedge rst_n)
begin

    if (!rst_n)
    begin
        a_reg           <= 32'd0;
        b_reg           <= 32'd0;
        op_reg          <= RES;
        active          <= 1'b0;
        sum_sub_start   <= 1'b0;
        result          <= 32'd0;
        done            <= 1'b0;
        guard           <= 1'b0;
        round           <= 1'b0;
        sticky          <= 1'b0;
        overflow        <= 1'b0;
        underflow       <= 1'b0;
    end

    else
    begin

        // ---------------------------------------------------------------------
        // Valores padrão
        // ---------------------------------------------------------------------
        done        <= 1'b0;
        // start interno do somador/subtrator é sempre um pulso
        sum_sub_start <= 1'b0;


        // =====================================================================
        // FPU livre
        // =====================================================================

        if (!active)
        begin
            if (start)
            begin
                // -------------------------------------------------------------
                // Nova operação
                // -------------------------------------------------------------
                a_reg  <= a;
                b_reg  <= b;
                op_reg <= op;

                // -------------------------------------------------------------
                // ADD / SUB
                // -------------------------------------------------------------

                if ((op == ADD) || (op == SUB))
                begin
                    active <= 1'b1;
                    // O pulso será visto pelo fpu_sum_sub no próximo clock
                    sum_sub_start <= 1'b1;
                end


                // -------------------------------------------------------------
                // MUL
                // -------------------------------------------------------------

                else if (op == MUL)
                begin
                    active      <= 1'b1;
                end

                // -------------------------------------------------------------
                // Operação reservada / inválida
                // -------------------------------------------------------------
                else
                begin
                    active      <= 1'b0;
                    result      <= 32'd0;
                    guard       <= 1'b0;
                    round       <= 1'b0;
                    sticky      <= 1'b0;
                    overflow    <= 1'b0;
                    underflow   <= 1'b0;
                    done        <= 1'b1;
                end

            end

        end

        // =====================================================================
        // Operação em andamento
        // =====================================================================
        else
        begin

            case (op_reg)

                // =============================================================
                // ADD
                // =============================================================

                ADD:
                begin

                    if (sum_sub_done)
                    begin
                        result      <= sum_sub_result;
                        overflow    <= sum_sub_overflow;
                        underflow   <= sum_sub_underflow;

                        // O fpu_sum_sub não exporta GRS
                        guard       <= 1'b0;
                        round       <= 1'b0;
                        sticky      <= 1'b0;
                        done        <= 1'b1;
                        active      <= 1'b0;
                    end

                end

                // =============================================================
                // SUB
                // =============================================================

                SUB:
                begin
                    if (sum_sub_done)
                    begin
                        result      <= sum_sub_result;
                        overflow    <= sum_sub_overflow;
                        underflow   <= sum_sub_underflow;

                        // O fpu_sum_sub não exporta GRS
                        guard       <= 1'b0;
                        round       <= 1'b0;
                        sticky      <= 1'b0;
                        done        <= 1'b1;
                        active      <= 1'b0;
                    end

                end

                // =============================================================
                // MUL
                // =============================================================

                MUL:
                begin
                    if (mult_done)
                    begin
                        result      <= mult_result;
                        guard       <= mult_guard;
                        round       <= mult_round;
                        sticky      <= mult_sticky;
                        overflow    <= mult_overflow;
                        underflow   <= mult_underflow;
                        done        <= 1'b1;
                        active      <= 1'b0;
                    end
                end

                // =============================================================
                // RES
                // =============================================================

                default:
                begin
                    result      <= 32'd0;
                    guard       <= 1'b0;
                    round       <= 1'b0;
                    sticky      <= 1'b0;
                    overflow    <= 1'b0;
                    underflow   <= 1'b0;
                    done        <= 1'b1;
                    active      <= 1'b0;
                end

            endcase
        end
    end
end

endmodule