`default_nettype none
`timescale 1ps/1ps

module array_control #(
	parameter integer MATRIX_SIZE = 4,
	parameter integer DATA_WIDTH = 8,
	parameter integer SRAM_ADDR_W = 7, 
	
	parameter integer ROW_W = MATRIX_SIZE*DATA_WIDTH, // 32, packed matrix row
	parameter integer LANE_W = $clog2(MATRIX_SIZE)
)(
	input wire clk,
	input wire rstn,
	input wire i_enable, // csr enable
	input wire i_load_w, // reloads stationary weights; clear=0 for reuse
	input wire i_room,

	// dma and top hs
	input wire i_fill_done, // dma filldone
	output wire o_array_done, // dma array_done

	// sram read
	output wire o_cs_array,
	output wire [SRAM_ADDR_W-1:0] o_addr_array,
	input wire [ROW_W-1:0] i_array_rdata,

	// to the systolic array
	output wire o_start,
	output wire o_b_en,
	output wire [LANE_W-1:0] o_b_lane,
	output wire [ROW_W-1:0] o_b_wdata,
	output wire o_a_valid,
	output wire [ROW_W-1:0] o_ld_a,
	input wire i_sys_done,

	// CSR status word
	output wire o_busy,
	output wire o_w_valid
);
	localparam integer JOB_WORDS = 2*MATRIX_SIZE;
	localparam integer PTR_W = $clog2(JOB_WORDS);

	typedef enum logic [1:0] {
		IDLE,
		FETCH,
		START,
		RUN
	} state_t;
	state_t current_state, next_state;

	logic [PTR_W-1:0] rd_ptr_r;

	logic w_valid_r, load_w_r;
	wire load_w_now = i_load_w || !w_valid_r;

	wire start_job = (current_state == IDLE) && i_enable && i_fill_done && i_room;
	wire [PTR_W-1:0] last_word = load_w_r ? PTR_W'(JOB_WORDS-1) : PTR_W'(MATRIX_SIZE-1);
	wire fetch_last = (current_state == FETCH) && (rd_ptr_r == last_word);
	wire job_end = (current_state == RUN) && i_sys_done;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			load_w_r <= 1'b1; // post reset always load wieght
			w_valid_r <= 1'b0;
		end else begin
			if (start_job) load_w_r <= load_w_now;
			if (job_end && load_w_r) w_valid_r <= 1'b1;
		end
	end

	assign o_w_valid = w_valid_r;

	always_comb begin
		next_state = current_state;
		unique case (current_state)
			IDLE:  begin
				if (start_job) begin
					next_state = FETCH;
				end
			end
			FETCH: begin
				if (fetch_last) begin
					next_state = START;
				end
			end
			START: begin
				next_state = RUN;
			end
			RUN: begin
				if (job_end) begin
					next_state = IDLE;
				end
			end
		endcase
	end

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			current_state <= IDLE;
		end else begin
			current_state <= next_state;
		end
	end

	// address generate 8 continuous reads
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rd_ptr_r <= '0;
		end else if (current_state == FETCH) begin
			rd_ptr_r <= rd_ptr_r + 1'b1; // wrap after last word
		end else begin
			rd_ptr_r <= '0;
		end
	end

	assign o_cs_array = (current_state == FETCH);
	assign o_addr_array = SRAM_ADDR_W'(rd_ptr_r);

	logic rd_vld_r, rd_isb_r;
	logic [LANE_W-1:0] rd_lane_r;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rd_vld_r <= 1'b0;
			rd_isb_r <= 1'b0;
		end else begin
			rd_vld_r <= o_cs_array;
			rd_isb_r <= load_w_r && (rd_ptr_r < PTR_W'(MATRIX_SIZE));
			rd_lane_r <= rd_ptr_r[LANE_W-1:0];
		end
	end

	assign o_b_en = rd_vld_r && rd_isb_r;
	assign o_b_lane = rd_lane_r;
	assign o_b_wdata = i_array_rdata;
	assign o_a_valid = rd_vld_r && !rd_isb_r;
	assign o_ld_a = i_array_rdata;
	assign o_start = (current_state == START);

	
	// release buffer
	logic release_r;
	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			release_r <= 1'b1;
		end else if (start_job) begin
			release_r <= 1'b0; // swap cycle
		end else if (job_end) begin
			release_r <= 1'b1; // allow dma swap
		end
	end

	assign o_array_done = release_r;
	assign o_busy = (current_state != IDLE);

endmodule
`default_nettype wire
