`default_nettype none
`timescale 1ps/1ps

module csa #(
	parameter integer WIDTH = 32
)(
	input  wire [WIDTH-1:0] i_a,
	input  wire [WIDTH-1:0] i_b,
	input  wire [WIDTH-1:0] i_c,
	output wire [WIDTH-1:0] o_sum,
	output wire [WIDTH-1:0] o_carry
);
	assign o_carry[0] = 1'b0;
	genvar b;
	generate
		for (b = 0; b < WIDTH; b = b + 1) begin : gen_csa
			assign o_sum[b] = i_a[b] ^ i_b[b] ^ i_c[b];
			wire carry_out;
			assign carry_out = (i_a[b] & i_b[b]) | (i_a[b] & i_c[b]) | (i_b[b] & i_c[b]);

			if (b < WIDTH-1) begin : gen_carry
				assign o_carry[b+1] = carry_out;
			end

		end
	endgenerate

endmodule
`default_nettype wire
