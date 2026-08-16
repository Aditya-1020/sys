`timescale 1ps/1ps

package sys_pkg;
	localparam int MATRIX_SIZE  = 4;
	localparam int DATA_WIDTH = 8;
	localparam int RES_JOBS = 2;
	localparam int SRAM_ADDR_W = 6;
	localparam int AXI_ADDR_W = 32;
	localparam int AXI_DATA_W = 32;

	localparam int ROW_W = MATRIX_SIZE * DATA_WIDTH;
	localparam int LANE_W = $clog2(MATRIX_SIZE);
	localparam int RESULT_W = (2 * DATA_WIDTH) + $clog2(MATRIX_SIZE);
	localparam int TILE_BITS = MATRIX_SIZE * MATRIX_SIZE * RESULT_W;
	localparam int LEN_W = SRAM_ADDR_W + 1;
	localparam int LEVEL_W = $clog2((RES_JOBS * MATRIX_SIZE) + 1);
	localparam int TILE_BEATS = TILE_BITS / AXI_DATA_W;
	localparam int TILE_BYTES = TILE_BEATS * 4;
	localparam int NJOB_W = 16;

	// CTRL (0x00)
	localparam int CTRL_EN = 0;
	localparam int CTRL_GO = 1;
	localparam int CTRL_LOAD_W = 2;
	localparam int CTRL_STORE = 3;
	localparam int CTRL_AUTO_ST = 4;
	localparam int CTRL_AUTO_FILL = 5;

	// STATUS (0x04)
	localparam int ST_DMA_BUSY = 0;
	localparam int ST_DMA_DONE = 1;
	localparam int ST_DMA_ERR = 2;
	localparam int ST_FILL_DONE = 3;
	localparam int ST_CTRL_BUSY = 4;
	localparam int ST_ARRAY_BUSY = 5;
	localparam int ST_ARRAY_DONE = 6;
	localparam int ST_PP_SEL = 7;
	localparam int ST_W_VALID = 8;
	localparam int ST_RES_VALID = 9;
	localparam int ST_RES_OVF = 10;
	localparam int ST_WDMA_BUSY = 11;
	localparam int ST_WDMA_DONE = 12;
	localparam int ST_WDMA_ERR = 13;
	localparam int ST_AF_BUSY = 14;
	localparam int ST_LEVEL_LSB = 16;
	localparam int ST_TILE_LSB = ST_LEVEL_LSB + LEVEL_W;

	// CSR byte offsets
	localparam logic [7:0] REG_CTRL = 8'h00;
	localparam logic [7:0] REG_STATUS = 8'h04;
	localparam logic [7:0] REG_SRC_ADDR = 8'h08;
	localparam logic [7:0] REG_LEN = 8'h0C;
	localparam logic [7:0] REG_RESULT = 8'h10;
	localparam logic [7:0] REG_DST_ADDR = 8'h14;
	localparam logic [7:0] REG_NJOBS = 8'h18;
endpackage
