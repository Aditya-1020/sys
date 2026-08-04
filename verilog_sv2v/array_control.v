`timescale 1ps/1ps
`default_nettype none
module array_control (
	clk,
	rstn,
	i_enable,
	i_load_w,
	i_room,
	i_fill_done,
	o_array_done,
	o_cs_array,
	o_addr_array,
	i_array_rdata,
	o_start,
	o_b_en,
	o_b_lane,
	o_b_wdata,
	o_a_valid,
	o_ld_a,
	i_sys_done,
	o_busy,
	o_w_valid
);
	reg _sv2v_0;
	parameter integer MATRIX_SIZE = 4;
	parameter integer DATA_WIDTH = 8;
	parameter integer SRAM_ADDR_W = 6;
	parameter integer ROW_W = MATRIX_SIZE * DATA_WIDTH;
	parameter integer LANE_W = $clog2(MATRIX_SIZE);
	input wire clk;
	input wire rstn;
	input wire i_enable;
	input wire i_load_w;
	input wire i_room;
	input wire i_fill_done;
	output wire o_array_done;
	output wire o_cs_array;
	output wire [SRAM_ADDR_W - 1:0] o_addr_array;
	input wire [ROW_W - 1:0] i_array_rdata;
	output wire o_start;
	output wire o_b_en;
	output wire [LANE_W - 1:0] o_b_lane;
	output wire [ROW_W - 1:0] o_b_wdata;
	output wire o_a_valid;
	output wire [ROW_W - 1:0] o_ld_a;
	input wire i_sys_done;
	output wire o_busy;
	output wire o_w_valid;
	localparam integer JOB_WORDS = 2 * MATRIX_SIZE;
	localparam integer PTR_W = $clog2(JOB_WORDS);
	reg [1:0] current_state;
	reg [1:0] next_state;
	reg [PTR_W - 1:0] rd_ptr_r;
	reg w_valid_r;
	reg load_w_r;
	wire load_w_now = i_load_w || !w_valid_r;
	wire start_job = (((current_state == 2'd0) && i_enable) && i_fill_done) && i_room;
	function automatic signed [PTR_W - 1:0] sv2v_cast_C850C_signed;
		input reg signed [PTR_W - 1:0] inp;
		sv2v_cast_C850C_signed = inp;
	endfunction
	wire [PTR_W - 1:0] last_word = (load_w_r ? $unsigned(sv2v_cast_C850C_signed(JOB_WORDS - 1)) : $unsigned(sv2v_cast_C850C_signed(MATRIX_SIZE - 1)));
	wire fetch_last = (current_state == 2'd1) && (rd_ptr_r == last_word);
	wire job_end = (current_state == 2'd3) && i_sys_done;
	always @(posedge clk or negedge rstn)
		if (!rstn) begin
			load_w_r <= 1'b1;
			w_valid_r <= 1'b0;
		end
		else begin
			if (start_job)
				load_w_r <= load_w_now;
			if (job_end && load_w_r)
				w_valid_r <= 1'b1;
		end
	assign o_w_valid = w_valid_r;
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = current_state;
		(* full_case, parallel_case *)
		case (current_state)
			2'd0:
				if (start_job)
					next_state = 2'd1;
			2'd1:
				if (fetch_last)
					next_state = 2'd2;
			2'd2: next_state = 2'd3;
			2'd3:
				if (job_end)
					next_state = 2'd0;
		endcase
	end
	always @(posedge clk or negedge rstn)
		if (!rstn)
			current_state <= 2'd0;
		else
			current_state <= next_state;
	always @(posedge clk or negedge rstn)
		if (!rstn)
			rd_ptr_r <= 1'sb0;
		else if (current_state == 2'd1)
			rd_ptr_r <= rd_ptr_r + 1'b1;
		else
			rd_ptr_r <= 1'sb0;
	assign o_cs_array = current_state == 2'd1;
	function automatic [SRAM_ADDR_W - 1:0] sv2v_cast_63253;
		input reg [SRAM_ADDR_W - 1:0] inp;
		sv2v_cast_63253 = inp;
	endfunction
	assign o_addr_array = sv2v_cast_63253(rd_ptr_r);
	reg rd_vld_r;
	reg rd_isb_r;
	reg [LANE_W - 1:0] rd_lane_r;
	always @(posedge clk or negedge rstn)
		if (!rstn) begin
			rd_vld_r <= 1'b0;
			rd_isb_r <= 1'b0;
		end
		else begin
			rd_vld_r <= o_cs_array;
			rd_isb_r <= load_w_r && (rd_ptr_r < $unsigned(sv2v_cast_C850C_signed(MATRIX_SIZE)));
			rd_lane_r <= rd_ptr_r[LANE_W - 1:0];
		end
	assign o_b_en = rd_vld_r && rd_isb_r;
	assign o_b_lane = rd_lane_r;
	assign o_b_wdata = i_array_rdata;
	assign o_ld_a = i_array_rdata;
	assign o_a_valid = rd_vld_r && !rd_isb_r;
	assign o_start = current_state == 2'd2;
	reg release_r;
	always @(posedge clk or negedge rstn)
		if (!rstn)
			release_r <= 1'b1;
		else if (start_job)
			release_r <= 1'b0;
		else if (job_end)
			release_r <= 1'b1;
	assign o_array_done = release_r;
	assign o_busy = current_state != 2'd0;
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
