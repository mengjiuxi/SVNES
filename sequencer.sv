`include "config.h"
import typepkg::*;

module sequencer (
	sys_if sys,
	
	// Instruction infomation
	input Opcode opcode,
	input Addressing mode,
	
	// Bus control
	output logic bus_we, dbg,
	
	// Program counter
	pc_addr_oe, pc_inc, pc_load,
	
	// Address register
	dl_addr_oe,
	
	// Instruction register
	ins_we,
	
	// ALU flags
	input logic alu_cin, alu_cout, alu_sign, alu_zero, alu_ovf,
	
	// ALU buses controls
	output alu_bus_a_t abus_a,
	output alu_bus_b_t abus_b,
	output alu_bus_o_t abus_o,
	
	// ALU function select
	output ALUFunc alu_func,
	
	// Status register
	input dataLogic p,
	output dataLogic p_mask, p_set, p_clr
);

enum int unsigned {JumpL, JumpH, Fetch, Decode, ReadH, Absolute} state, state_next;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		state <= JumpL;
	else
		state <= state_next;

logic execute;
always_comb
begin
	bus_we = 1'b0;
	pc_addr_oe = 1'b0;
	dl_addr_oe = 1'b0;
	pc_inc = 1'b0;
	pc_load = 1'b0;
	ins_we = 1'b0;
	
	abus_a.bus = 1'b1;
	abus_a.con = 1'b0;
	abus_a.acc = 1'b0;
	abus_a.x = 1'b0;
	abus_a.y = 1'b0;
	abus_a.p = 1'b0;
	abus_a.sp = 1'b0;
	abus_a.dll = 1'b0;
	abus_a.dlh = 1'b0;
	abus_a.pcl = 1'b0;
	abus_a.pch = 1'b0;
	
	abus_b.bus = 1'b1;
	abus_b.con = 1'b0;
	
	abus_o.bus = 1'b0;
	abus_o.acc = 1'b0;
	abus_o.x = 1'b0;
	abus_o.y = 1'b0;
	abus_o.sp = 1'b0;
	abus_o.dll = 1'b0;
	abus_o.dlh = 1'b0;
	abus_o.pcl = 1'b0;
	abus_o.pch = 1'b0;
	
	alu_func = ALUTXB;
	p_mask = 'h0;
	p_mask[`STATUS_R] = 1'b1;
	p_set = 'h0;
	p_clr = 'h0;
	state_next = state;
	
	dbg = state == Fetch;
	
	execute = 1'b0;
	case (state)
	Fetch: begin
		pc_addr_oe = 1'b1;
		pc_inc = 1'b1;
		ins_we = 1'b1;
		state_next = Decode;
	end
	Decode: begin
		pc_addr_oe = 1'b1;
		pc_inc = 1'b1;
		case (mode)
		Imp:	begin
			pc_inc = 1'b0;
			state_next = Fetch;
			execute = 1'b1;
		end
		Imm:	begin
			state_next = Fetch;
			execute = 1'b1;
		end
		Abs:	begin
			alu_func = ALUTXB;
			abus_b.bus = 1'b1;
			abus_o.dll = 1'b1;
			state_next = ReadH;
		end
		Rlt: begin
		end
		default:	;
		endcase
	end
	ReadH: begin
		pc_addr_oe = 1'b1;
		alu_func = ALUTXB;
		abus_b.bus = 1'b1;
		abus_o.dlh = 1'b1;
		if (opcode == JMP || opcode == JSR) begin
			pc_load = 1'b1;
			state_next = Fetch;
		end else begin
			pc_inc = 1'b1;
			state_next = Absolute;
		end
	end
	Absolute: begin
		dl_addr_oe = 1'b1;
		state_next = Fetch;
		execute = 1'b1;
	end
	JumpL: begin
		pc_addr_oe = 1'b1;
		pc_inc = 1'b1;
		alu_func = ALUTXB;
		abus_b.bus = 1'b1;
		abus_o.dll = 1'b1;
		state_next = JumpH;
	end
	JumpH: begin
		pc_addr_oe = 1'b1;
		pc_load = 1'b1;
		alu_func = ALUTXB;
		abus_b.bus = 1'b1;
		abus_o.dlh = 1'b1;
		state_next = Fetch;
	end
	endcase
	
	if (execute)
		case (opcode)
		// Arithmetic operations
		ADC:	begin
			alu_func = ALUADD;
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_b.bus = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
			p_mask[`STATUS_V] = 1'b1;
		end
		SBC:	begin
			alu_func = ALUSUB;
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_b.bus = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
			p_mask[`STATUS_V] = 1'b1;
		end
		// Compare operations
		CMP:	begin
			alu_func = ALUSUB;
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_b.bus = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
		end
		CPX:	begin
			alu_func = ALUSUB;
			abus_a.bus = 1'b0;
			abus_a.x = 1'b1;
			abus_b.bus = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
		end
		CPY:	begin
			alu_func = ALUSUB;
			abus_a.bus = 1'b0;
			abus_a.y = 1'b1;
			abus_b.bus = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
		end
		// Logical operations
		AND:	begin
			alu_func = ALUAND;
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_b.bus = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		ORA:	begin
			alu_func = ALUORA;
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_b.bus = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		EOR:	begin
			alu_func = ALUEOR;
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_b.bus = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		// Shifting operations
		ASL:	begin
			alu_func = ALUASL;
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
		end
		LSR:	begin
			alu_func = ALULSR;
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
		end
		ROL:	begin
			alu_func = ALUROL;
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
		end
		ROR:	begin
			alu_func = ALUROR;
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
			p_mask[`STATUS_C] = 1'b1;
		end
		// Increment & decrement operations
		INX:	begin
			alu_func = ALUADD;
			abus_a.bus = 1'b0;
			abus_a.x = 1'b1;
			abus_b.bus = 1'b0;
			abus_b.con = 1'b1;
			abus_o.x = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		INY:	begin
			alu_func = ALUADD;
			abus_a.bus = 1'b0;
			abus_a.y = 1'b1;
			abus_b.bus = 1'b0;
			abus_b.con = 1'b1;
			abus_o.y = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		DEX:	begin
			alu_func = ALUSUB;
			abus_a.bus = 1'b0;
			abus_a.x = 1'b1;
			abus_b.bus = 1'b0;
			abus_b.con = 1'b1;
			abus_o.x = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		DEY:	begin
			alu_func = ALUSUB;
			abus_a.bus = 1'b0;
			abus_a.y = 1'b1;
			abus_b.bus = 1'b0;
			abus_b.con = 1'b1;
			abus_o.y = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		// Memory load
		LDA:	begin
			alu_func = ALUTXB;
			abus_b.bus = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		LDX:	begin
			alu_func = ALUTXB;
			abus_b.bus = 1'b1;
			abus_o.x = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		LDY:	begin
			alu_func = ALUTXB;
			abus_b.bus = 1'b1;
			abus_o.y = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		// Memory store
		STA:	begin
			alu_func = ALUTXA;
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_o.bus = 1'b1;
			bus_we = 1'b1;
		end
		STX:	begin
			alu_func = ALUTXA;
			abus_a.bus = 1'b0;
			abus_a.x = 1'b1;
			abus_o.bus = 1'b1;
			bus_we = 1'b1;
		end
		STY:	begin
			alu_func = ALUTXA;
			abus_a.bus = 1'b0;
			abus_a.y = 1'b1;
			abus_o.bus = 1'b1;
			bus_we = 1'b1;
		end
		// Status register operations
		SEC:	p_set[`STATUS_C] = 1'b1;
		SED:	p_set[`STATUS_D] = 1'b1;
		SEI:	p_set[`STATUS_I] = 1'b1;
		CLC:	p_clr[`STATUS_C] = 1'b1;
		CLD:	p_clr[`STATUS_D] = 1'b1;
		CLI:	p_clr[`STATUS_I] = 1'b1;
		CLV:	p_clr[`STATUS_V] = 1'b1;
		// Register transfer operations
		TAX:	begin
			alu_func = ALUTXA;
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_o.x = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		TAY:	begin
			alu_func = ALUTXA;
			abus_a.bus = 1'b0;
			abus_a.acc = 1'b1;
			abus_o.y = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		TSX:	begin
			alu_func = ALUTXA;
			abus_a.bus = 1'b0;
			abus_a.sp = 1'b1;
			abus_o.x = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		TXA:	begin
			alu_func = ALUTXA;
			abus_a.bus = 1'b0;
			abus_a.x = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		TXS:	begin
			alu_func = ALUTXA;
			abus_a.bus = 1'b0;
			abus_a.x = 1'b1;
			abus_o.sp = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		TYA:	begin
			alu_func = ALUTXA;
			abus_a.bus = 1'b0;
			abus_a.y = 1'b1;
			abus_o.acc = 1'b1;
			p_mask[`STATUS_N] = 1'b1;
			p_mask[`STATUS_Z] = 1'b1;
		end
		default:	;
		endcase
end

endmodule
