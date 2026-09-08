module testbench;

// Params:
parameter   WIDTH = 24,
            T_WID = (WIDTH - 1),
            I_WID = (T_WID -1),
            R_WID = ((WIDTH*2)-1);

localparam  ADD = 2'b00,
            SUB = 2'b01,
            MUL = 2'b10,
            RES = 2'b11;

// I/Os
logic   [I_WID:0]   a_m, b_m;
logic   [1:0]       op;
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
int op_n = 3000;

fpu_mult_24x24 dut (.*);

always #5 clk = !clk;

task reset;
    begin
        rst = 0;
        op = ADD;
        #10;
        rst = 1;
        #10;
    end
endtask

task st_op;
    begin
        @(negedge clk);
        op = MUL;

        @(posedge clk);
        #1;

        check_op();

        @(negedge clk);
        op = ADD;

        @(posedge clk);
        #1;
    end
endtask

/*
task mult_teste;
begin
    a_m = 4;
    b_m = 2;
    st_op();
    check_op();
end
endtask
*/

task mult_teste;

    integer i;
    integer j;

    begin

        for(i = 1; i < op_n; i = i + 1)
            begin
                a_m = i;
                for(j = 1; j < op_n; j = j + 1)
                    begin
                        b_m = j;
                        st_op();
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

task div; $display("+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"); endtask

task header;
    begin
        div();
        $display("|                                                                                  Multiplicação                                                                                                 |");
        div();
        $display("| op_s | clk | rst |            A            |           B             ||                 R_expected                       |                    R_mant_s                      ||  done || STATUS |");
    end
endtask

task monitor_tk;
begin
                    $monitor(
                    "|  %02b  |  %01b  |  %01b  | %023b | %023b || %048b | %048b ||   %01b   ||",
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
            assert ((exp_mult == r_mant_s)&&(done==1)&&(op==MUL))
                begin
                    div();
                    pass++;
                    pass_tk();
                end
            else
            assert ((exp_mult == r_mant_s)&&(done==0)&&(op==MUL))
                begin
                    div();
                end
            else
            assert ((exp_mult != r_mant_s)&&(done==0)&&(op==ADD))
                begin
                    div();
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
            "| RESULTADO FINAL                                                                                                                                                                                |"
        );

        div();

        $display(
            "| PASS  = %-05d                                                                                                                                                                                  |",
            pass
        );

        $display(
            "| FAIL  = %-05d                                                                                                                                                                                  |",
            fail
        );

        $display(
            "| TOTAL = %-05d                                                                                                                                                                                  |",
            pass + fail
        );

        div();


        if(fail == 0)
            $display(
                "| STATUS FINAL: PASS                                                                                                                                                                             |"
            );
        else
            $display(
                "| STATUS FINAL: FAIL                                                                                                                                                                            |"
            );

        div();

    end
endtask

initial
    begin
        header();
        //monitor_tk();
        reset();
        #10;
        mult_teste();
        #10;
        footer();
        $finish;
    end

initial
    begin
        #10000000000000;
        $dumpfile("dump.vcd");
        $dumpvars(0, dut);
    end

endmodule