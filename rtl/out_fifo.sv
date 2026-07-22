`default_nettype wire
`timescale 1ps/1ps

module out_fifo #(
	parameter integer DATA_W = 18,
	parameter integer DEPTH = 4 // fixed
)(
	input wire clk,
	input wire rstn,

	// array face
	input wire i_wr_valid,
	input wire [DATA_W-1:0] i_wr_data,
	output logic o_wr_ready,

	// spi read channel face
	output logic o_rd_valid,
	output logic [DATA_W-1:0] o_rd_data,
	input wire i_rd_ready,

	// status
	output logic [7:0] o_level,
	output logic o_empty,
	output logic o_full
);
	localparam integer PTR_W = $clog2(DEPTH);
	localparam integer LEVEL_W = $clog2(DEPTH + 1);

	// pointers carry an extra wrap bit; DEPTH must be a power of 2
	logic [PTR_W:0] wr_ptr_r, rd_ptr_r;
	logic full, empty, push, pop;

	// occupancy from pointer difference; wrap bits make full/empty exact
	wire [LEVEL_W-1:0] level = wr_ptr_r - rd_ptr_r;
	assign empty = (wr_ptr_r == rd_ptr_r);
	assign full = (wr_ptr_r == {~rd_ptr_r[PTR_W], rd_ptr_r[PTR_W-1:0]});
	assign push = i_wr_valid && !full;
	assign pop = i_rd_ready && !empty;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			wr_ptr_r <= '0;
		end else if (push) begin
			wr_ptr_r <= wr_ptr_r + 1'b1; // natural wrap, MSB toggles
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rd_ptr_r <= '0;
		end else if (pop) begin
			rd_ptr_r <= rd_ptr_r + 1'b1; // natural wrap, MSB toggles
		end
	end

	logic [DATA_W-1:0] mem_r [0:DEPTH-1];
	always_ff @(posedge clk) begin
		if (push) begin
			mem_r[wr_ptr_r[PTR_W-1:0]] <= i_wr_data;
		end
	end

	assign o_wr_ready = !full;
	assign o_rd_valid = !empty;
	assign o_rd_data = mem_r[rd_ptr_r[PTR_W-1:0]];
	assign o_empty = empty;
	assign o_full = full;
	assign o_level = {{(8-LEVEL_W){1'b0}}, level};

endmodule
`default_nettype none
