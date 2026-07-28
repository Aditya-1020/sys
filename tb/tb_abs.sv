`timescale 1ps/1ps
module tb_abs;
    logic signed [9:0] in, out;

    abs dut (
        .in (in),
        .out(out)
    );


    initial begin
        in = '0;
        #100;
        in = -20;
        #1;
        $display("in=%0d, \t out=%0d", in, dut.out);
        
        $finish;
    end

endmodule
