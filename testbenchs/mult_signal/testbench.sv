`timescale 1ns / 1ps

module fpu_mult_signal_tb;

// I/Os para o sinal
logic a_s, b_s;
logic clk, rst;
logic sig_final;

// Variável de referência do Scoreboard
logic exp_sig;

fpu_signal dut (.*);

/* -------------------------------------------------------------------------- */
/* SCOREBOARD                                                                 */
/* -------------------------------------------------------------------------- */

int pass = 0;
int fail = 0;

always #5 clk = ~clk;

task reset;
    begin
        rst = 0;
        clk = 0;
        #5;
        rst = 1;
        #10;
    end
endtask

task test_signals;
    begin
        // Tabela verdade completa para a operação XOR de 2 entradas
        a_s = 0; b_s = 0; #10; check_op();
        a_s = 0; b_s = 1; #10; check_op();
        a_s = 1; b_s = 0; #10; check_op();
        a_s = 1; b_s = 1; #10; check_op();
    end
endtask

initial
    begin
        $dumpfile("dump.vcd");
        $dumpvars(0, fpu_mult_signal_tb);
    end

task div; $display("+-------------------------------------------------------+"); endtask

task header;
    begin
        div();
        $display("|           Teste de Sinal da Multiplicação             |");
        div();
        $display("| A_S | B_S || Esperado | Obtido || Done  || Status  |");
        div();
    end
endtask

task pass_tk;
    begin
        $display("|  %1b  |  %1b  ||    %1b    |   %1b    ||   -   ||  PASS   |",
                    a_s, b_s, exp_sig, sig_final);
    end
endtask

task fail_tk;
    begin
        $display("|  %1b  |  %1b  ||    %1b    |   %1b    ||   -   ||  FAIL   |",
                    a_s, b_s, exp_sig, sig_final);
    end
endtask

task check_op;
    begin
        // Modelo de referência esperado para o sinal da multiplicação (XOR)
        exp_sig = a_s ^ b_s;

        // Validação comparando o resultado com o hardware
        if (exp_sig === sig_final) begin
            div();
            pass++;
            pass_tk();
        end else begin
            div();
            fail++;
            fail_tk();
        end
    end
endtask

initial
    begin
        reset();
        header();

        #10;
        test_signals();
        #10;

        div();
        $display("Simulação Finalizada. PASS: %0d | FAIL: %0d", pass, fail);
        div();

        $finish;
    end

endmodule