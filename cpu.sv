`include "config.h"
import typepkg::*;

module cpu (
	sys_if sys,
	inout wire rdy,
	output logic we, dbg,
	output wire [`ADDR_N - 1:0] addr,
	inout wire [`DATA_N - 1:0] data
);

sysbus_if sysbus (.*);

// Instruction register
dataLogic ins;
logic ins_we;
register ins0 (.we(ins_we), .oe(1'b0), .in(sysbus.data), .out(), .data(ins), .*);

// ALU
wire [`DATA_N - 1:0] alu_in_a, alu_in_b;
dataLogic alu_out;
ALUFunc alu_func;
logic alu_cin, alu_cinclr;
logic alu_cout, alu_sign, alu_zero, alu_ovf;
alu alu0 (.*);

alu_bus_a_t abus_a;
assign alu_in_a = abus_a.con ? {`DATA_N{1'b0}} : {`DATA_N{1'bz}};

alu_bus_b_t abus_b;
assign alu_in_b = abus_b.bus ? sysbus.data : {`DATA_N{1'bz}};
assign alu_in_b = abus_b.con ? {{`DATA_N - 1{1'b0}}, 1'b1} : {`DATA_N{1'bz}};

alu_bus_o_t abus_o;
assign sysbus.data = abus_o.bus ? alu_out : {`DATA_N{1'bz}};

// Registers
dataLogic acc;
register acc0 (.we(abus_o.acc), .oe(abus_a.acc), .in(alu_out), .out(alu_in_a), .data(acc), .*);

dataLogic x;
register x0 (.we(abus_o.x), .oe(abus_a.x), .in(alu_out), .out(alu_in_a), .data(x), .*);

dataLogic y;
register y0 (.we(abus_o.y), .oe(abus_a.y), .in(alu_out), .out(alu_in_a), .data(y), .*);

// Status register
dataLogic p, p_in, p_din;
dataLogic p_mask, p_set, p_clr;
logic p_brk, p_int;
assign p_brk = 1'b0, p_int = 1'b0;
assign p_in = {alu_sign, alu_ovf, 1'b1, p_brk, 1'b0, p_int, alu_zero, alu_cout};
assign p_din = abus_o.p ? alu_out : ((~p_mask & p) | (p_mask & p_in) | p_set) & ~p_clr;
assign alu_cin = p[`STATUS_C];
register p0 (
	.we(1'b1), .oe(abus_a.p),
	.in(p_din | ({{`DATA_N - 1{1'b0}}, 1'b1} << `STATUS_R)),
	.out(alu_in_a), .data(p), .*);

// Stack pointer
dataLogic sp;
logic sp_addr_oe;
register sp0 (.we(abus_o.sp), .oe(abus_a.sp), .in(alu_out), .out(alu_in_a), .data(sp), .*);
assign sysbus.addr = sp_addr_oe ? {{`ADDR_N - `DATA_N - 1{1'b0}}, 1'b1, sp} : {`ADDR_N{1'bz}};

// Data latch registers
dataLogic dl;
register dl0 (.we(1'b1), .oe(abus_a.dl), .in(sysbus.data), .out(alu_in_a), .data(dl), .*);
assign alu_in_b = abus_b.dl ? dl : {`DATA_N{1'bz}};
logic dl_sign;
assign dl_sign = dl[`DATA_N - 1];

dataLogic adl;
register adl0 (.we(abus_o.adl), .oe(abus_a.adl), .in(alu_out), .out(alu_in_a), .data(adl), .*);

dataLogic adh, adh_in;
logic adh_bus;
assign adh_in = adh_bus ? sysbus.data : alu_out;
register adh0 (.we(abus_o.adh), .oe(abus_a.adh), .in(adh_in), .out(alu_in_a), .data(adh), .*);
logic ad_addr_oe;
assign sysbus.addr = ad_addr_oe ? {adh, adl} : {`ADDR_N{1'bz}};

// Program counter
logic pc_addr_oe;
logic pc_inc, pc_load;
pc pc0 (
	.oel(abus_a.pcl), .oeh(abus_a.pch),
	.wel(abus_o.pcl), .weh(abus_o.pch),
	.in(alu_out), .out(alu_in_a),
	.load({sysbus.data, adl}), .*);

// Instruction decoder
Opcode opcode;
Addressing mode;
idec idec0 (.pc_bytes(), .*);

// Control sequencer
sequencer seq0 (.bus_rdy(rdy), .bus_we(we), .*);

endmodule
