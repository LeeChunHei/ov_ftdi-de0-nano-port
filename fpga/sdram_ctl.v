module sdram_ctl
#(
	parameter CLK_FREQ = 100000000,
	parameter ADDR_WIDTH = 13,
	parameter BA_WIDTH = 2,
	parameter DQM_WIDTH = 2,
	parameter DQ_WIDTH = 16,
	parameter COLUMN_ADDR_WIDTH = 9,
	parameter ROW_ADDR_WIDTH = ADDR_WIDTH,
	parameter BST_LEN = 8,	// Burst Length
	parameter CAS = 3,	// CAS latency
	parameter TRP = 3,	// tRP, Command Period (PRE to ACT), in cycle
	parameter TRC = 9,	// tRC, Command Period (REF to REF / ACT to ACT), in cycle
	parameter TMRD = 2,	// tMRD, Mode Register Set To Command Delay Time, in cycle
	parameter TRCD = 3,	// tRCD, Active Command To Read/Write Command Delay Time, in cycle
	parameter TDPL = 2,	// tDPL, Input Data To Precharge Command Delay Time, in cycle
	parameter TREF = 32,	// tREF, Refresh Cycle Time, in ms
	parameter REFCNT = 8192	// Minimum Refresh execution in each tREF period
)
(
	input		clk,
	input		rst_n,
	
	input			app_req,
	output reg	app_req_ack,
	input			app_wr,	// write = 0, read = 1
	input			[7:0]app_req_len,
	input			[31:0]app_req_addr,
	input			[DQ_WIDTH-1:0]app_wr_data,
	output reg	app_wr_next_req,
	output reg	[DQ_WIDTH-1:0]app_rd_data,
	output reg	app_rd_ready,
	
	output		io_clk,
	output		io_cs_n,
	output		io_cke,
	output		io_ras_n,
	output		io_cas_n,
	output		io_we_n,
	output reg	[DQM_WIDTH-1:0]io_dqm,
	output reg	[BA_WIDTH-1:0]io_ba,
	output reg	[ADDR_WIDTH-1:0]io_addr,
	inout			[DQ_WIDTH-1:0]io_dq
);

	reg [7:0]state;
	reg [7:0]next_state;
	reg [31:0]time_counter;
	reg [31:0]target_time_cnt;
	reg [4:0]cmd;

	reg [31:0]active_addr;
	reg [31:0]xfer_cnt;
	
	reg [DQM_WIDTH-1:0]dq_out;
	reg [DQ_WIDTH-1:0]dq;
	reg [DQ_WIDTH-1:0]dq_rd;
	
	reg [7:0]refresh_miss_cnt;
	reg [31:0]refresh_counter;
	
	reg [31:0]curr_addr;
	
	// SDRAM MODE Register BA1|BA0|A12|A11|A10|A9|A8|A7|A6|A5|A4|A3|A2|A1|A0
	localparam MODE_REGISTER	=	(CAS==2 && BST_LEN == 1) ? {5'b00000,1'b0,2'b00,3'b010,1'b0,3'b000} :
											(CAS==2 && BST_LEN == 2) ? {5'b00000,1'b0,2'b00,3'b010,1'b0,3'b001} :
											(CAS==2 && BST_LEN == 4) ? {5'b00000,1'b0,2'b00,3'b010,1'b0,3'b010} :
											(CAS==2 && BST_LEN == 8) ? {5'b00000,1'b0,2'b00,3'b010,1'b0,3'b011} :
											(CAS==3 && BST_LEN == 1) ? {5'b00000,1'b0,2'b00,3'b011,1'b0,3'b000} :
											(CAS==3 && BST_LEN == 2) ? {5'b00000,1'b0,2'b00,3'b011,1'b0,3'b001} :
											(CAS==3 && BST_LEN == 4) ? {5'b00000,1'b0,2'b00,3'b011,1'b0,3'b010} :
											(CAS==3 && BST_LEN == 8) ? {5'b00000,1'b0,2'b00,3'b011,1'b0,3'b011} :
											{5'b00000,1'b0,2'b00,3'b011,1'b0,3'b000};
	// SDRAM States
	localparam INIT				= 0;
	localparam PRECHARGE_INIT	= 1;
	localparam REFRESH_INIT_0	= 2;
	localparam REFRESH_INIT_1	= 3;
	localparam LOAD_MODE_REQ	= 4;
	localparam IDLE				= 5;
	localparam ACTIVE				= 6;
	localparam WRITE				= 7;
	localparam READ				= 8;
	localparam PRECHARGE			= 9;
	localparam REFRESH			= 10;
	localparam NOP_WAIT			= 255;
	
	// Command cke|cs_n|ras_n|cas_n|we_n
	localparam CMD_DESL	= 5'b11xxx;	// Device deselect
	localparam CMD_NOP	= 5'b10111;	// No operation
	localparam CMD_BST	= 5'b10110;	// Burst stop
	localparam CMD_READ	= 5'b10101;	// Read
	localparam CMD_WRITE	= 5'b10100;	// Write
	localparam CMD_ACT	= 5'b10011;	// Bank active
	localparam CMD_PRE	= 5'b10010;	// Precharge select bank
	localparam CMD_PALL	= 5'b10010;	// Precharge all banks
	localparam CMD_REF	= 5'b10001;	// CBR Auto-Refresh
	localparam CMD_SELF	= 5'b00001;	// Self-Refresh
	localparam CMD_MRS	= 5'b10000;	// Mode register set

	// Timing parameter
	localparam integer INIT_DELAY_CNT = 1 / (1000000.0 / CLK_FREQ);
	localparam integer REF_CNT = TREF / (1000.0 / CLK_FREQ) / REFCNT;
	
	assign io_clk = !clk;
	
	assign io_cke = cmd[4];
	assign io_cs_n = cmd[3];
	assign io_ras_n = cmd[2];
	assign io_cas_n = cmd[1];
	assign io_we_n = cmd[0];
	
//	assign curr_addr = active_addr + xfer_cnt;
	
	generate
		if (DQ_WIDTH == 8) begin
			assign io_dq = dq_out ? dq : 8'hZZ;
		end
		else if (DQ_WIDTH == 16) begin
			assign io_dq[15:8] = dq_out[1] ? dq[15:8] : 8'hZZ;
			assign io_dq[7:0] = dq_out[0] ? dq[7:0] : 8'hZZ;
		end
		else if (DQ_WIDTH == 32) begin
			assign io_dq[31:24] = dq_out[3] ? dq[31:24] : 8'hZZ;
			assign io_dq[23:16] = dq_out[2] ? dq[23:16] : 8'hZZ;
			assign io_dq[15:8] = dq_out[1] ? dq[15:8] : 8'hZZ;
			assign io_dq[7:0] = dq_out[0] ? dq[7:0] : 8'hZZ;
		end
	endgenerate
	
	initial begin
		if (DQ_WIDTH == 8) begin
			io_dqm <= 1;
		end
		else if (DQ_WIDTH == 16) begin
			io_dqm <= 2'b11;
		end
		else if (DQ_WIDTH == 32) begin
			io_dqm <= 4'b1111;
		end
	
		state = 0;
		time_counter = 0;
		dq_out = 0;
		
		refresh_miss_cnt = 0;
		refresh_counter = 0;
		
		app_req_ack = 0;
		app_wr_next_req = 0;
		app_rd_ready = 0;
	end
	
	always @(negedge clk) begin
		dq_rd <= io_dq;
	end
	
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			state <= 0;
			time_counter <= 0;
			dq_out <= 0;
			
			refresh_miss_cnt <= 0;
			refresh_counter <= 0;
			
			app_req_ack <= 0;
			app_wr_next_req <= 0;
			app_rd_ready <= 0;
		end
		else begin
			refresh_counter <= refresh_counter + 1;
			if (refresh_counter >= REF_CNT && state != IDLE) begin
				refresh_counter <= 0;
				refresh_miss_cnt <= refresh_miss_cnt + 1;
			end
			case (state)
				INIT: begin
					time_counter <= 0;
					target_time_cnt <= INIT_DELAY_CNT;
					next_state <= PRECHARGE_INIT;
					state <= NOP_WAIT;
				end
				PRECHARGE_INIT: begin
					cmd <= CMD_PALL;
					io_addr[10] <= 1;
					time_counter <= 0;
					target_time_cnt <= TRP;
					next_state <= REFRESH_INIT_0;
					state <= NOP_WAIT;
				end
				REFRESH_INIT_0: begin
					cmd <= CMD_REF;
					time_counter <= 0;
					target_time_cnt <= TRC;
					next_state <= REFRESH_INIT_1;
					state <= NOP_WAIT;
				end
				REFRESH_INIT_1: begin
					cmd <= CMD_REF;
					time_counter <= 0;
					target_time_cnt <= TRC;
					next_state <= LOAD_MODE_REQ;
					state <= NOP_WAIT;
				end
				LOAD_MODE_REQ: begin
					cmd <= CMD_MRS;
					io_ba <= MODE_REGISTER[14:13];
					io_addr <= MODE_REGISTER[12:0];
					time_counter <= 0;
					target_time_cnt <= TMRD;
					next_state <= IDLE;
					state <= NOP_WAIT;
					refresh_counter <= 0;
					refresh_miss_cnt <= 0;
				end
				IDLE: begin
					cmd <= CMD_NOP;
					if (refresh_counter >= REF_CNT) begin
						refresh_counter <= 0;
						state <= REFRESH;
					end
					else if (refresh_miss_cnt) begin
						state <= REFRESH;
					end
					else if (app_req) begin
						state <= ACTIVE;
						app_req_ack <= 1;
						active_addr <= app_req_addr;
					end
				end
				ACTIVE: begin
					app_req_ack <= 0;
					cmd <= CMD_ACT;
					io_ba <= active_addr[BA_WIDTH+ROW_ADDR_WIDTH+COLUMN_ADDR_WIDTH-1:ROW_ADDR_WIDTH+COLUMN_ADDR_WIDTH];
					io_addr <= active_addr[ROW_ADDR_WIDTH+COLUMN_ADDR_WIDTH-1:COLUMN_ADDR_WIDTH];
					xfer_cnt <= 0;
					time_counter <= 0;
					target_time_cnt <= TRCD;
					next_state <= (app_wr == 0) ? WRITE : READ;
					state <= NOP_WAIT;
				end
				WRITE: begin
					if (xfer_cnt == 0) begin
						cmd <= CMD_WRITE;
						io_addr <= active_addr[COLUMN_ADDR_WIDTH-1:0];
						io_addr[10] <= 0; // no auto precharge
					end
					else begin
						cmd <= CMD_NOP;
					end
					if (DQ_WIDTH == 8) begin
						dq_out <= 1;
						io_dqm <= 0;
					end
					else if (DQ_WIDTH == 16) begin
						dq_out <= 2'b11;
						io_dqm <= 2'b00;
					end
					else if (DQ_WIDTH == 32) begin
						dq_out <= 4'b1111;
						io_dqm <= 4'b0000;
					end
					dq <= app_wr_data;
					app_wr_next_req <= 1;
					xfer_cnt <= xfer_cnt + 32'b1;
					active_addr <= active_addr + 32'b1;
					if (xfer_cnt >= app_req_len) begin//-1
						if (DQ_WIDTH == 8) begin
							dq_out <= 0;
							io_dqm <= 1;
						end
						else if (DQ_WIDTH == 16) begin
							dq_out <= 2'b00;
							io_dqm <= 2'b11;
						end
						else if (DQ_WIDTH == 32) begin
							dq_out <= 4'b0000;
							io_dqm <= 4'b1111;
						end
						app_wr_next_req <= 0;
						time_counter <= 0;
						target_time_cnt <= TDPL;
						next_state <= PRECHARGE;
						state <= NOP_WAIT;
					end
					else begin
						if (BST_LEN == 2) begin
							if (active_addr[0] == 0) begin
								cmd <= CMD_WRITE;
								io_addr <= active_addr[COLUMN_ADDR_WIDTH-1:0];
								io_addr[10] <= 0; // no auto precharge
							end
						end
						else if (BST_LEN == 4) begin
							if (active_addr[1:0] == 2'b00) begin
								cmd <= CMD_WRITE;
								io_addr <= active_addr[COLUMN_ADDR_WIDTH-1:0];
								io_addr[10] <= 0; // no auto precharge
							end
						end
						else if (BST_LEN == 8) begin
							if (active_addr[2:0] == 3'b000) begin
								cmd <= CMD_WRITE;
								io_addr <= active_addr[COLUMN_ADDR_WIDTH-1:0];
								io_addr[10] <= 0; // no auto precharge
							end
						end
					end
				end
				READ: begin
					// TODO: Should be NOP when enough address been sent
					cmd <= CMD_READ;
					io_addr <= active_addr[ADDR_WIDTH-1:0];
					io_addr[10] <= 0; // no auto precharge
					if (DQ_WIDTH == 8) begin
						dq_out <= 0;
						io_dqm <= 0;
					end
					else if (DQ_WIDTH == 16) begin
						dq_out <= 2'b00;
						io_dqm <= 2'b00;
					end
					else if (DQ_WIDTH == 32) begin
						dq_out <= 4'b0000;
						io_dqm <= 4'b0000;
					end
					active_addr <= active_addr + 1;
					time_counter <= time_counter + 1;
					if (time_counter > CAS) begin
						app_rd_data <= dq_rd;
						app_rd_ready <= 1;
						xfer_cnt <= xfer_cnt + 1;
					end
					if (xfer_cnt >= app_req_len) begin//-1
						if (DQ_WIDTH == 8) begin
							dq_out <= 0;
							io_dqm <= 1;
						end
						else if (DQ_WIDTH == 16) begin
							dq_out <= 2'b00;
							io_dqm <= 2'b11;
						end
						else if (DQ_WIDTH == 32) begin
							dq_out <= 4'b0000;
							io_dqm <= 4'b1111;
						end
						app_rd_ready <= 0;
						cmd <= CMD_PALL;
						io_addr[10] <= 1;
						time_counter <= 0;
						target_time_cnt <= TRP;
						next_state <= IDLE;
						state <= NOP_WAIT;
					end
				end
				PRECHARGE: begin
					cmd <= CMD_PALL;
					io_addr[10] <= 1;
					time_counter <= 0;
					target_time_cnt <= TRP;
					next_state <= IDLE;
					state <= NOP_WAIT;
				end
				REFRESH: begin
					cmd <= CMD_REF;
					time_counter <= 0;
					target_time_cnt <= TRC;
					if (refresh_miss_cnt) begin
						next_state <= REFRESH;
						refresh_miss_cnt <= refresh_miss_cnt - 1;
					end
					else begin
						next_state <= IDLE;
					end
					state <= NOP_WAIT;
				end
				NOP_WAIT: begin
					cmd <= CMD_NOP;
					time_counter <= time_counter + 1;
					if (time_counter >= target_time_cnt-2) begin
						time_counter <= 0;
						state <= next_state;
						if (next_state == WRITE) begin
							app_wr_next_req <= 1;
						end
					end
				end
			endcase
		end
	end
	
endmodule