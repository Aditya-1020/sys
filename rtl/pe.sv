`default_nettype none
`timescale 1ps/1ps

module pe #(
	parameter integer DATA_WIDTH = 8,
	parameter integer MATRIX_SIZE = 4,
	parameter integer ACC_WIDTH = 2*DATA_WIDTH + $clog2(MATRIX_SIZE)
)(
	input wire clk,
	input wire rstn, // sync reset (datapath)
	input wire i_enable,
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
	localparam integer NROW = DATA_WIDTH + 1;

	logic en_r;
	logic signed [DATA_WIDTH-1:0] a_r, w_r;
	wire [ACC_WIDTH-1:0] a_ext = {{(ACC_WIDTH-DATA_WIDTH){a_r[DATA_WIDTH-1]}}, a_r};
	wire [ACC_WIDTH-1:0] row [0:NROW-1];

	genvar g;
	generate
		for (g = 0; g < DATA_WIDTH-1; g = g + 1) begin : gen_row
			assign row[g] = w_r[g] ? (a_ext << g) : {ACC_WIDTH{1'b0}};
		end
	endgenerate

	assign row[DATA_WIDTH-1] = w_r[DATA_WIDTH-1] ? ~(a_ext << (DATA_WIDTH-1)) : {ACC_WIDTH{1'b0}};
	assign row[NROW-1] = {{(ACC_WIDTH-1){1'b0}}, w_r[DATA_WIDTH-1]};

	logic [ACC_WIDTH-1:0] p0s_r, p0c_r, p1s_r, p1c_r, p2s_r, p2c_r;
	logic [ACC_WIDTH-1:0] q0s_r, q0c_r, q1s_r, q1c_r;
	logic [ACC_WIDTH-1:0] mult_s_r, mult_c_r;
	logic signed [ACC_WIDTH-1:0] acc_s, acc_c;

	wire [ACC_WIDTH-1:0] l0s, l0c, l1s, l1c, l2s, l2c;
	
	csa #(.WIDTH(ACC_WIDTH)) u_l0 (
		.i_a(row[0]),
		.i_b(row[1]),
		.i_c(row[2]),
		.o_sum(l0s),
		.o_carry(l0c)
	);

	csa #(.WIDTH(ACC_WIDTH)) u_l1 (
		.i_a(row[3]),
		.i_b(row[4]),
		.i_c(row[5]),
		.o_sum(l1s),
		.o_carry(l1c)
	);

	csa #(.WIDTH(ACC_WIDTH)) u_l2 (
		.i_a(row[6]),
		.i_b(row[7]),
		.i_c(row[8]),
		.o_sum(l2s),
		.o_carry(l2c)
	);

	wire [ACC_WIDTH-1:0] m0s, m0c, m1s, m1c;
	
	csa #(.WIDTH(ACC_WIDTH)) u_m0 (
		.i_a(p0s_r),
		.i_b(p0c_r),
		.i_c(p1s_r),
		.o_sum(m0s),
		.o_carry(m0c)
	);
	csa #(.WIDTH(ACC_WIDTH)) u_m1 (
		.i_a(p1c_r),
		.i_b(p2s_r),
		.i_c(p2c_r),
		.o_sum(m1s),
		.o_carry(m1c)
	);

	wire [ACC_WIDTH-1:0] n0s, n0c, mult_sum, mult_carry;
	csa #(.WIDTH(ACC_WIDTH)) u_n0 (
		.i_a(q0s_r),
		.i_b(q0c_r),
		.i_c(q1s_r),
		.o_sum(n0s),
		.o_carry(n0c)
	);
	
	csa #(.WIDTH(ACC_WIDTH)) u_n1 (
		.i_a(n0s),
		.i_b(n0c),
		.i_c(q1c_r),
		.o_sum(mult_sum),
		.o_carry(mult_carry)
	);

	// accumulate
	wire [ACC_WIDTH-1:0] a0s, a0c, acc_sum, acc_carry;
	csa #(.WIDTH(ACC_WIDTH)) u_a0 (
		.i_a(i_psum_s),
		.i_b(i_psum_c),
		.i_c(mult_s_r),
		.o_sum(a0s),
		.o_carry(a0c)
	);
	
	csa #(.WIDTH(ACC_WIDTH)) u_a1 (
		.i_a(a0s),
		.i_b(a0c),
		.i_c(mult_c_r),
		.o_sum(acc_sum),
		.o_carry(acc_carry)
		);

	always_ff @(posedge clk) begin
		if (!rstn) begin
			en_r <= 1'b0;
		end else begin
			en_r <= i_enable;
		end
	end

	always_ff @(posedge clk) begin
		if (i_enable) begin
			a_r <= i_a;
		end
		if (i_w_load) begin
			w_r <= i_b;
		end

		p0s_r <= l0s;
		p0c_r <= l0c;
		p1s_r <= l1s;
		p1c_r <= l1c;
		p2s_r <= l2s;
		p2c_r <= l2c;

		q0s_r <= m0s;
		q0c_r <= m0c;
		q1s_r <= m1s;
		q1c_r <= m1c;

		mult_s_r <= mult_sum;
		mult_c_r <= mult_carry;

		if (i_enable) begin
			acc_s <= signed'(acc_sum);
			acc_c <= signed'(acc_carry);
		end
	end

	assign o_psum_s = acc_s;
	assign o_psum_c = acc_c;
	assign o_a = a_r;
	assign o_enable = en_r;

endmodule
`default_nettype wire
