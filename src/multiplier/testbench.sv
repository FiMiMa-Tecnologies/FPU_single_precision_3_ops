module testbench;

// Params:
parameter   WIDTH = 24,
            T_WID = (WIDTH - 1),
            I_WID = (T_WID -1),
            R_WID = ((WIDTH*2)-1);

// I/Os
logic   [I_WID:0]   a_m, b_m;
logic               clk, rst;
logic   [R_WID:0]   r_mant_s;
logic               done;

/* -------------------------------------------------------------------------- */
/* SCOREBOARD                                                                  */
/* -------------------------------------------------------------------------- */

int pass = 0;
int fail = 0;


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

task mult_teste;
    integer i;
    integer j;

    begin
        for(i = 1; i < (8388608); i = i + 1)
            begin
                a_m = i;
                for(j = 1; j < (8388608); j = j + 1)
                    begin
                        b_m = j;
                        #5;
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

task div; $display("+--------------------------------------------+"); endtask

task header;
    begin
        div();
        $display("|             Multiplicação           |");
        div();
        $display("| A | B | R |");
        div();
    end
endtask

task monitor;
    begin
        $monitor("| %024b | %024b |", 
        $time, D, SL, SR, clk, rst, S, Q);
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
                        r_mant_s,
                        done,
                    );
end
endtask

task check_op;
        begin
            exp_mult = {1,{a_m * b_m}};

            assert ((exp_mult == r_mant_s)&&(done))
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

initial
    begin
        reset();
        header();

        #10;

        mult_teste();

        #10;

        //footer();

        $finish;

    end

endmodule