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

    /*
    // --- MONITOR DE ESTADOS E SINAIS INTERMEDIÁRIOS (para Debug) ---
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
    */

    // --- Task para Execução Automática dos Testes ---
    task executar_teste(
        input [8*35:1] nome_teste,
        input [1:0]    operacao,
        input [31:0]   val_a,
        input [31:0]   val_b,
        input [31:0]   val_esperado
    );
        begin
            // Aplica as entradas
            a     = val_a;
            b     = val_b;
            op    = operacao;
            
            // Aguarda 1 ciclo para que as entradas a/b fiquem estáveis nas portas do DUT
            #1;
            @(posedge clk);
            start = 1'b1;

            // Reseta o sinal start no clock seguinte
            @(posedge clk);
            start = 1'b0;

            // Aguarda a FSM sinalizar o término da operação
            wait(done);
            @(posedge clk);

            // Exibe e valida o resultado
            $display("--------------------------------------------------");
            $display("Teste: %s", nome_teste);
            $display("A:        0x%h", val_a);
            $display("B:        0x%h", val_b);
            $display("Obtido:    0x%h", result);
            $display("Esperado:  0x%h", val_esperado);
            $display("Overflow: %b | Underflow: %b", overflow, underflow);

            if (result === val_esperado) begin
                $display("Status:   [PASSOU]");
            end else if (((result - val_esperado) === 32'h00000001 || (val_esperado - result) === 32'hFFFFFFFF)) 
                begin
                $display("Status:   [PASSOU COM DIFERENCA DE 1 BIT]");
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

        // ----------------------------------------------------
        // Operações de mesmo sinal (adição e subtração)
        // ----------------------------------------------------
        // 1. Soma: 1.1 + 2.2 = 3.3
        // 1.1 = 0x3F8CCCCD | 2.2 = 0x400CCCCD | 4.0 = 0x40533333
        executar_teste("Soma decimal (1.1 + 2.2)", 2'b00, 32'h3F8CCCCD, 32'h400CCCCD, 32'h40533333);

        // 2. Soma: 6.4 + 3.1 = 9.5
        // 6.4 = 0x40CCCCCD | 3.1 = 0x40466666 | 9.5 = 0x41180000
        executar_teste("Soma decimal (6.4 + 3.1)", 2'b00, 32'h40CCCCCD, 32'h40466666, 32'h41180000);

        // 3. Subtração: 8.3 - 2.8 = 5.5
        // 8.3 = 0x4104CCCD | 2.8 = 0x40333333 | 5.5 = 0x40B00000
        executar_teste("Subtracao decimal (8.3 - 2.8)", 2'b01, 32'h4104CCCD, 32'h40333333, 32'h40B00000);

        // 4. Subtração: 0.4 - 0.15 = 0.25
        // 0.4 = 0x3ECCCDCD | 0.15 = 0x3E19999A | 0.25 = 0x3E800000
        executar_teste("Subtracao decimal (0.4 - 0.15)", 2'b01, 32'h3ECCCCCD, 32'h3E19999A, 32'h3E800000);

        // 5. Subtração: 15.6 - 7.8 = 7.8
        // 15.6 = 0x4179999A | 7.8 = 0x40FA6666 | 7.8 = 0x40F9999A
        executar_teste("Subtracao decimal (15.6 - 7.8)", 2'b01, 32'h4179999A, 32'h40F9999A, 32'h40F9999A);
        
        // 6. Soma: 1.5 + 2.5 = 4.0
        // 1.5 = 0x3FC00000 | 2.5 = 0x40200000 | 4.0 = 0x40800000
        executar_teste("Soma 1.5 + 2.5", 2'b00, 32'h3FC00000, 32'h40200000, 32'h40800000);

        // 7. Soma: 5.0 + 0.5 = 5.5
        // 5.0 = 0x40A00000 | 0.5 = 0x3F000000 | 5.5 = 0x40B00000
        executar_teste("Soma 5.0 + 0.5", 2'b00, 32'h40A00000, 32'h3F000000, 32'h40B00000);

        // 8. Subtração: 5.0 - 2.0 = 3.0
        // 5.0 = 0x40A00000 | 2.0 = 0x40000000 | 3.0 = 0x40400000
        executar_teste("Subtracao 5.0 - 2.0", 2'b01, 32'h40A00000, 32'h40000000, 32'h40400000);

        // 9. Subtração: 1.0 - 3.0 = -2.0
        // 1.0 = 0x3F800000 | 3.0 = 0x40400000 | -2.0 = 0xC0000000
        executar_teste("Subtracao 1.0 - 3.0", 2'b01, 32'h3F800000, 32'h40400000, 32'hC0000000);

        // 10. Soma: 2.5 + 1.3 = 3.8
        // 2.5 = 0x40200000 | 1.3 = 0x3FA66666 | 3.8 = 0x40733333
        executar_teste("Soma 2.5 + 1.3", 2'b00, 32'h40200000, 32'h3FA66666, 32'h40733333);

        // 11. Soma: 3.25 + 1.50 = 4.75
        // 3.25 = 0x40500000 | 1.50 = 0x3FC00000 | 4.75 = 0x40980000
        executar_teste("Soma 3.25 + 1.50", 2'b00, 32'h40500000, 32'h3FC00000, 32'h40980000);

        // 12. Subtração: 5.8 - 2.3 = 3.5
        // 5.8 = 0x40B9999A | 2.3 = 0x40133333 | 3.5 = 0x40600000
        executar_teste("Subtracao 5.8 - 2.3", 2'b01, 32'h40B9999A, 32'h40133333, 32'h40600000);

        // 13. Subtração: 10.0 - 2.5 = 7.5
        // 10.0 = 0x41200000 | 2.5 = 0x40200000 | 7.5 = 0x40F00000
        executar_teste("Subtracao 10.0 - 2.5", 2'b01, 32'h41200000, 32'h40200000, 32'h40F00000);

        // 14. Soma: 0.7 + 0.3 = 1.0
        executar_teste("Soma 0.7 + 0.3", 2'b00, 32'h3F333333, 32'h3E99999A, 32'h3F800000);

        // 15. Soma: 0.85 + 0.15 = 1.0 
        executar_teste("Soma 0.85 + 0.15", 2'b00, 32'h3F59999A, 32'h3E19999A, 32'h3F800000);

        // 16. Soma: 12.75 + 0.375 = 13.125
        executar_teste("Soma 12.75 + 0.375", 2'b00, 32'h414C0000, 32'h3EC00000, 32'h41520000);

        // 17. Subtração : 3.7 - 1.2 = 2.5
        executar_teste("Subtracao 3.7 - 1.2", 2'b01, 32'h406CCCCD, 32'h3F99999A, 32'h40200000);

        // 18. Subtração: 1.4 - 0.9 = 0.5
        executar_teste("Subtracao 1.4 - 0.9", 2'b01, 32'h3FB33333, 32'h3F666666, 32'h3F000000);

        // ----------------------------------------------------
        // Operações de sinais diferentes (adição e subtração)
        // ----------------------------------------------------

        // 19. Soma: 4.0 + (-4.0) = 0.0
        // 4.0 = 0x40800000 | -4.0 = 0xC0800000 | 0.0 = 0x00000000
        executar_teste("Soma 4.0 + (-4.0)", 2'b00, 32'h40800000, 32'hC0800000, 32'h00000000);

        // 20. Soma: -2.0 + -4.0 = -6.0
        // -2.0 = 0xC0000000 | -4.0 = 0xC0800000 | -6.0 = 0xC0C00000
        executar_teste("Soma -2.0 + -4.0", 2'b00, 32'hC0000000, 32'hC0800000, 32'hC0C00000);

        // 21. Subtração: -5.0 - (-2.0) = -3.0
        // -5.0 = 0xC0A00000 | -2.0 = 0xC0000000 | -3.0 = 0xC0400000
        executar_teste("Subtracao -5.0 - (-2.0)", 2'b01, 32'hC0A00000, 32'hC0000000, 32'hC0400000);

        // 22. Soma: -3.5 + 8.25 = 4.75
        // -3.5 = 0xC0600000 | 8.25 = 0x41040000 | 4.75 = 0x40980000
        executar_teste("Soma -3.5 + 8.25", 2'b00, 32'hC0600000, 32'h41040000, 32'h40980000);

        // 23. Soma: 1.5 + (-4.5) = -3.0
        // 1.5 = 0x3FC00000 | -4.5 = 0xC0900000 | -3.0 = 0xC0400000
        executar_teste("Soma 1.5 + (-4.5)", 2'b00, 32'h3FC00000, 32'hC0900000, 32'hC0400000);

        // 24. Soma: -12.5 + 12.5 = 0.0
        // -12.5 = 0xC1480000 | 12.5 = 0x41480000 | 0.0 = 0x00000000
        executar_teste("Soma -12.5 + 12.5", 2'b00, 32'hC1480000, 32'h41480000, 32'h00000000);

        // 25. Subtração: 2.5 - 6.5 = -4.0
        // 2.5 = 0x40200000 | 6.5 = 0x40D00000 | -4.0 = 0xC0800000
        executar_teste("Subtracao 2.5 - 6.5", 2'b01, 32'h40200000, 32'h40D00000, 32'hC0800000);

        // 26. Subtração: -1.75 - 0.25 = -2.0
        // -1.75 = 0xbfe00000| 0.25 = 0x3E800000 | -2.0 = 0xC0000000
        executar_teste("Subtracao -1.75 - 0.25", 2'b01, 32'hBFE00000, 32'h3E800000, 32'hC0000000);

        // 27. Subtração: 3.0 - (-5.0) = 8.0
        // 3.0 = 0x40400000 | -5.0 = 0xC0A00000 | 8.0 = 0x41000000
        executar_teste("Subtracao 3.0 - (-5.0)", 2'b01, 32'h40400000, 32'hC0A00000, 32'h41000000);

        // -------------------------------------------------------------------
        // Operações com Grande Diferença de Expoente (Alinhamento de Mantissa)
        // -------------------------------------------------------------------
        // 28. Soma: 1024.0 + 0.0009765625 = 1024.0009765625
        // Expoentes: 137 (2^10) vs 117 (2^-10) -> Diferença de 20 posições no deslocamento
        // 1024.0 = 0x44800000 | 0.0009765625 = 0x3A800000 | Resultado = 0x44800008
        executar_teste("Soma exp dif 20", 2'b00, 32'h44800000, 32'h3A800000, 32'h44800008);

        // 29. Soma: 1.0 + 2^-23 (Menor bit somável sem perda total na mantissa)
        // Expoentes: 127 vs 104 -> Diferença de 23 posições
        // 1.0 = 0x3F800000 | 2^-23 (1.1920929e-7) = 0x34800000 | Resultado = 0x3F800001
        executar_teste("Soma limite de precisao", 2'b00, 32'h3F800000, 32'h34800000, 32'h3F800001);

        // 30. Soma com absorção total: 1.0 + 2^-25 (Operando menor perde todos os bits)
        // O valor menor desce além da largura de 24 bits da mantissa + bits de guarda.
        // 1.0 = 0x3F800000 | 2^-25 = 0x33800000 | Resultado = 1.0 (0x3F800000)
        executar_teste("Soma absorcao total", 2'b00, 32'h3F800000, 32'h33800000, 32'h3F800000);

        // 31. Soma de sinais opostos com grande diferença: -2048.0 + 0.125 = -2047.875
        // Expoentes: 138 (2^11) vs 124 (2^-3) -> Diferença de 14 posições
        // -2048.0 = 0xC5000000 | 0.125 = 0x3E000000 | Resultado = 0xC4FFFC00
        executar_teste("Soma opostos grande dif", 2'b00, 32'hC5000000, 32'h3E000000, 32'hC4FFFC00);

        $display("==================================================");
        $display("          SIMULACAO FINALIZADA                    ");
        $display("==================================================");
        $finish;
    end

endmodule