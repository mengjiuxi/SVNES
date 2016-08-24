`include "config.h"
import typepkg::*;

module peripherals (
	sys_if sys,
	sysbus_if sysbus,
	// GPIO
	inout wire [`DATA_N - 1:0] io[2],
	output dataLogic iodir[2],
	// SPI
	input logic cs, miso,
	output logic mosi, sck
);

logic periphs_sel;
assign periphs_sel = (sysbus.addr & ~`PERIPH_MASK) == `PERIPH_BASE;
assign sysbus.rdy = periphs_sel ? 1'b1 : 1'bz;

logic [2 ** `PERIPH_MAP_N - 1:0] periph_sel;
demux #(.N(`PERIPH_MAP_N)) demux0 (
	.sel(sysbus.addr[`PERIPHS_N - 1:`PERIPH_N]),
	.oe(periphs_sel),
	.q(periph_sel)
);

periphbus_if pbus (
	.we(sysbus.we), .data(sysbus.data),
	.addr(sysbus.addr[`PERIPH_N - 1:0])
);

gpio gpio0 (.sel(periph_sel[0]), .io(io[0]), .iodir(iodir[0]), .*);
gpio gpio1 (.sel(periph_sel[1]), .io(io[1]), .iodir(iodir[1]), .*);

logic interrupt;
spi spi0 (.sel(periph_sel[2]), .*);

endmodule
