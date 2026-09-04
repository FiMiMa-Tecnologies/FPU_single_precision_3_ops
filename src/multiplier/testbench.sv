module testbench;

// Params:
parameter   WIDTH = 24,
            T_WID = (WIDTH - 1),
            I_WID = (T_WID -1),
            R_WID = ((WIDTH*2)-1);

// I/Os
logic       [I_WID:0]   a_m, b_m;
logic       [R_WID:0]   result;

task mult_teste;
    begin
        a_m = $urandom_range(0, 8388608);
        b_m = $urandom_range(0, 8388608);
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


initial
    begin
        mult_teste();
    end



endmodule