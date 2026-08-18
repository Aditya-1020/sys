`default_nettype none
`timescale 1ps/1ps

module array_control #(
	parameter integer MATRIX_SIZE = 4,
	parameter integer DATA_WIDTH = 8,
	parameter integer SRAM_ADDR_W = 6,
	parameter integer LEN_W = SRAM_ADDR_W + 1,

	parameter integer ROW_W = MATRIX_SIZE*DATA_WIDTH, // 32, packed matrix row
	parameter integer LANE_W = $clog2(MATRIX_SIZE)
)(
	input wire clk,
	input wire rstn,
	input wire i_enable, // csr enable
	input wire i_load_w, // reloads stationary weights; clear=0 for reuse
	input wire [LEN_W-1:0] i_len,
	input wire i_room,

	// dma and top hs
	input wire i_fill_done, // dma filldone
	output wire o_array_done, // dma array_done

	// sram read
	output wire o_cs_array,
	output wire [SRAM_ADDR_W-1:0] o_addr_array,
	input wire [ROW_W-1:0] i_array_rdata,

	// to the systolic array
	output wire o_b_en,
	output wire [LANE_W-1:0] o_b_lane,
	output wire [ROW_W-1:0] o_b_wdata,
	output wire o_a_valid,
	output wire [ROW_W-1:0] o_ld_a,
	input wire i_array_busy,
	output wire o_reserve, // pulse issued tile

	// CSR status word
	output wire o_busy,
	output wire o_w_valid
);
	localparam integer JOB_WORDS = 2*MATRIX_SIZE;
	localparam integer PTR_W = $clog2(JOB_WORDS);

	typedef enum logic [0:0] {
		IDLE,
		FETCH
	} state_t;
	state_t current_state, next_state;

	logic [PTR_W-1:0] rd_ptr_r;
	logic [SRAM_ADDR_W-1:0] job_base_r;
	logic buf_live_r;
	logic w_valid_r, load_w_r;

	wire [PTR_W-1:0] last_word = load_w_r ? unsigned'(PTR_W'(JOB_WORDS-1)) : unsigned'(PTR_W'(MATRIX_SIZE-1));

	wire tile_done = (current_state == FETCH) && (rd_ptr_r == last_word);
	wire w_valid_next = w_valid_r || (tile_done && load_w_r);
	wire load_w_now = i_load_w || !w_valid_next;
	wire w_ok = !load_w_now || !i_array_busy;

	logic [LEN_W-1:0] len_r;
	wire [LEN_W-1:0] next_base = {1'b0, job_base_r} + LEN_W'(load_w_r ? JOB_WORDS : MATRIX_SIZE);	
	wire last_job_w = (next_base >= len_r);

	logic last_job_r;
	always_ff @(posedge clk) begin
		if (!rstn) begin
			last_job_r <= 1'b0;
		end else begin
			last_job_r <= last_job_w;
		end
	end

	wire fast_restart = tile_done && !last_job_r && i_enable && i_room && w_ok;
	wire start_job = ((current_state == IDLE) && i_enable && i_room && w_ok && (i_fill_done || buf_live_r)) || fast_restart;

	assign o_reserve = start_job;

	always_ff @(posedge clk) begin
		if (!rstn) begin
			job_base_r <= '0;
			buf_live_r <= 1'b0;
			len_r <= '0;
		end else begin
			if (start_job && (current_state == IDLE)) begin
				buf_live_r <= 1'b1;
				len_r <= i_len; // snapshot for the whole buffer
			end
			if (tile_done) begin
				if (last_job_r) begin
					job_base_r <= '0;
					buf_live_r <= 1'b0;
				end else begin
					job_base_r <= next_base[SRAM_ADDR_W-1:0];
				end
			end
		end
	end

	always_ff @(posedge clk) begin
		if (!rstn) begin
			load_w_r <= 1'b1; // post reset always load wieght
			w_valid_r <= 1'b0;
		end else begin
			if (start_job) load_w_r <= load_w_now;
			if (tile_done && load_w_r) w_valid_r <= 1'b1;
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
				if (tile_done && !fast_restart) begin
					next_state = IDLE;
				end
			end
		endcase
	end

	always_ff @(posedge clk) begin
		if (!rstn) begin
			current_state <= IDLE;
		end else begin
			current_state <= next_state;
		end
	end

	always_ff @(posedge clk) begin
		if (!rstn) begin
			rd_ptr_r <= '0;
		end else if (tile_done) begin
			rd_ptr_r <= '0;
		end else if (current_state == FETCH) begin
			rd_ptr_r <= rd_ptr_r + 1'b1;
		end else begin
			rd_ptr_r <= '0;
		end
	end

	assign o_cs_array = (current_state == FETCH);

	logic [SRAM_ADDR_W-1:0] addr_r;
	always_ff @(posedge clk) begin
		if (!rstn) begin
			addr_r <= '0;
		end else if (tile_done) begin
			addr_r <= last_job_r ? '0 : next_base[SRAM_ADDR_W-1:0];
		end else if (current_state == FETCH) begin
			addr_r <= addr_r + 1'b1;
		end else begin
			addr_r <= job_base_r;
		end
	end

	assign o_addr_array = addr_r;

	// pipelined read (c0=addr/cs, c1=dout from macro c2=valid and update out)
	logic rd_vld_d1, rd_vld_r;
	logic rd_isb_d1, rd_isb_r;
	logic [LANE_W-1:0] rd_lane_d1, rd_lane_r;

	always_ff @(posedge clk) begin
		if (!rstn) begin
			rd_vld_d1 <= 1'b0;
			rd_vld_r  <= 1'b0;
			rd_isb_d1 <= 1'b0;
			rd_isb_r  <= 1'b0;
		end else begin
			rd_vld_d1 <= o_cs_array;
			rd_vld_r  <= rd_vld_d1;
			rd_isb_d1 <= load_w_r && (rd_ptr_r < unsigned'(PTR_W'(MATRIX_SIZE)));
			rd_isb_r  <= rd_isb_d1;
		end
	end
	always_ff @(posedge clk) begin
		rd_lane_d1 <= rd_ptr_r[LANE_W-1:0];
		rd_lane_r  <= rd_lane_d1;
	end

	assign o_b_en = rd_vld_r && rd_isb_r;
	assign o_b_lane = rd_lane_r;
	assign o_b_wdata = i_array_rdata;
	assign o_ld_a = i_array_rdata;
	assign o_a_valid = rd_vld_r && !rd_isb_r;

	assign o_array_done = (current_state == IDLE) && i_enable && i_room && w_ok && !buf_live_r;
	assign o_busy = (current_state != IDLE);

endmodule
`default_nettype wire
