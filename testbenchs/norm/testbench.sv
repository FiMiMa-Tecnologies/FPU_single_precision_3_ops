`timescale 1ns/1ps

module testbench;

parameter   WIDTH = 24,
            T_WID = (WIDTH - 1),
            I_WID = (T_WID -1),
            R_WID = ((WIDTH*2)-1);


logic [R_WID:0] n_anorm;
logic [I_WID:0] n_norm;
logic           guard, round, sticky;

/*
Objetivo do bloco:
1º Indentificar se o estouro de bit ocorreu e à partir disso, gerar os sinais de guard, round e sticky.
2º Realizar o shift do resultado da multiplicação para que ele fique normalizado.
---------------------------------------------------------------------------------------------------------------------------------------
1º Teste possível:
Aplicar um sinal de 48 bits com o bit de estouro ativado e verificar se os sinais de guard, round e sticky são gerados corretamente.
Para este caso, espera-se que:
    > guard = n_anorm[23];
    > round = n_anorm[22];
    > sticky = |n_anorm[21:0];
---------------------------------------------------------------------------------------------------------------------------------------
2º Teste possível:
Aplicar um sinal de 48 bits com o bit de estouro desativado e verificar se os sinais de guard, round e sticky são gerados corretamente.
Para este caso, espera-se que:
    > guard = n_anorm[22];
    > round = n_anorm[21];
    > sticky = |n_anorm[20:0];
---------------------------------------------------------------------------------------------------------------------------------------
Com base nisso, irei de antemão criar 2 sinais virtuais para simular o or unário de sticky em ambos os casos, e assim, facilitar 
a verificação dos resultados.
Irei chamá-los de stick__overflow e stick_no_overflow, e eles serão definidos da seguinte forma:
    > stick_overflow = |n_anorm[21:0];
    > stick_no_overflow = |n_anorm[20:0];

Vou replicar a metodologia com o sinal de guard e round, criando os sinais virtuais guard_overflow, guard_no_overflow, round_overflow 
e round_no_overflow.
    > guard_overflow = n_anorm[23];
    > guard_no_overflow = n_anorm[22];
    > round_overflow = n_anorm[22];
    > round_no_overflow = n_anorm[21];
*/

// Sinais virtualizados para nossos testes de verificação de guard, round e sticky.
//--------------------------------------------
wire stick_overflow    = |n_anorm[21:0];
wire stick_no_overflow = |n_anorm[20:0];
//--------------------------------------------
wire guard_overflow    = n_anorm[23];
wire guard_no_overflow = n_anorm[22];
//--------------------------------------------
wire round_overflow    = n_anorm[22];
wire round_no_overflow = n_anorm[21];
//--------------------------------------------

fpu_mult_norm dut(.*);

task situation_1_test1;
    begin
        div();
        $display("|                                Bit de estouro ativado, guard = 1, round = 1, sticky = 1                            |");
        div();
        // Bit de estouro ativado, guard = 1, round = 1, sticky = 1
        // 23º bit = 1;
        // 22º bit = 1;
        // De 21º bit até o 0º bit, pelo menos um bit = 1;

        n_anorm = 48'b1000_0000_0000_0000_0000_0000_1100_0000_0000_0000_0000_0111; 
        // Estouro: [47]; G/R: [23]/[22] com estouro, [22]/[21] sem estouro.
    end
endtask

//--------------------------------------------

task situation_2_test1;
    begin
        div();
        $display("|                                Bit de estouro desativado, guard = 0, round = 0, sticky = 0                         |");
        div();
        // Bit de estouro desativado, guard = 0, round = 0, sticky = 0
        // 22º bit = 0;
        // 21º bit = 0;
        // De 20º bit até o 0º bit, todos os bits = 0;
        
        n_anorm = 48'b0000_0000_0000_0000_0000_0000_1000_0000_0000_0000_0000_0000; 
        // Estouro: [47]; G/R: [23]/[22] com estouro, [22]/[21] sem estouro.
    end
endtask

//--------------------------------------------

task situation_1_test2;
    begin
        div();
        $display("|                                Bit de estouro ativado, guard = 1, round = 0, sticky = 0                            |");
        div();
        // Bit de estouro ativado, guard = 1, round = 0, sticky = 0
        // 23º bit = 1;
        // 22º bit = 0;
        // De 21º bit até o 0º bit, todos os bits = 0;

        n_anorm = 48'b1000_0000_0000_0000_0000_0001_1000_0000_0000_0000_0000_0000; 
        // Estouro: [47]; G/R: [23]/[22] com estouro, [22]/[21] sem estouro.
    end
endtask

//--------------------------------------------

task situation_2_test2;
    begin
        div();
        $display("|                                Bit de estouro desativado, guard = 0, round = 0, sticky = 1                         |");
        div();
        // Bit de estouro desativado, guard = 0, round = 0, sticky = 1
        // 22º bit = 0;
        // 21º bit = 0;
        // De 20º bit até o 0º bit, pelo menos um bit = 1;
        
        n_anorm = 48'b0000_0000_0000_0000_0000_0000_1001_0000_0000_0000_0000_0000; 
        // Estouro: [47]; G/R: [23]/[22] com estouro, [22]/[21] sem estouro.
    end
endtask

//--------------------------------------------

task situation_1_test3;
    begin
        div();
        $display("|                                Bit de estouro ativado, guard = 1, round = 1, sticky = 0                            |");
        div();
        // Bit de estouro ativado, guard = 1, round = 1, sticky = 0
        // 23º bit = 1;
        // 22º bit = 1;
        // De 21º bit até o 0º bit, todos os bits = 0;

        n_anorm = 48'b1000_0000_0000_0000_0000_0001_1100_0000_0000_0000_0000_0000; 
        // Estouro: [47]; G/R: [23]/[22] com estouro, [22]/[21] sem estouro.
    end
endtask

//--------------------------------------------

task situation_2_test3;
    begin
        div();
        $display("|                                Bit de estouro desativado, guard = 0, round = 1, sticky = 1                         |");
        div();
        // Bit de estouro desativado, guard = 0, round = 1, sticky = 1
        // 22º bit = 0;
        // 21º bit = 1;
        // De 20º bit até o 0º bit, pelo menos um bit = 1;
        
        n_anorm = 48'b0100_0000_0000_0000_0000_0000_0010_0000_0000_0000_0000_0001; 
        // Estouro: [47]; G/R: [23]/[22] com estouro, [22]/[21] sem estouro.
    end
endtask

//--------------------------------------------

task situation_1_test4;
    begin
        div();
        $display("|                                Bit de estouro ativado, guard = 0, round = 1, sticky = 1                            |");
        div();
        // Bit de estouro ativado, guard = 0, round = 1, sticky = 1
        // 23º bit = 0;
        // 22º bit = 1;
        // De 21º bit até o 0º bit, pelo menos um bit = 1;

        n_anorm = 48'b1000_0000_0000_0000_0000_0000_0100_0000_0000_0000_0000_0001; 
        // Estouro: [47]; G/R: [23]/[22] com estouro, [22]/[21] sem estouro.
        div(); 
    end
endtask

//--------------------------------------------

task situation_2_test4;
    begin
        div();
        $display("|                                Bit de estouro desativado, guard = 1, round = 1, sticky = 1                         |");       
        div();
        // Bit de estouro desativado, guard = 1, round = 1, sticky = 1
        // 22º bit = 1
        // 21º bit = 1;
        // De 20º bit até o 0º bit, pelo menos um bit = 1
        
        n_anorm = 48'b0000_0000_0000_0000_0000_0000_1111_0000_0000_0000_0000_0000; 
        // Estouro: [47]; G/R: [23]/[22] com estouro, [22]/[21] sem estouro.
    end
endtask

task div; $display("+--------------------------------------------------------------------------------------------------------------------+"); endtask

task header;
    begin
        div();
        $display("|                                                    Normalizador                                                    |");
        div();
        $display("|                       nanorm                       |           n_norm           | guard | round | sticky || STATUS |");
    end
endtask

task monitor_tk;
begin
                    $monitor(
                    "|  %48b  |  %24b  |   %01b   |   %01b   |    %1b   ||",
                        n_anorm,
                        n_norm,
                        guard,
                        round,
                        sticky
                    );
end
endtask

/*
task pass_tk;
begin
                    $display(
                    "|  %02b  |  %01b  |  %01b  | %023b | %023b || %048b | %048b ||   %01b   ||  PASS  |",
                        op,
                        clk,
                        rst,
                        a_m,
                        b_m,
                        exp_mult,
                        r_mant_s,
                        done,
                    );
end
endtask

task fail_tk;
begin
                    $display(
                    "|  %02b  |  %01b  |  %01b  | %023b | %023b || %048b | %048b ||   %01b   ||  FAIL  |",
                        op,
                        clk,
                        rst,
                        a_m,
                        b_m,
                        exp_mult,
                        r_mant_s,
                        done,
                    );
end
endtask


task check_cases;
    begin
        assert
    end
endtask
*/

initial
    begin
        $dumpfile("dump.vcd");
        $dumpvars(0, dut);
    end

initial
    begin
        header();
        monitor_tk();
        #10 situation_1_test1();
        #10 situation_2_test1();
        #10 situation_1_test2();
        #10 situation_2_test2();
        #10 situation_1_test3();
        #10 situation_2_test3();
        #10 situation_1_test4();
        #10 situation_2_test4();
    end

endmodule: testbench
