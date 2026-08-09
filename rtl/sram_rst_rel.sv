`default_nettype none
`timescale 1ps/1ps

(* keep_hierarchy *)
module sram_rst_rel (
	input wire clk,
	input wire rstn,
	output wire o_rstb,
	output wire o_access_en
);
	logic [1:0] rel_r;

	always_ff @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			rel_r <= 2'b00;
		end else begin
			rel_r <= {rel_r[0], 1'b1};
		end
	end

	assign o_rstb = rel_r[0];
	assign o_access_en = rel_r[1];

endmodule
`default_nettype wire
