`default_nettype none
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
	localparam logic [PTR_W-1:0] PTR_LAST = PTR_W'(DEPTH - 1);

	logic [PTR_W-1:0] wr_ptr_r, rd_ptr_r;
	logic [LEVEL_W-1:0] level_r;
	logic full, empty, push, pop;

	assign full = (level_r == LEVEL_W'(DEPTH));
	assign empty = (level_r == '0);
	assign push = i_wr_valid && !full;
	assign pop = i_rd_ready && !empty;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			wr_ptr_r <= '0;
		end else if (push) begin
			wr_ptr_r <= (wr_ptr_r == PTR_LAST) ? '0 : wr_ptr_r + 1'b1;
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rd_ptr_r <= '0;
		end else if (pop) begin
			rd_ptr_r <= (rd_ptr_r == PTR_LAST) ? '0 : rd_ptr_r + 1'b1;
		end
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			level_r <= '0;
		end else if (push && !pop) begin
			level_r <= level_r + 1'b1;
		end else if (pop && !push) begin
			level_r <= level_r - 1'b1;
		end
	end

	logic [DATA_W-1:0] mem_r [0:DEPTH-1];
	always_ff @(posedge clk) begin
		if (push) begin
			mem_r[wr_ptr_r] <= i_wr_data;
		end
	end

	assign o_wr_ready = !full;
	assign o_rd_valid = !empty;
	assign o_rd_data = mem_r[rd_ptr_r];
	assign o_empty = empty;
	assign o_full = full;
	assign o_level = {{(8-LEVEL_W){1'b0}}, level_r};

endmodule
`default_nettype wire
