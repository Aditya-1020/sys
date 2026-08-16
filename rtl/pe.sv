`default_nettype none
`timescale 1ps/1ps

module pe #(
	parameter integer DATA_WIDTH = 8,
	parameter integer MATRIX_SIZE = 4,
	parameter integer ACC_WIDTH = 2*DATA_WIDTH + $clog2(MATRIX_SIZE)
)(
	input wire clk,
	input wire rstn,
	input wire i_enable, // compute
	input wire i_w_load,
	input wire signed [DATA_WIDTH-1:0] i_a,
	input wire signed [DATA_WIDTH-1:0] i_b,
	input wire signed [ACC_WIDTH-1:0] i_psum_s,
	input wire signed [ACC_WIDTH-1:0] i_psum_c,
	output wire signed [DATA_WIDTH-1:0] o_a,
	output wire signed [ACC_WIDTH-1:0] o_psum_s,
	output wire signed [ACC_WIDTH-1:0] o_psum_c,
	output wire o_enable
);
	logic signed [DATA_WIDTH-1:0] a_r; // pass through only
	always_ff @(posedge clk) begin
		if (i_enable) begin
			a_r <= i_a;
		end
	end

	logic en_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			en_r <= 1'b0;
		end else begin
			en_r <= i_enable;
		end
	end

	// weight stationary; clear unless reloaded
	logic signed [DATA_WIDTH-1:0] w_r;
	always_ff @(posedge clk) begin
		if (i_w_load) begin
			w_r <= i_b;
		end else begin
			w_r <= w_r;
		end
	end

	// pipelined multiply
	localparam integer HALF_W = DATA_WIDTH / 2;
	localparam integer PROD_W = 2 * DATA_WIDTH;

	logic signed [DATA_WIDTH+HALF_W:0] pp_lo_r;
	logic signed [DATA_WIDTH+HALF_W-1:0] pp_hi_r;
	logic signed [PROD_W-1:0] mult_pipe;

	always_ff @(posedge clk) begin
		pp_lo_r <= a_r * signed'({1'b0, w_r[HALF_W-1:0]});
		pp_hi_r <= a_r * signed'(w_r[DATA_WIDTH-1:HALF_W]);
	end

	always_ff @(posedge clk) begin
		mult_pipe <= (PROD_W'(pp_hi_r) <<< HALF_W) + PROD_W'(pp_lo_r);
	end

	// carry same acucmulator
	logic signed [ACC_WIDTH-1:0] acc_s, acc_c;
	wire signed [ACC_WIDTH-1:0] mult_ext = ACC_WIDTH'(mult_pipe);

	logic [ACC_WIDTH-1:0] csa_sum;
	logic [ACC_WIDTH-1:0] csa_carry;
	assign csa_carry[0] = 1'b0;

	genvar b;
	generate
		for (b = 0; b < ACC_WIDTH; b = b + 1) begin : gen_cs
			assign csa_sum[b] = i_psum_s[b] ^ i_psum_c[b] ^ mult_ext[b];
			wire carry_out_b = (i_psum_s[b] & i_psum_c[b]) | (i_psum_s[b] & mult_ext[b]) | (i_psum_c[b] & mult_ext[b]);

			if (b < ACC_WIDTH-1) begin : gen_csa_carry
				assign csa_carry[b+1] = carry_out_b;
			end
		end
	endgenerate

	always_ff @(posedge clk) begin
		if (i_enable) begin
			acc_s <= signed'(csa_sum);
			acc_c <= signed'(csa_carry);
		end else begin
			acc_s <= acc_s;
			acc_c <= acc_c;
		end
	end

	assign o_psum_s = acc_s;
	assign o_psum_c = acc_c;
	assign o_a = a_r;
	assign o_enable = en_r;

endmodule
`default_nettype wire
