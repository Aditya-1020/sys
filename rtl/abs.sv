`default_nettype wire
`timescale 1ps/1ps

module abs (
    input wire signed [9:0] in,
    output wire signed [9:0] out
);
    assign out = in[9] ? -in : in;

endmodule
`default_nettype none
