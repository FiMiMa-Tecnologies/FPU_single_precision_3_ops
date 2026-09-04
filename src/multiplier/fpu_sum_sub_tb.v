`timescale 1ns / 1ps

module fpu_sum_sub_tb;

    // --- Sinais da FPU ---
    reg        clk;
    reg        rst_n;
    reg        start;
    reg  [1:0] op;
    reg  [31:0] a;
    reg  [31:0] b;
    wire [31:0] result;
    wire        done;
    wire        overflow;
    wire        underflow;

    // --- Instanciação da FPU (DUT) ---
    fpu_sum_sub dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .op(op),
        .a(a),
        .b(b),
        .result(result),
        .done(done),
        .overflow(overflow),
        .underflow(underflow)
    );

    // --- Gerador de Clock (100 MHz - Período de 10ns) ---
    always #5 clk = ~clk;

    
    // --- MONITOR DE ESTADOS E SINAIS INTERMEDIÁRIOS ---
    always @(posedge clk) begin
        // Exibe logs apenas se a FSM não estiver ociosa (IDLE)
        if (dut.current_state != 3'b000) begin
            $display("--- [Clock %0t ps] ---", $time);
            
            case (dut.current_state)
                3'b001: $display("Estado: UNPACK    | exp_a: %d | exp_b: %d | mant_a: 0x%h | mant_b: 0x%h", 
                                  dut.exp_a, dut.exp_b, dut.mant_a, dut.mant_b);
                                  
                3'b010: $display("Estado: ALIGN     | exp_diff: %d | exp_res: %d | mant_a: 0x%h | mant_b: 0x%h", 
                                  dut.exp_diff, dut.exp_res, dut.mant_a, dut.mant_b);
                                  
                3'b011: $display("Estado: EXECUTE   | sign_res: %b | mant_res: 0x%h", 
                                  dut.sign_res, dut.mant_res);
                                  
                3'b100: $display("Estado: NORMALIZE | exp_res: %d | mant_res: 0x%h", 
                                  dut.exp_res, dut.mant_res);
                                  
                3'b101: $display("Estado: ROUND     | Guard bit[2]: %b | round_up: %b | mant_res: 0x%h", 
                                  dut.mant_res[2], dut.round_up, dut.mant_res);
                                  
                3'b110: $display("Estado: FINISH    | exp_res: %d | mant_res: 0x%h | Result Final: 0x%h", 
                                  dut.exp_res, dut.mant_res, dut.result);
            endcase
        end
    end
    

    // --- Task para Execução Automática dos Testes ---
    task executar_teste(
        input [8*35:1] nome_teste,
        input [1:0]    operacao,
        input [31:0]   val_a,
        input [31:0]   val_b,
        input [31:0]   val_esperado
    );
        begin
            // 1. Aplica as entradas
            a     = val_a;
            b     = val_b;
            op    = operacao;
            
            // 2. Aguarda 1 ciclo para que as entradas a/b fiquem estáveis nas portas do DUT
            #1;
            @(posedge clk);
            start = 1'b1;

            // 3. Reseta o sinal start no clock seguinte
            @(posedge clk);
            start = 1'b0;

            // 4. Aguarda a FSM sinalizar o término da operação
            wait(done);
            @(posedge clk);

            // 5. Exibe e valida o resultado
            $display("--------------------------------------------------");
            $display("Teste: %s", nome_teste);
            $display("A:        0x%h", val_a);
            $display("B:        0x%h", val_b);
            $display("Obtido:   0x%h", result);
            $display("Esperado: 0x%h", val_esperado);

            if (result === val_esperado) begin
                $display("Status:   [PASSOU]");
            end else begin
                $display("Status:   [FALHOU]");
            end

            // Tempo de folga entre testes
            repeat(2) @(posedge clk);
        end
    endtask

    // --- Sequência de Simulação ---
    initial begin
        // Inicialização de Sinais
        clk   = 0;
        rst_n = 0;
        start = 0;
        op    = 0;
        a     = 0;
        b     = 0;

        // Reset do Sistema
        #20;
        rst_n = 1;
        #10;

        $display("==================================================");
        $display("          INICIANDO SIMULACAO DA FPU              ");
        $display("==================================================");


        // 1. Soma: 1.1 + 2.2 = 3.3
        executar_teste("Soma decimal (1.1 + 2.2)", 2'b00, 32'h3F8CCDCD, 32'h400CCDCD, 32'h40533333);

        // 2. Soma: 6.4 + 3.1 = 9.5
        executar_teste("Soma decimal (6.4 + 3.1)", 2'b00, 32'h40CCCDCD, 32'h40466666, 32'h41180000);

        // 3. Subtração: 8.3 - 2.8 = 5.5
        executar_teste("Subtracao decimal (8.3 - 2.8)", 2'b01, 32'h4104CCCC, 32'h40333333, 32'h40B00000);

        // 4. Subtração: 0.4 - 0.15 = 0.25
        executar_teste("Subtracao decimal (0.4 - 0.15)", 2'b01, 32'h3ECCCDCD, 32'h3E19999A, 32'h3E800000);

        // 5. Subtração: 15.6 - 7.8 = 7.8
        executar_teste("Subtracao decimal (15.6 - 7.8)", 2'b01, 32'h4179999A, 32'h40FA6666, 32'h40F9999A);

        /*
        // Caso 1: Adição Básica -> 1.5 + 2.5 = 4.0
        // 1.5 = 0x3FC00000 | 2.5 = 0x40200000 | 4.0 = 0x40800000
        executar_teste("Soma 1.5 + 2.5", 2'b00, 32'h3FC00000, 32'h40200000, 32'h40800000);

        // Caso 2: Adição com Expoentes Diferentes -> 5.0 + 0.5 = 5.5
        // 5.0 = 0x40A00000 | 0.5 = 0x3F000000 | 5.5 = 0x40B00000
        executar_teste("Soma 5.0 + 0.5", 2'b00, 32'h40A00000, 32'h3F000000, 32'h40B00000);
        
        // Caso 3: Adição Resultando em Zero -> 4.0 + (- 4.0) = 0.0
        // 4.0 = 0x40800000 | -4.0 = 0xC0800000 | 0.0 = 0x00000000
        executar_teste("Soma 4.0 + (-4.0)", 2'b00, 32'h40800000, 32'hC0800000, 32'h00000000);

        // Caso 4: Subtração Básica -> 5.0 - 2.0 = 3.0
        // 5.0 = 0x40A00000 | 2.0 = 0x40000000 | 3.0 = 0x40400000
        executar_teste("Subtracao 5.0 - 2.0", 2'b01, 32'h40A00000, 32'h40000000, 32'h40400000);

        // Caso 5: Subtração Resultando em Valor Negativo -> 1.0 - 3.0 = -2.0
        // 1.0 = 0x3F800000 | 3.0 = 0x40400000 | -2.0 = 0xC0000000
        executar_teste("Subtracao 1.0 - 3.0", 2'b01, 32'h3F800000, 32'h40400000, 32'hC0000000);

        // Caso 6: Adição de dois Valores Negativos -> -2.0 + -4.0 = -6.0
        // -2.0 = 0xC0000000 | -4.0 = 0xC0800000 | -6.0 = 0xC0C00000
        executar_teste("Soma -2.0 + -4.0", 2'b00, 32'hC0000000, 32'hC0800000, 32'hC0C00000);

        // Caso 7: Subração de dois Valores Negativos -> -5.0 - (-2.0) = -3.0
        // -5.0 = 0xC0A00000 | -2.0 = 0xC0000000 | -3.0 = 0xC0400000
        executar_teste("Subtracao -5.0 - (-2.0)", 2'b01, 32'hC0A00000, 32'hC0000000, 32'hC0400000);

        
        // ----------------------------------------------------
        // TESTES ESPECÍFICOS DE ARREDONDAMENTO (ROUND HALF UP)
        // ----------------------------------------------------

        // Soma: 2.5 + 1.3 = 3.8
        executar_teste("Soma decimal (2.5 + 1.3)", 2'b00, 32'h40200000, 32'h3FA66666, 32'h40733333);

        // Soma: 3.25 + 1.50 = 4.75
        executar_teste("Soma decimal exata (3.25 + 1.50)", 2'b00, 32'h40500000, 32'h3FC00000, 32'h40980000);

        // Subtração: 5.8 - 2.3 = 3.5
        executar_teste("Subtracao decimal (5.8 - 2.3)", 2'b01, 32'h40B9999A, 32'h40133333, 32'h40600000);

        // Subtração: 10.0 - 2.5 = 7.5
        executar_teste("Subtracao decimal exata (10.0 - 2.5)", 2'b01, 32'h41200000, 32'h40200000, 32'h40F00000);

        // ----------------------------------------------------
        // TESTES DE ARREDONDAMENTO COM DECIMAIS (IEEE-754)
        // ----------------------------------------------------

        // 1. Soma dízimas: 0.7 + 0.3 = 1.0 exato
        executar_teste("Soma decimal (0.7 + 0.3)", 2'b00, 32'h3F333333, 32'h3E99999A, 32'h3F800000);

        // 2. Soma decimal: 1.1 + 2.2 = 3.3
        executar_teste("Soma decimal (1.1 + 2.2)", 2'b00, 32'h3F8CCDCD, 32'h400CCDCD, 32'h40533333);

        // 3. Soma dízimas: 0.85 + 0.15 = 1.0 exato
        executar_teste("Soma decimal (0.85 + 0.15)", 2'b00, 32'h3F59999A, 32'h3E19999A, 32'h3F800000);

        // 4. Soma decimal: 6.4 + 3.1 = 9.5
        executar_teste("Soma decimal (6.4 + 3.1)", 2'b00, 32'h40CCCDCD, 32'h40466666, 32'h41180000);;

        // 5. Soma exata sem dízima: 12.75 + 0.375 = 13.125
        executar_teste("Soma exata (12.75 + 0.375)", 2'b00, 32'h414C0000, 32'h3EC00000, 32'h41520000);

        // 6. Subtração decimal: 3.7 - 1.2 = 2.5
        executar_teste("Subtracao decimal (3.7 - 1.2)", 2'b01, 32'h406CCCCD, 32'h3F99999A, 32'h40200000);

        // 7. Subtração decimal: 8.3 - 2.8 = 5.5
        executar_teste("Subtracao decimal (8.3 - 2.8)", 2'b01, 32'h4104CCCC, 32'h40333333, 32'h40B00000);

        // 8. Subtração com shift-left: 1.4 - 0.9 = 0.5
        executar_teste("Subtracao decimal (1.4 - 0.9)", 2'b01, 32'h3FB33333, 32'h3F666666, 32'h3F000000);

        // 9. Subtração decimal: 0.4 - 0.15 = 0.25
        executar_teste("Subtracao decimal (0.4 - 0.15)", 2'b01, 32'h3ECCCDCD, 32'h3E19999A, 32'h3E800000);

        // 10. Subtração decimal: 15.6 - 7.8 = 7.8
        executar_teste("Subtracao decimal (15.6 - 7.8)", 2'b01, 32'h4179999A, 32'h40FA6666, 32'h40F9999A);
        */
        $display("==================================================");
        $display("          SIMULACAO FINALIZADA                    ");
        $display("==================================================");
        $finish;
    end

endmodule