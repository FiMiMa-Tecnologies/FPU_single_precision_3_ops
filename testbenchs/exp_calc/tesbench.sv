`timescale 1ns/1ps;

module testbench;

parameter   EXP_WID = 8,
            E_WID   = (EXP_WID - 1);


logic [E_WID:0]     a_e, b_e;
logic [EXP_WID:0]   exp_final;
logic               underflow, overflow;
logic               rst;
logic               clk = 0;

/*
O objetivo do bloco é realizar a soma entre os expoentes de A e B
e subtrair o bias ao final.
*/

always #5 clk = !clk;

task reset;
    begin
        rst = 1;
        #5;
        rst = 0;
        #10;
        rst = 1;
        #10;
    end
endtask


fpu_exp_calc dut(.*);


/* -------------------------------------------------------------------------- */
/* SCOREBOARD                                                                  */
/* -------------------------------------------------------------------------- */

int pass = 0;
int fail = 0;

logic [EXP_WID:0] exp_expected;

logic underflow_expected;
logic overflow_expected;

localparam BIAS = 8'b10000001;


/* -------------------------------------------------------------------------- */
/* FORMATAÇÃO DOS LOGS                                                         */
/* -------------------------------------------------------------------------- */

task div;
    begin
        $display("+------+------++---------+---------++---------+---------++--------+");
    end
endtask


task header;
    begin

        div();

        $display(
            "|  Ae  |  Be  || Exp DUT | Exp REF || OV DUT  | UF DUT  || STATUS |"
        );

        div();

    end
endtask


task footer;
    begin

        div();

        $display(
            "| RESULTADO FINAL                                                 |"
        );

        div();

        $display(
            "| PASS  = %-05d                                                   |",
            pass
        );

        $display(
            "| FAIL  = %-05d                                                   |",
            fail
        );

        $display(
            "| TOTAL = %-05d                                                   |",
            pass + fail
        );

        div();

        if(fail == 0)
            $display(
                "| STATUS FINAL: PASS                                              |"
            );
        else
            $display(
                "| STATUS FINAL: FAIL                                              |"
            );

        div();

    end
endtask


task pass_tk;
begin
                    $display(
                    "| %08b | %08b || %09b | %09b ||   %01b/%01b   |   %01b/%01b   ||  PASS  |",
                        a_e,
                        b_e,
                        exp_expected,
                        exp_final,
                        overflow_expected,
                        overflow,
                        underflow_expected,
                        underflow
                    );
end
endtask


task fail_tk;
begin
                    $display(
                    "| %08b | %08b || %09b | %09b ||   %01b/%01b   |   %01b/%01b   ||  FAIL  |",
                        a_e,
                        b_e,
                        exp_expected,
                        exp_final,
                        overflow_expected,
                        overflow,
                        underflow_expected,
                        underflow
                    );
end
endtask

/* -------------------------------------------------------------------------- */
/* SCOREBOARD                                                                  */
/* -------------------------------------------------------------------------- */


/*
//1º condição:
((exp_final == (a_e + b_e + BIAS)) && (exp_final =< 254) && (overflow == 1'b0) && (underflow == 1'b0));

//2º condição:
((exp_final == (a_e + b_e + BIAS)) && (exp_final > 254) && (overflow == 1'b1) && (underflow == 1'b0));

//3º condição:
((exp_final == (a_e + b_e + BIAS)) && (exp_final < 1) && (overflow == 1'b0) && (underflow == 1'b1));

10000010 <= exp_final <= 11111111

*/


task check_op;
        begin
            exp_expected = a_e + b_e + BIAS;
            assert (((exp_expected == (a_e + b_e + BIAS)) && 
                     (exp_final <= 254) && 
                     (exp_final == exp_expected) && 
                     (overflow == 1'b0) && 
                     (underflow == 1'b0)))
                begin
                    div();
                    overflow_expected  = 1'b0;
                    underflow_expected = 1'b0;
                    pass++;
                    pass_tk();
                end
            else
            assert (((exp_expected == (a_e + b_e + BIAS)) && 
                     (exp_final > 254) && 
                     (exp_final == exp_expected) && 
                     (overflow == 1'b1) && 
                     (underflow == 1'b0)))
                begin
                    div();
                    overflow_expected  = 1'b1;
                    underflow_expected = 1'b0;
                    pass++;
                    pass_tk();
                end
            else
            assert (((exp_expected == (a_e + b_e + BIAS)) && 
                     (8'b10000010 <= exp_final) && (exp_final <= 8'b11111111) && 
                     (exp_final == exp_expected) && 
                     (overflow == 1'b0) && 
                     (underflow == 1'b1)))
                begin
                    div();
                    overflow_expected  = 1'b0;
                    underflow_expected = 1'b1;
                    pass++;
                    pass_tk();
                end
            else
                begin
                    div();
                    //verflow_expected  = 1'b0;
                    //underflow_expected = 1'b0;
                    fail++;
                    fail_tk();
                end
        end
endtask

/*
task check_op;

    begin

        exp_expected = a_e + b_e - 127;


        if(exp_final > 254)
            begin

                overflow_expected  = 1'b1;
                underflow_expected = 1'b0;

            end

        else if(exp_final < 1)
            begin

                overflow_expected  = 1'b0;
                underflow_expected = 1'b1;

            end

        else
            begin

                overflow_expected  = 1'b0;
                underflow_expected = 1'b0;

            end


        if(
            (exp_final == exp_expected) &&
            (overflow  == overflow_expected) &&
            (underflow == underflow_expected)
        )
            begin

                pass++;

                $display(
                    "| %08b | %08b || %09b | %09b ||   %01b/%01b   |   %01b/%01b   ||  PASS  |",
                    a_e,
                    b_e,
                    exp_final,
                    exp_expected,
                    overflow_expected,
                    overflow,
                    underflow_expected,
                    underflow
                );

            end

        else
            begin

                fail++;

                $display(
                    "| %08b | %08b || %09b | %09b ||   %01b/%01b   |   %01b/%01b   ||  FAIL  |",
                    a_e,
                    b_e,
                    exp_expected,
                    exp_final,
                    overflow_expected,
                    overflow,
                    underflow_expected,
                    underflow
                );

            end

    end

endtask

*/

/* -------------------------------------------------------------------------- */
/* ESTÍMULOS                                                                   */
/* -------------------------------------------------------------------------- */

task mult_teste;

    integer i;
    integer j;

    begin

        for(i = 1; i < (2**(E_WID+1)); i = i + 1)
            begin

                a_e = i;

                for(j = 1; j < (2**(E_WID+1)); j = j + 1)
                    begin

                        b_e = j;

                        @(posedge clk);
                        #1;

                        check_op();

                    end

            end

    end

endtask


/* -------------------------------------------------------------------------- */
/* SIMULAÇÃO                                                                   */
/* -------------------------------------------------------------------------- */

initial
    begin
        reset();
        header();

        #10;

        mult_teste();

        #10;

        footer();

        $finish;

    end


initial
    begin

        $dumpfile("dump.vcd");

        $dumpvars(0, dut);

    end

endmodule