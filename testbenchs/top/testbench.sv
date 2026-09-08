`timescale 1ns/1ps

module testbench;

    /* ---------------------------------------------------------------------- */
    /* CONFIGURATION                                                          */
    /* ---------------------------------------------------------------------- */

    localparam logic [1:0] ADD = 2'b00;
    localparam logic [1:0] SUB = 2'b01;
    localparam logic [1:0] MUL = 2'b10;

    localparam integer NUM_TESTS_PER_OP = 1000;
    localparam integer MAX_LATENCY      = 500;

    // Random operand exponent interval.
    // IEEE-754 single precision exponent bias = 127.
    // 96..158 corresponds approximately to unbiased exponents -31..+31.
    // This keeps all generated operands normalized and makes the result range
    // safe for ADD/SUB/MUL, avoiding intentional overflow/underflow cases.
    localparam integer EXP_MIN = 96;
    localparam integer EXP_MAX = 158;

    localparam bit VERBOSE = 1'b0;

    /* ---------------------------------------------------------------------- */
    /* DUT INTERFACE                                                          */
    /* ---------------------------------------------------------------------- */

    logic        clk;
    logic        rst_n;
    logic        start;
    logic [1:0]  op;
    logic [31:0] a;
    logic [31:0] b;

    logic [31:0] result;
    logic        done;
    logic        guard;
    logic        round;
    logic        sticky;
    logic        overflow;
    logic        underflow;

    /* ---------------------------------------------------------------------- */
    /* SCOREBOARD                                                             */
    /* ---------------------------------------------------------------------- */

    integer pass_add;
    integer fail_add;
    integer pass_sub;
    integer fail_sub;
    integer pass_mul;
    integer fail_mul;

    integer timeout_count;
    integer protocol_fail;

    integer latency_add_sum;
    integer latency_sub_sum;
    integer latency_mul_sum;
    integer latency_add_max;
    integer latency_sub_max;
    integer latency_mul_max;

    integer seed;
    integer seed_dummy;

    /* ---------------------------------------------------------------------- */
    /* DUT                                                                    */
    /* ---------------------------------------------------------------------- */

    fpu dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .op        (op),
        .a         (a),
        .b         (b),
        .result    (result),
        .done      (done),
        .guard     (guard),
        .round     (round),
        .sticky    (sticky),
        .overflow  (overflow),
        .underflow (underflow)
    );

    /* ---------------------------------------------------------------------- */
    /* CLOCK                                                                  */
    /* ---------------------------------------------------------------------- */

    initial clk = 1'b0;
    always #5 clk = ~clk;

    /* ---------------------------------------------------------------------- */
    /* RANDOM IEEE-754 OPERAND GENERATOR                                      */
    /* ---------------------------------------------------------------------- */

    function automatic logic [31:0] random_fp32_normal;
        logic        sign_rand;
        logic [7:0]  exp_rand;
        logic [22:0] mant_rand;
        integer      exp_tmp;
        begin
            sign_rand = $urandom_range(0, 1);
            exp_tmp   = $urandom_range(EXP_MIN, EXP_MAX);
            exp_rand  = exp_tmp[7:0];
            mant_rand = $urandom();

            random_fp32_normal = {sign_rand, exp_rand, mant_rand};
        end
    endfunction

    /* ---------------------------------------------------------------------- */
    /* IEEE-754 -> REAL REFERENCE CONVERSION                                  */
    /* ---------------------------------------------------------------------- */

    function automatic real fp32_to_real(input logic [31:0] bits);
        integer exp_field;
        integer frac_field;
        integer exp_unbiased;
        integer i;
        real    magnitude;
        real    scale;
        begin
            exp_field  = bits[30:23];
            frac_field = bits[22:0];

            if (exp_field == 0) begin
                // Zero/subnormal support. The random generator itself emits
                // normalized operands, but this keeps the helper generic.
                if (frac_field == 0) begin
                    fp32_to_real = 0.0;
                end
                else begin
                    magnitude = frac_field / 8388608.0; // 2^23
                    scale = 1.0;
                    for (i = 0; i < 126; i = i + 1)
                        scale = scale / 2.0;
                    magnitude = magnitude * scale;

                    if (bits[31])
                        fp32_to_real = -magnitude;
                    else
                        fp32_to_real = magnitude;
                end
            end
            else if (exp_field == 255) begin
                // NaN/Inf are intentionally not generated by this testbench.
                fp32_to_real = 0.0;
            end
            else begin
                magnitude = 1.0 + (frac_field / 8388608.0);
                exp_unbiased = exp_field - 127;
                scale = 1.0;

                if (exp_unbiased >= 0) begin
                    for (i = 0; i < exp_unbiased; i = i + 1)
                        scale = scale * 2.0;
                end
                else begin
                    for (i = 0; i < -exp_unbiased; i = i + 1)
                        scale = scale / 2.0;
                end

                magnitude = magnitude * scale;

                if (bits[31])
                    fp32_to_real = -magnitude;
                else
                    fp32_to_real = magnitude;
            end
        end
    endfunction

    /* ---------------------------------------------------------------------- */
    /* ROUND-TO-NEAREST, TIES-TO-EVEN                                         */
    /* ---------------------------------------------------------------------- */

    function automatic integer round_nearest_even(input real value);
        integer base;
        real    rem;
        begin
            // value is always non-negative in this testbench.
            base = $rtoi(value);
            rem  = value - base;

            if (rem > 0.5)
                round_nearest_even = base + 1;
            else if (rem < 0.5)
                round_nearest_even = base;
            else if (base[0])
                round_nearest_even = base + 1;
            else
                round_nearest_even = base;
        end
    endfunction

    /* ---------------------------------------------------------------------- */
    /* REAL -> IEEE-754 SINGLE PRECISION REFERENCE CONVERSION                  */
    /* ---------------------------------------------------------------------- */

    function automatic logic [31:0] real_to_fp32(input real value);
        logic        sign_bit;
        integer      exp_unbiased;
        integer      exp_field;
        integer      mantissa;
        integer      sub_mantissa;
        real         x;
        real         normalized;
        real         mant_exact;
        real         sub_scaled;
        begin
            // Exact zero. For the generated operand set, exact cancellation
            // corresponds to +0 under round-to-nearest-even.
            if (value == 0.0) begin
                real_to_fp32 = 32'h00000000;
            end
            else begin
                if (value < 0.0) begin
                    sign_bit = 1'b1;
                    x = -value;
                end
                else begin
                    sign_bit = 1'b0;
                    x = value;
                end

                // Normalize x to [1.0, 2.0).
                normalized  = x;
                exp_unbiased = 0;

                while (normalized >= 2.0) begin
                    normalized  = normalized / 2.0;
                    exp_unbiased = exp_unbiased + 1;
                end

                while (normalized < 1.0) begin
                    normalized  = normalized * 2.0;
                    exp_unbiased = exp_unbiased - 1;
                end

                exp_field = exp_unbiased + 127;

                // Overflow -> infinity.
                if (exp_field >= 255) begin
                    real_to_fp32 = {sign_bit, 8'hff, 23'h000000};
                end
                // Subnormal/underflow path. Not expected with the current
                // random exponent limits, but retained in the model.
                else if (exp_field <= 0) begin
                    // subnormal = round(x / 2^-149)
                    sub_scaled = x;
                    repeat (149)
                        sub_scaled = sub_scaled * 2.0;

                    sub_mantissa = round_nearest_even(sub_scaled);

                    if (sub_mantissa <= 0)
                        real_to_fp32 = {sign_bit, 31'h00000000};
                    else if (sub_mantissa >= 8388608)
                        // Rounded into the minimum normal value.
                        real_to_fp32 = {sign_bit, 8'h01, 23'h000000};
                    else
                        real_to_fp32 = {sign_bit, 8'h00, sub_mantissa[22:0]};
                end
                else begin
                    // Remove implicit leading 1 and quantize 23 fraction bits.
                    mant_exact = (normalized - 1.0) * 8388608.0;
                    mantissa   = round_nearest_even(mant_exact);

                    // Rounding can turn 1.111... into 10.000...
                    if (mantissa >= 8388608) begin
                        mantissa   = 0;
                        exp_field  = exp_field + 1;
                    end

                    if (exp_field >= 255)
                        real_to_fp32 = {sign_bit, 8'hff, 23'h000000};
                    else
                        real_to_fp32 = {sign_bit, exp_field[7:0], mantissa[22:0]};
                end
            end
        end
    endfunction

    /* ---------------------------------------------------------------------- */
    /* REFERENCE OPERATION                                                    */
    /* ---------------------------------------------------------------------- */

    // Exact integer reference for normalized operands in the configured range.
    // MUL exports a truncated result plus GRS, without final rounding.
    // Packed return value: {result[31:0], guard, round, sticky}.
    function automatic logic [34:0] reference_mult(
        input logic [31:0] a_bits,
        input logic [31:0] b_bits
    );
        longint unsigned product;
        integer shift, exponent;
        logic [31:0] truncated;
        logic [2:0] grs;
        begin
            product = (64'd8388608 + a_bits[22:0]) *
                      (64'd8388608 + b_bits[22:0]);
            shift = (product >= (64'd1 << 47)) ? 24 : 23;
            exponent = int'(a_bits[30:23]) + int'(b_bits[30:23]) - 127 + (shift == 24);
            truncated = (product >> shift) & 32'h007fffff;
            truncated[31] = a_bits[31] ^ b_bits[31];
            truncated[30:23] = exponent[7:0];
            grs[2] = (product >> (shift - 1)) & 1;
            grs[1] = (product >> (shift - 2)) & 1;
            grs[0] = (product % (64'd1 << (shift - 2))) != 0;
            reference_mult = {truncated, grs};
        end
    endfunction

    function automatic logic [31:0] reference_result(
        input logic [1:0]  operation,
        input logic [31:0] a_bits,
        input logic [31:0] b_bits
    );
        real a_real;
        real b_real;
        real r_real;
        begin
            a_real = fp32_to_real(a_bits);
            b_real = fp32_to_real(b_bits);

            case (operation)
                ADD: r_real = a_real + b_real;
                SUB: r_real = a_real - b_real;
                MUL: r_real = a_real * b_real;
                default: r_real = 0.0;
            endcase

            if (operation == MUL)
                reference_result = reference_mult(a_bits, b_bits) >> 3;
            else
                reference_result = real_to_fp32(r_real);
        end
    endfunction

    /* ---------------------------------------------------------------------- */
    /* START PULSE                                                            */
    /* ---------------------------------------------------------------------- */

    task automatic issue_operation(
        input logic [1:0]  operation,
        input logic [31:0] operand_a,
        input logic [31:0] operand_b
    );
        begin
            // Drive away from the active clock edge to avoid race conditions.
            @(negedge clk);
            a     = operand_a;
            b     = operand_b;
            op    = operation;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;
        end
    endtask

    /* ---------------------------------------------------------------------- */
    /* ONE RANDOM TEST CASE                                                   */
    /* ---------------------------------------------------------------------- */

    task automatic run_random_case(
        input logic [1:0] operation,
        input integer     case_id
    );
        logic [31:0] operand_a;
        logic [31:0] operand_b;
        logic [31:0] expected;
        logic [34:0] mult_reference;
        logic [2:0] expected_grs;
        integer      cycles;
        bit          case_ok;
        real         a_real_dbg;
        real         b_real_dbg;
        real         r_real_dbg;
        begin
            operand_a = random_fp32_normal();
            operand_b = random_fp32_normal();
            expected  = reference_result(operation, operand_a, operand_b);
            mult_reference = reference_mult(operand_a, operand_b);
            expected_grs = (operation == MUL) ? mult_reference[2:0] : 3'b000;

            issue_operation(operation, operand_a, operand_b);

            cycles = 0;
            while ((done !== 1'b1) && (cycles < MAX_LATENCY)) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
            end

            case_ok = 1'b1;

            if (done !== 1'b1) begin
                case_ok = 1'b0;
                timeout_count = timeout_count + 1;
                $display("[TIMEOUT] op=%b case=%0d A=%08h B=%08h after %0d cycles",
                         operation, case_id, operand_a, operand_b, MAX_LATENCY);

                // Recover the DUT so one stalled transaction does not turn all
                // subsequent random cases into secondary timeouts.
                @(negedge clk);
                start = 1'b0;
                rst_n = 1'b0;
                repeat (2) @(posedge clk);
                #1;
                rst_n = 1'b1;
                repeat (2) @(posedge clk);
            end
            else begin
                // Main arithmetic comparison.
                if (result !== expected)
                    case_ok = 1'b0;

                // Generated values/results stay inside a range where these
                // flags are expected to remain clear.
                if ((overflow !== 1'b0) || (underflow !== 1'b0))
                    case_ok = 1'b0;

                // MUL: exact discarded bits. ADD/SUB: GRS must be zero.
                if ({guard, round, sticky} !== expected_grs)
                    case_ok = 1'b0;

                if (!case_ok) begin
                    a_real_dbg = fp32_to_real(operand_a);
                    b_real_dbg = fp32_to_real(operand_b);

                    case (operation)
                        ADD: r_real_dbg = a_real_dbg + b_real_dbg;
                        SUB: r_real_dbg = a_real_dbg - b_real_dbg;
                        MUL: r_real_dbg = a_real_dbg * b_real_dbg;
                        default: r_real_dbg = 0.0;
                    endcase

                    $display("[FAIL] op=%b case=%0d latency=%0d", operation, case_id, cycles);
                    $display("       A        = %08h  (%e)", operand_a, a_real_dbg);
                    $display("       B        = %08h  (%e)", operand_b, b_real_dbg);
                    $display("       REF(real)= %e", r_real_dbg);
                    $display("       expected = %08h", expected);
                    $display("       result   = %08h", result);
                    $display("       GRS      = %b%b%b (expected %03b)", guard, round, sticky, expected_grs);
                    $display("       OV/UF    = %b/%b", overflow, underflow);
                end
                else if (VERBOSE) begin
                    $display("[PASS] op=%b case=%0d A=%08h B=%08h result=%08h latency=%0d",
                             operation, case_id, operand_a, operand_b, result, cycles);
                end
            end

            case (operation)
                ADD: begin
                    latency_add_sum = latency_add_sum + cycles;
                    if (cycles > latency_add_max)
                        latency_add_max = cycles;
                    if (case_ok)
                        pass_add = pass_add + 1;
                    else
                        fail_add = fail_add + 1;
                end

                SUB: begin
                    latency_sub_sum = latency_sub_sum + cycles;
                    if (cycles > latency_sub_max)
                        latency_sub_max = cycles;
                    if (case_ok)
                        pass_sub = pass_sub + 1;
                    else
                        fail_sub = fail_sub + 1;
                end

                MUL: begin
                    latency_mul_sum = latency_mul_sum + cycles;
                    if (cycles > latency_mul_max)
                        latency_mul_max = cycles;
                    if (case_ok)
                        pass_mul = pass_mul + 1;
                    else
                        fail_mul = fail_mul + 1;
                end
            endcase

            // Verify that done is a pulse and returns low on the following cycle.
            if (done === 1'b1) begin
                @(posedge clk);
                #1;
                if (done !== 1'b0) begin
                    protocol_fail = protocol_fail + 1;
                    $display("[PROTOCOL FAIL] done did not return low after completion. op=%b case=%0d",
                             operation, case_id);
                end
            end
        end
    endtask

    /* ---------------------------------------------------------------------- */
    /* TEST CAMPAIGNS                                                         */
    /* ---------------------------------------------------------------------- */

    task automatic run_campaign(input logic [1:0] operation);
        integer i;
        begin
            case (operation)
                ADD: $display("\n==================== 1000 RANDOM ADD TESTS ====================");
                SUB: $display("\n==================== 1000 RANDOM SUB TESTS ====================");
                MUL: $display("\n==================== 1000 RANDOM MUL TESTS ====================");
            endcase

            for (i = 1; i <= NUM_TESTS_PER_OP; i = i + 1) begin
                run_random_case(operation, i);

                if ((i % 100) == 0)
                    $display("Progress op=%b : %0d/%0d", operation, i, NUM_TESTS_PER_OP);
            end
        end
    endtask

    /* ---------------------------------------------------------------------- */
    /* MAIN                                                                   */
    /* ---------------------------------------------------------------------- */

    initial begin
        $dumpfile("fpu_tb.vcd");
        $dumpvars(0, testbench);

        pass_add = 0;
        fail_add = 0;
        pass_sub = 0;
        fail_sub = 0;
        pass_mul = 0;
        fail_mul = 0;

        timeout_count = 0;
        protocol_fail = 0;

        latency_add_sum = 0;
        latency_sub_sum = 0;
        latency_mul_sum = 0;
        latency_add_max = 0;
        latency_sub_max = 0;
        latency_mul_max = 0;

        // Fixed seed -> reproducible random regression.
        seed = 32'h5A17_2026;
        seed_dummy = $urandom(seed);

        a     = 32'h00000000;
        b     = 32'h00000000;
        op    = ADD;
        start = 1'b0;
        rst_n = 1'b0;

        repeat (4) @(posedge clk);
        #1;
        rst_n = 1'b1;

        repeat (2) @(posedge clk);

        run_campaign(ADD);
        run_campaign(SUB);
        run_campaign(MUL);

        $display("\n===============================================================");
        $display("                    FPU RANDOM TEST SUMMARY");
        $display("===============================================================");
        $display("ADD : PASS=%0d FAIL=%0d TOTAL=%0d",
                 pass_add, fail_add, pass_add + fail_add);
        $display("SUB : PASS=%0d FAIL=%0d TOTAL=%0d",
                 pass_sub, fail_sub, pass_sub + fail_sub);
        $display("MUL : PASS=%0d FAIL=%0d TOTAL=%0d",
                 pass_mul, fail_mul, pass_mul + fail_mul);
        $display("---------------------------------------------------------------");
        $display("TOTAL: PASS=%0d FAIL=%0d TESTS=%0d",
                 pass_add + pass_sub + pass_mul,
                 fail_add + fail_sub + fail_mul,
                 pass_add + fail_add + pass_sub + fail_sub + pass_mul + fail_mul);
        $display("Timeouts      : %0d", timeout_count);
        $display("Protocol fails: %0d", protocol_fail);
        $display("---------------------------------------------------------------");
        $display("Latency ADD: avg=%0f cycles  max=%0d",
                 (latency_add_sum * 1.0) / NUM_TESTS_PER_OP, latency_add_max);
        $display("Latency SUB: avg=%0f cycles  max=%0d",
                 (latency_sub_sum * 1.0) / NUM_TESTS_PER_OP, latency_sub_max);
        $display("Latency MUL: avg=%0f cycles  max=%0d",
                 (latency_mul_sum * 1.0) / NUM_TESTS_PER_OP, latency_mul_max);
        $display("===============================================================\n");

        if ((fail_add == 0) &&
            (fail_sub == 0) &&
            (fail_mul == 0) &&
            (timeout_count == 0) &&
            (protocol_fail == 0)) begin
            $display("TESTBENCH RESULT: PASS");
        end
        else begin
            $display("TESTBENCH RESULT: FAIL");
        end

        $finish;
    end

endmodule
