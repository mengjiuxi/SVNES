module apu_pulse #(parameter logic defect = 1'b0) (
	sys_if sys,
	sysbus_if sysbus,
	input logic apuclk, qframe, hframe,
	input logic sel, en,
	output logic act,
	output logic [3:0] out
);

// Registers

logic we;
logic [7:0] regs[4];
apu_registers r0 (.*);

// Separation of register fields

logic [1:0] duty;
assign duty = regs[0][7:6];

logic lc_halt, env_loop;
assign lc_halt = regs[0][5], env_loop = lc_halt;

logic vol_con;
assign vol_con = regs[0][4];

logic [3:0] env_vol, env_period;
assign env_vol = regs[0][3:0], env_period = env_vol;

logic swp_en;
assign swp_en = regs[1][7];

logic [2:0] swp_period;
assign swp_period = regs[1][6:4];

logic swp_neg;
assign swp_neg = regs[1][3];

logic [2:0] swp_shift;
assign swp_shift = regs[1][2:0];

logic [10:0] timer_load_reg;
assign timer_load_reg = {regs[3][2:0], regs[2]};

logic [4:0] lc_load;
assign lc_load = regs[3][7:3];

// Envelope generator

logic [3:0] env_out;
apu_envelope e0 (
	.restart_cpu(we && sysbus.addr[1:0] == 2'd3), .loop(env_loop), 
	.period(env_period), .out(env_out), .*);

// Timer

logic [10:0] timer_load, swp_out;
logic swp_apply_cpu;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		timer_load <= 11'h0;
	else if (we && sysbus.addr[1:0] == 2'd3)
		timer_load <= timer_load_reg;
	else if (swp_apply_cpu)
		timer_load <= swp_out;

logic timer_clk;
logic [10:0] timer_cnt;

apu_timer #(.N(11)) t0 (
	.clk(apuclk), .n_reset(sys.n_reset), .clkout(timer_clk),
	.reload(1'b0), .load(timer_load), .cnt(timer_cnt));

logic gate_timer;
always_ff @(posedge timer_clk, negedge sys.n_reset)
	if (~sys.n_reset)
		gate_timer <= 1'b0;
	else
		gate_timer = timer_load[10:3] != 8'h0;

// Sweep

logic swp_reload, swp_reload_clr;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		swp_reload <= 1'b0;
	else if (~en || swp_reload_clr)
		swp_reload <= 1'b0;
	else if (we && sysbus.addr[1:0] == 2'd1)
		swp_reload <= 1'b1;

always_ff @(posedge hframe, negedge sys.n_reset)
	if (~sys.n_reset)
		swp_reload_clr <= 1'b0;
	else
		swp_reload_clr <= swp_reload;

logic gate_swp, swp_ovf, swp_ovf_add, swp_apply, swp_apply_delayed;
assign {swp_ovf_add, swp_out} = timer_load + ((timer_load >> swp_shift) ^ {11{swp_neg}}) + {10'h0, ~defect & swp_neg};
assign swp_ovf = swp_neg ^ swp_ovf_add;
assign gate_swp = swp_neg | ~swp_ovf_add;

always_ff @(posedge sys.clk, negedge sys.n_reset)
	if (~sys.n_reset)
		swp_apply_delayed <= 1'b0;
	else
		swp_apply_delayed <= swp_apply;

assign swp_apply_cpu = swp_apply & ~swp_apply_delayed;

logic [2:0] swp_div_cnt;

assign swp_apply = swp_en && swp_div_cnt == 3'h0 && swp_shift != 3'h0 && ~swp_ovf;

always_ff @(posedge hframe, negedge sys.n_reset)
	if (~sys.n_reset)
		swp_div_cnt <= 3'h0;
	else begin
		if (swp_reload)
			swp_div_cnt <= swp_period;
		else if (swp_div_cnt == 3'h0) begin
			if (swp_en)
				swp_div_cnt <= swp_period;
		end else
			swp_div_cnt <= swp_div_cnt - 3'h1;
	end

// Waveform sequencer

logic seq_reset, seq_reset_clr;

always_ff @(posedge apuclk, negedge sys.n_reset)
	if (~sys.n_reset)
		seq_reset <= 1'b0;
	else if (seq_reset_clr)
		seq_reset <= 1'b0;
	else if (we && sysbus.addr[1:0] == 2'd3)
		seq_reset <= 1'b1;

always_ff @(posedge timer_clk, negedge sys.n_reset)
	if (~sys.n_reset)
		seq_reset_clr <= 1'b0;
	else
		seq_reset_clr <= seq_reset;

logic [2:0] seq_step;

always_ff @(posedge timer_clk, negedge sys.n_reset)
	if (~sys.n_reset) begin
		seq_step <= 3'h0;
	end else if (~en || seq_reset) begin
		seq_step <= 3'h0;
	end else
		seq_step <= seq_step - 3'h1;

logic gate_seq;

always_comb
	case (duty)
	0:	gate_seq = seq_step == 3'b111 ? 1'b1 : 1'b0;
	1: gate_seq = seq_step[2:1] == 2'b11 ? 1'b1 : 1'b0;
	2: gate_seq = seq_step[2] == 1'b1 ? 1'b1 : 1'b0;
	3: gate_seq = seq_step[2:1] != 2'b11 ? 1'b1 : 1'b0;
	default:	gate_seq = 1'b0;
	endcase

// Length counter

logic gate_lc;
apu_length_counter lc0 (
	.halt(lc_halt), .load_cpu(we && sysbus.addr[1:0] == 2'd3),
	.idx(lc_load), .gate(gate_lc), .*);

// Output control

logic gate;
assign gate = en & gate_lc & gate_timer & gate_seq & gate_swp;

assign out = gate ? env_out : 4'b0;

endmodule
