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
	localparam integer HALF_W = DATA_WIDTH / 2;
	localparam integer PROD_W = 2 * DATA_WIDTH;

	logic en_r;
	logic signed [DATA_WIDTH-1:0] a_r, w_r;
	logic signed [DATA_WIDTH+HALF_W:0] pp_lo_r;
	logic signed [DATA_WIDTH+HALF_W-1:0] pp_hi_r;
	logic signed [PROD_W-1:0] mult_pipe;
	logic signed [ACC_WIDTH-1:0] acc_s, acc_c;

	logic [ACC_WIDTH-1:0] csa_sum, csa_carry;
	wire signed [ACC_WIDTH-1:0] mult_ext = ACC_WIDTH'(mult_pipe);

	csa #(.WIDTH(ACC_WIDTH)) u_csa (
		.i_a    (i_psum_s),
		.i_b    (i_psum_c),
		.i_c    (mult_ext),
		.o_sum  (csa_sum),
		.o_carry(csa_carry)
	);

	// One sync-reset policy for control; datapath regs hold when disabled (no X on release).
	always_ff @(posedge clk) begin
		if (!rstn) begin
			en_r <= 1'b0;
			a_r  <= '0;
			w_r  <= '0;
			pp_lo_r   <= '0;
			pp_hi_r   <= '0;
			mult_pipe <= '0;
			acc_s <= '0;
			acc_c <= '0;
		end else begin
			en_r <= i_enable;
			if (i_enable)
				a_r <= i_a;
			if (i_w_load)
				w_r <= i_b;
			pp_lo_r <= a_r * signed'({1'b0, w_r[HALF_W-1:0]});
			pp_hi_r <= a_r * signed'(w_r[DATA_WIDTH-1:HALF_W]);
			mult_pipe <= (PROD_W'(pp_hi_r) <<< HALF_W) + PROD_W'(pp_lo_r);
			if (i_enable) begin
				acc_s <= signed'(csa_sum);
				acc_c <= signed'(csa_carry);
			end
		end
	end

	assign o_psum_s = acc_s;
	assign o_psum_c = acc_c;
	assign o_a = a_r;
	assign o_enable = en_r;

endmodule
`default_nettype wire
