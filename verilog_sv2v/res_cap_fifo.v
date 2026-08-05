`timescale 1ps/1ps
`default_nettype none
module res_cap_fifo (
	clk,
	rstn,
	i_result_valid,
	i_result_data,
	o_room,
	rd_en,
	o_rdata,
	o_valid,
	o_level,
	o_overflow
);
	reg _sv2v_0;
	parameter integer MATRIX_SIZE = 4;
	parameter integer DATA_WIDTH = 8;
	localparam integer JOBS = 2;
	localparam integer RESULT_WIDTH = (2 * DATA_WIDTH) + $clog2(MATRIX_SIZE);
	localparam integer TOTAL_ELEMENTS = MATRIX_SIZE * MATRIX_SIZE;
	localparam integer DEPTH = JOBS * TOTAL_ELEMENTS;
	localparam integer LVL_W = $clog2(DEPTH + 1);
	input wire clk;
	input wire rstn;
	input wire [MATRIX_SIZE - 1:0] i_result_valid;
	input wire [(MATRIX_SIZE * RESULT_WIDTH) - 1:0] i_result_data;
	output wire o_room;
	input wire rd_en;
	output wire signed [RESULT_WIDTH - 1:0] o_rdata;
	output wire o_valid;
	output wire [LVL_W - 1:0] o_level;
	output wire o_overflow;
	localparam integer ROW_W = MATRIX_SIZE * RESULT_WIDTH;
	localparam integer ROWS = JOBS * MATRIX_SIZE;
	localparam integer PTR_W = $clog2(ROWS);
	localparam integer RLVL_W = $clog2(ROWS + 1);
	localparam integer COL_W = $clog2(MATRIX_SIZE);
	wire [ROW_W - 1:0] row_data;
	wire [MATRIX_SIZE - 1:0] row_valid_v;
	genvar _gv_c_1;
	generate
		for (_gv_c_1 = 0; _gv_c_1 < MATRIX_SIZE; _gv_c_1 = _gv_c_1 + 1) begin : gen_skew
			localparam c = _gv_c_1;
			localparam integer DLY = (MATRIX_SIZE - 1) - c;
			wire signed [RESULT_WIDTH - 1:0] din = $signed(i_result_data[RESULT_WIDTH * c+:RESULT_WIDTH]);
			if (DLY == 0) begin : gen_passthru
				assign row_data[RESULT_WIDTH * c+:RESULT_WIDTH] = din;
				assign row_valid_v[c] = i_result_valid[c];
			end
			else begin : gen_delay
				reg signed [RESULT_WIDTH - 1:0] d_sr [0:DLY - 1];
				reg [DLY - 1:0] v_sr;
				always @(posedge clk)
					if (!rstn)
						v_sr <= 1'sb0;
					else begin
						v_sr[0] <= i_result_valid[c];
						begin : sv2v_autoblock_1
							reg signed [31:0] k;
							for (k = 1; k < DLY; k = k + 1)
								v_sr[k] <= v_sr[k - 1];
						end
					end
				always @(posedge clk)
					if (!rstn) begin : sv2v_autoblock_2
						reg signed [31:0] k;
						for (k = 0; k < DLY; k = k + 1)
							d_sr[k] <= 1'sb0;
					end
					else begin
						d_sr[0] <= din;
						begin : sv2v_autoblock_3
							reg signed [31:0] k;
							for (k = 1; k < DLY; k = k + 1)
								d_sr[k] <= d_sr[k - 1];
						end
					end
				assign row_data[RESULT_WIDTH * c+:RESULT_WIDTH] = d_sr[DLY - 1];
				assign row_valid_v[c] = v_sr[DLY - 1];
			end
		end
	endgenerate
	wire row_valid = &row_valid_v;
	reg [ROW_W - 1:0] mem [0:ROWS - 1];
	reg [PTR_W - 1:0] wr_ptr;
	reg [RLVL_W - 1:0] level_r;
	function automatic signed [RLVL_W - 1:0] sv2v_cast_3EDEB_signed;
		input reg signed [RLVL_W - 1:0] inp;
		sv2v_cast_3EDEB_signed = inp;
	endfunction
	wire full = level_r == sv2v_cast_3EDEB_signed(ROWS);
	wire empty = level_r == {RLVL_W {1'sb0}};
	wire push = row_valid && !full;
	reg [ROW_W - 1:0] row_buf_r;
	reg row_buf_valid_r;
	reg signed [RESULT_WIDTH - 1:0] head_r;
	reg head_valid_r;
	reg [COL_W - 1:0] rd_sub;
	wire consume = head_valid_r && rd_en;
	wire stage2_needs_data = !head_valid_r || consume;
	wire stage1_has_data = row_buf_valid_r;
	wire transfer = stage2_needs_data && stage1_has_data;
	function automatic signed [COL_W - 1:0] sv2v_cast_D7C09_signed;
		input reg signed [COL_W - 1:0] inp;
		sv2v_cast_D7C09_signed = inp;
	endfunction
	wire last_element = rd_sub == sv2v_cast_D7C09_signed(MATRIX_SIZE - 1);
	wire pop_row = transfer && last_element;
	always @(posedge clk or negedge rstn)
		if (!rstn)
			row_buf_valid_r <= 1'b0;
		else if (transfer && last_element)
			row_buf_valid_r <= 1'b0;
		else if (!row_buf_valid_r && !empty)
			row_buf_valid_r <= 1'b1;
	reg [ROWS - 1:0] rd_sel_r;
	always @(posedge clk or negedge rstn)
		if (!rstn)
			rd_sel_r <= {{ROWS - 1 {1'b0}}, 1'b1};
		else if (pop_row)
			rd_sel_r <= {rd_sel_r[ROWS - 2:0], rd_sel_r[ROWS - 1]};
	reg [ROW_W - 1:0] mem_rd;
	always @(*) begin
		if (_sv2v_0)
			;
		mem_rd = 1'sb0;
		begin : sv2v_autoblock_4
			reg signed [31:0] r;
			for (r = 0; r < ROWS; r = r + 1)
				mem_rd = mem_rd | ({ROW_W {rd_sel_r[r]}} & mem[r]);
		end
	end
	always @(posedge clk)
		if (!row_buf_valid_r && !empty)
			row_buf_r <= mem_rd;
	always @(posedge clk or negedge rstn)
		if (!rstn) begin
			head_valid_r <= 1'b0;
			rd_sub <= 1'sb0;
		end
		else if (transfer) begin
			head_valid_r <= 1'b1;
			rd_sub <= (last_element ? {COL_W {1'sb0}} : rd_sub + 1'b1);
		end
		else if (consume)
			head_valid_r <= 1'b0;
	always @(posedge clk)
		if (transfer)
			head_r <= $signed(row_buf_r[RESULT_WIDTH * rd_sub+:RESULT_WIDTH]);
	always @(posedge clk or negedge rstn)
		if (!rstn)
			wr_ptr <= 1'sb0;
		else if (push)
			wr_ptr <= wr_ptr + 1'b1;
	always @(posedge clk)
		if (push)
			mem[wr_ptr] <= row_data;
	always @(posedge clk or negedge rstn)
		if (!rstn)
			level_r <= 1'sb0;
		else if (push && !pop_row)
			level_r <= level_r + 1'b1;
		else if (pop_row && !push)
			level_r <= level_r - 1'b1;
	reg overflow_r;
	always @(posedge clk or negedge rstn)
		if (!rstn)
			overflow_r <= 1'b0;
		else if (row_valid && full)
			overflow_r <= 1'b1;
	assign o_rdata = head_r;
	assign o_valid = head_valid_r;
	assign o_room = level_r <= sv2v_cast_3EDEB_signed(ROWS - MATRIX_SIZE);
	function automatic [LVL_W - 1:0] sv2v_cast_54142;
		input reg [LVL_W - 1:0] inp;
		sv2v_cast_54142 = inp;
	endfunction
	assign o_level = sv2v_cast_54142({level_r, {COL_W {1'b0}}});
	assign o_overflow = overflow_r;
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
