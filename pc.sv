`include "config.h"

module pc (
	sys_if sys,
	sysbus_if sysbus,
	// Read & write control
	input logic pc_addr_oe,
	input logic pc_inc,
	input logic oeh, oel,
	input logic weh, wel,
	input logic [`DATA_N - 1:0] in,
	output wire [`DATA_N - 1:0] out
);

logic [`ADDR_N - 1:0] pc;

assign sysbus.addr = pc_addr_oe ? pc : 'bz;

assign out = oeh ? pc[`ADDR_N - 1:`ADDR_N - `DATA_N] : 'bz;
assign out = oel ? pc[`DATA_N - 1:0] : 'bz;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		pc <= 'b0;
	else if (pc_inc)
		pc <= pc + 1;
	else if (weh)
		pc[`ADDR_N - 1:`ADDR_N - `DATA_N] <= in;
	else if (wel)
		pc[`DATA_N - 1:0] <= in;

endmodule