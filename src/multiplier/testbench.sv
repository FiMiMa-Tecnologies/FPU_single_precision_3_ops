module testbench;

// Params:
parameter   WIDTH = 24,
            T_WID = (WIDTH - 1),
            I_WID = (T_WID -1),
            R_WID = ((WIDTH*2)-1);

// I/Os
logic   [I_WID:0]   a_m, b_m;
logic               clk = 0, rst;
logic   [R_WID:0]   r_mant_s;
logic               done;

/* -------------------------------------------------------------------------- */
/* SCOREBOARD                                                                  */
/* -------------------------------------------------------------------------- */

int pass = 0;
int fail = 0;
logic [R_WID:0] exp_mult;

//int op_n = 8388608;
int op_n = 1000;

fpu_mult_24x24 dut (.*);

always #5 clk = !clk;

task reset;
    begin
        rst = 0;
        #10;
        rst = 1;
        #10;
    end
endtask

task mult_teste;
    integer i;
    integer j;
    begin
        for(i = 1; i < (op_n); i = i + 1)
            begin
                a_m = i;
                for(j = 1; j < (op_n); j = j + 1)
                    begin
                        b_m = j;
                        @(posedge clk);
                        #1;
                        check_op();
                    end
            end
    end
endtask

initial
    begin
        $dumpfile("dump.vcd");
        $dumpvars(0, dut);
        #10;
    end

task div; $display("+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"); endtask

task header;
    begin
        div();
        $display("|                                                                     Multiplicação                                                                                           |");
        div();
        $display("|           A             |           B             ||                 R_expected                       |                    R_mant_s                      ||  done || STATUS |");
    end
endtask

task pass_tk;
begin
                    $display(
                    "| %023b | %023b || %048b | %048b ||   %01b   ||  PASS  |",
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
                    "| %023b | %023b || %048b | %048b ||   %01b   ||  FAIL  |",
                        a_m,
                        b_m,
                        exp_mult,
                        dut.r_parc,
                        //r_mant_s,
                        done,
                    );
end
endtask

// Wire declarations:
logic  imp_bit = 1;
logic  [T_WID:0] r_s;
logic  [R_WID:0] r_parc;

//Signal Attach:
logic  [T_WID:0] a_m_s;
logic  [T_WID:0] b_m_s;

assign  a_m_s[23]      = imp_bit;
assign  a_m_s[22:0]    = a_m;

assign  b_m_s[23]      = imp_bit;
assign  b_m_s[22:0]    = b_m;

task check_op;
        begin
            exp_mult = (a_m_s * b_m_s);
            assert ((exp_mult == r_mant_s)&&(done==1))
                begin
                    div();
                    pass++;
                    pass_tk();
                end
            else
                begin
                    div();
                    fail++;
                    fail_tk();
                end
        end
endtask

task footer;
    begin

        div();

        $display(
            "| RESULTADO FINAL                                                                                                                                                             |"
        );

        div();

        $display(
            "| PASS  = %-05d                                                                                                                                                               |",
            pass
        );

        $display(
            "| FAIL  = %-05d                                                                                                                                                               |",
            fail
        );

        $display(
            "| TOTAL = %-05d                                                                                                                                                               |",
            pass + fail
        );

        div();


        if(fail == 0)
            $display(
                "| STATUS FINAL: PASS                                                                                                                                                          |"
            );
        else
            $display(
                "| STATUS FINAL: FAIL                                                                                                                                                          |"
            );

        div();

    end
endtask

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