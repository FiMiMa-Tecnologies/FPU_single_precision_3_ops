`timescale 1ns/1ps

module testbench;

    localparam [1:0] MUL = 2'b10;

    logic clk = 1'b0;
    logic rst = 1'b0;
    logic [1:0] op = 2'b00;
    logic a_s = 0, b_s = 0;
    logic [7:0] a_e = 0, b_e = 0;
    logic [22:0] a_m = 0, b_m = 0;
    wire [31:0] result;
    wire done, guard, round, sticky, overflow, underflow;
    integer total = 0;
    integer failures = 0;
    integer early_flag_mismatches = 0;

    fpu_mult_top dut (
        .clk(clk), .rst(rst), .op(op),
        .a_s(a_s), .b_s(b_s), .a_e(a_e), .b_e(b_e),
        .a_m(a_m), .b_m(b_m), .result(result), .done(done),
        .guard(guard), .round(round), .sticky(sticky),
        .overflow(overflow), .underflow(underflow)
    );

    // Clock de 10 ns. Entradas aplicadas na borda de descida.
    always #5 clk = ~clk;

    localparam integer NUM_CASES = 100000;
    logic [31:0] random_state = 32'h1a2b3c4d;
    logic [31:0] operand_a, operand_b;
    integer normal_cases = 0, overflow_cases = 0, underflow_cases = 0;
    integer norm_cases = 0;
    integer sign_cases [0:3];
    integer grs_cases [0:7];
    integer i;

    task automatic table_line;
        $display("+--------+----------+----------+----------+----------+---------+---------+---------+---------+------+--------+");
    endtask

    task automatic print_header;
        begin
            $display("");
            $display("FPU MULT TOP | SCOREBOARD | %0d casos | Seed: %08h", NUM_CASES, random_state);
            $display("Operandos/resultados em hexadecimal. Obt/Esp = obtido/esperado.");
            $display("C1 = dados, GRS e done na primeira borda; demais valores na segunda borda.");
            $display("Flags = overflow/underflow. -------- = resultado fora da faixa, sem comparacao.");
            table_line();
            $display("| Caso   |    A     |    B     | Obtido   | Esperado | Classe  | GRS O/E | Flg O/E | D O/E   | C1   | Status |");
            table_line();
        end
    endtask

    task automatic footer_row(input string label_text, input string value_text);
        integer pad;
        begin
            $write("| %s", label_text);
            for (pad = label_text.len(); pad < 43; pad++) $write(" ");
            $write(" | ");
            for (pad = value_text.len(); pad < 12; pad++) $write(" ");
            $display("%s |", value_text);
        end
    endtask

    task automatic print_footer;
        integer index;
        begin
            table_line();
            $display("");
            $display("RESUMO DA EXECUCAO");
            $display("+---------------------------------------------+--------------+");
            footer_row("Metrica", "Valor");
            $display("+---------------------------------------------+--------------+");
            footer_row("Casos executados", $sformatf("%0d", total));
            footer_row("Aprovados", $sformatf("%0d", total - failures));
            footer_row("Falhas", $sformatf("%0d", failures));
            footer_row("Taxa de aprovacao", $sformatf("%0.2f %%", 100.0 * (total - failures) / total));
            footer_row("Resultados normais (comparados)", $sformatf("%0d", normal_cases));
            footer_row("Overflow (resultado nao comparado)", $sformatf("%0d", overflow_cases));
            footer_row("Underflow (resultado nao comparado)", $sformatf("%0d", underflow_cases));
            footer_row("Normalizacoes com incremento do expoente", $sformatf("%0d", norm_cases));
            footer_row("Flags pendentes em C1 (informativo)", $sformatf("%0d", early_flag_mismatches));
            $display("+---------------------------------------------+--------------+");
            for (index = 0; index < 4; index++)
                footer_row($sformatf("Cobertura sinais A/B = %02b", index[1:0]),
                           $sformatf("%0d", sign_cases[index]));
            for (index = 0; index < 8; index++)
                footer_row($sformatf("Cobertura GRS = %03b", index[2:0]),
                           $sformatf("%0d", grs_cases[index]));
            $display("+---------------------------------------------+--------------+");
            footer_row("STATUS FINAL", failures == 0 ? "PASS" : "FAIL");
            $display("+---------------------------------------------+--------------+");
        end
    endtask

    // PRNG xorshift32: sequencia reproduzivel, sem depender do simulador.
    function automatic logic [31:0] next_random();
        begin
            random_state = random_state ^ (random_state << 13);
            random_state = random_state ^ (random_state >> 17);
            random_state = random_state ^ (random_state << 5);
            next_random = random_state;
        end
    endfunction

    function automatic logic [31:0] random_operand();
        logic [31:0] bits_random, exponent_random;
        logic [7:0] exponent;
        begin
            bits_random = next_random();
            exponent_random = next_random();
            // Expoentes 1..254: somente operandos finitos normalizados.
            exponent = 1 + (exponent_random % 254);
            random_operand = {bits_random[31], exponent, bits_random[22:0]};
        end
    endfunction

    task automatic check_mult(
        input logic [31:0] operand_a,
        input logic [31:0] operand_b
    );
        longint unsigned significand_a, significand_b, product;
        logic [31:0] expected;
        logic [2:0] expected_grs;
        logic expected_overflow, expected_underflow;
        logic first_cycle_ok, case_ok;
        string first_cycle_detail, class_text, expected_text;
        integer exponent, shift;
        begin
            // Referencia inteira exata, calculada apenas a partir das entradas.
            // Nao aplica arredondamento: o README especifica truncamento + GRS.
            significand_a = 8388608 + operand_a[22:0];
            significand_b = 8388608 + operand_b[22:0];
            product = significand_a * significand_b;
            exponent = int'(operand_a[30:23]) + int'(operand_b[30:23]) - 127;
            shift = 23;
            if (product >= 64'd140737488355328) begin // 2**47
                shift = 24;
                exponent = exponent + 1;
                norm_cases = norm_cases + 1;
            end
            expected = (product >> shift) & 32'h007fffff;
            expected[30:23] = exponent[7:0];
            expected[31] = operand_a[31] ^ operand_b[31];
            expected_grs[2] = (product >> (shift - 1)) & 1;
            expected_grs[1] = (product >> (shift - 2)) & 1;
            expected_grs[0] = (product % (64'd1 << (shift - 2))) != 0;
            expected_overflow = exponent > 254;
            expected_underflow = exponent <= 0;
            if (expected_overflow) overflow_cases = overflow_cases + 1;
            else if (expected_underflow) underflow_cases = underflow_cases + 1;
            else normal_cases = normal_cases + 1;
            sign_cases[{operand_a[31], operand_b[31]}]++;
            grs_cases[expected_grs]++;

            @(negedge clk);
            op = MUL;
            {a_s, a_e, a_m} = operand_a;
            {b_s, b_e, b_m} = operand_b;
            @(posedge clk);
            #1;
            // done indica disponibilidade da mantissa, nao das flags.
            // Verifica o caminho de dados na primeira borda, sem relaxar
            // sua latencia. As flags registradas usam norm_inc desta borda
            // somente na proxima: mantemos op e operandos estaveis ate la.
            first_cycle_ok = done === 1'b1 &&
                {guard, round, sticky} === expected_grs &&
                (expected_overflow || expected_underflow || result === expected);
            first_cycle_detail = $sformatf("C1: resultado=%08h done=%b GRS=%03b",
                                             result, done, {guard, round, sticky});
            if ({overflow, underflow} !== {expected_overflow, expected_underflow})
                early_flag_mismatches++;
            @(posedge clk);
            #1; // Flags agora incluem a normalizacao do produto atual.
            total = total + 1;
            // Fora da faixa, o README nao define um resultado IEEE especial.
            // Nesses casos verificamos done, GRS e flags, sem comparar result.
            case_ok = first_cycle_ok &&
                (expected_overflow || expected_underflow || result === expected) &&
                done === 1'b1 && {guard, round, sticky} === expected_grs &&
                {overflow, underflow} === {expected_overflow, expected_underflow};
            if (!case_ok) failures++;
            class_text = expected_overflow ? "OVF" : (expected_underflow ? "UDF" : "NORMAL");
            if (expected_overflow || expected_underflow) expected_text = "--------";
            else expected_text = $sformatf("%08h", expected);
            $display("| %6d | %08h | %08h | %08h | %8s | %-7s | %03b/%03b |  %02b/%02b  |   %b/1   | %4s | %4s   |",
                     total, operand_a, operand_b, result, expected_text, class_text,
                     {guard, round, sticky}, expected_grs,
                     {overflow, underflow}, {expected_overflow, expected_underflow},
                     done, first_cycle_ok ? "PASS" : "FAIL", case_ok ? "PASS" : "FAIL");
            if (!first_cycle_ok)
                $display("  Detalhe caso %0d | %s | esperado=%s done=1 GRS=%03b",
                         total, first_cycle_detail, expected_text, expected_grs);
            @(negedge clk);
            op = 2'b00;
        end
    endtask

    initial begin
        $dumpfile("mult_top.vcd");
        $dumpvars(0, testbench);

        // Reset ativo baixo, mantido por dois ciclos.
        repeat (2) @(negedge clk);
        rst = 1'b1;

        print_header();
        for (i = 0; i < 4; i++) sign_cases[i] = 0;
        for (i = 0; i < 8; i++) grs_cases[i] = 0;
        for (i = 0; i < NUM_CASES; i++) begin
            operand_a = random_operand();
            operand_b = random_operand();
            check_mult(operand_a, operand_b);
        end

        print_footer();
        if (failures != 0)
            $fatal(1, "Falha na verificacao do fpu_mult_top.");
        $finish;
    end

    // Impede que uma alteracao futura deixe a simulacao sem terminar.
    initial begin
        #(NUM_CASES * 40 + 100);
        $fatal(1, "Timeout da simulacao.");
    end

endmodule : testbench
