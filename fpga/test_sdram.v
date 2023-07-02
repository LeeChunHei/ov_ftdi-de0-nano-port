module test_sdram(
	input		CLOCK_50,
	output	DRAM_CS_N,
	output	DRAM_CKE,
	output	DRAM_RAS_N,
	output	DRAM_CAS_N,
	output	DRAM_WE_N,
	output	[1:0]DRAM_DQM,
	output	[1:0]DRAM_BA,
	output	[12:0]DRAM_ADDR,
	inout		[15:0]DRAM_DQ,
	output	DRAM_CLK,
	output wire	[2:0]leds,
	output	[1:0]sdr_den_n,
	output	[15:0]sdr_dout,
	output [31:0]app_rd_data,
	output app_rd_valid,
	output app_wr_next_req,
	output app_req_ack,
	output sdram_clk
);

	wire	[15:0]pad_sdr_din;
//	wire	[15:0]sdr_dout;
//	wire	[1:0]sdr_den_n;
//	wire	sdram_clk;
	wire sdram_pad_clk = ~sdram_clk;

	reg app_req;
	reg [25:0]app_req_addr;
	reg [8:0]app_req_len;
	reg app_req_wr_n;
//	wire app_req_ack;
	reg [31:0]app_wr_data;
	reg [3:0]app_wr_en_n;
//	wire [31:0]app_rd_data;
//	wire app_rd_valid;
	wire app_last_rd;
	wire app_last_wr;
//	wire app_wr_next_req;
	wire sdr_init_done;
	
	reg [31:0]counter;
	reg [7:0]xfer_counter;
	reg [7:0]state;
	reg [2:0]leds_reg;
	
	parameter IDLE = 8'd0;
	parameter REQ_WR = 8'd1;
	parameter WRITE = 8'd2;
	parameter REQ_RD = 8'd3;
	parameter READ = 8'd4;
	parameter STALL = 8'd5;
	
	assign DRAM_DQ[7:0] = (sdr_den_n[0] == 1'b0) ? sdr_dout[7:0] : 8'hZZ;
	assign DRAM_DQ[15:8] = (sdr_den_n[1] == 1'b0) ? sdr_dout[15:8] : 8'hZZ;
	assign pad_sdr_din = DRAM_DQ;
	assign DRAM_CLK = sdram_pad_clk;
	assign leds = leds_reg;
	
	pll pll_1(
		.areset(0),
		.inclk0(CLOCK_50),
		.c0(sdram_clk),
		.locked(rst_n));

	sdrc_core
	#(
		.SDR_DW(16),	// SDR Data Width 
		.SDR_BW(2)		// SDR Byte Width
	)
	sdram_ctl
	(
		.clk(sdram_clk),
		.pad_clk(sdram_pad_clk),
		.reset_n(rst_n),
		.sdr_width(2'b01),
		.cfg_colbits(2'b01),

		/* Request from app */
		.app_req            (app_req            ) ,// Transfer Request
		.app_req_addr       (app_req_addr       ) ,// SDRAM Address
		.app_req_len        (app_req_len        ) ,// Burst Length (in 16 bit words)
		.app_req_wrap       (1'b0               ) ,// Wrap mode request 
		.app_req_wr_n       (app_req_wr_n       ) ,// 0 => Write request, 1 => read req
		.app_req_ack        (app_req_ack        ) ,// Request has been accepted
		.cfg_req_depth      (2'b11) ,//how many req. buffer should hold

		.app_wr_data        (app_wr_data        ) ,
		.app_wr_en_n        (app_wr_en_n        ) ,
		.app_rd_data        (app_rd_data        ) ,
		.app_rd_valid       (app_rd_valid       ) ,
		.app_last_rd        (app_last_rd        ) ,
		.app_last_wr        (app_last_wr        ) ,
		.app_wr_next_req    (app_wr_next_req    ) ,
		.sdr_init_done      (sdr_init_done      ) ,
		.app_req_dma_last   (app_req            ) ,

		/* Interface to SDRAMs */
		.sdr_cs_n(DRAM_CS_N),
		.sdr_cke(DRAM_CKE),
		.sdr_ras_n(DRAM_RAS_N),
		.sdr_cas_n(DRAM_CAS_N),
		.sdr_we_n(DRAM_WE_N),
		.sdr_dqm(DRAM_DQM),
		.sdr_ba(DRAM_BA),
		.sdr_addr(DRAM_ADDR), 
		.pad_sdr_din(pad_sdr_din),
		.sdr_dout(sdr_dout),
		.sdr_den_n(sdr_den_n),

		/* Parameters */
		.cfg_sdr_en(1'b1),
		.cfg_sdr_mode_reg(13'h033),
		.cfg_sdr_tras_d(4'h6),
		.cfg_sdr_trp_d(4'h3),
		.cfg_sdr_trcd_d(4'h3),
		.cfg_sdr_cas(3'h3),
		.cfg_sdr_trcar_d(4'h9),
		.cfg_sdr_twr_d(4'h2),
		.cfg_sdr_rfsh(12'h10),
		.cfg_sdr_rfmax(3'h15)
	);

	initial begin
		counter = 10;
		app_req_addr = 'h100000;
		state = IDLE;
		leds_reg = 3'b111;
	end
	
	always @(posedge sdram_clk or negedge rst_n) begin
		if (!rst_n) begin
			counter <= 10;
			app_req_addr <= 'h100000;
			state <= IDLE;
			leds_reg <= 3'b111;
		end
		else begin
			case (state)
				IDLE: begin
					if (sdr_init_done) begin
						state <= REQ_WR;
					end
				end
				REQ_WR: begin
					leds_reg[1:0] <= 2'b10;
					app_req <= 1;
					app_wr_en_n <= 0;
					app_req_wr_n <= 0;
					app_req_len <= 5;
					if (app_req_ack) begin
						xfer_counter <= 0;
						app_wr_data <= counter;
						app_req <= 0;
						app_wr_en_n <= 0;
						state <= WRITE;
					end
				end
				WRITE: begin
					leds_reg[1:0] <= 2'b01;
					if (app_wr_next_req) begin
						xfer_counter <= xfer_counter + 1;
						app_wr_data <= counter + 1;
						counter <= counter + 1;
//						app_req_addr <= app_req_addr + 1;
					end
					if (xfer_counter >= 5) begin
						state <= REQ_RD;
//							state <= (counter > 100000) ? REQ_RD : REQ_WR;
					end
//					if (app_last_wr) begin
//						if (counter > 100000) begin
//							state <= REQ_RD;
//						end
//						else begin
//							state <= REQ_WR;
//						end
//					end
				end
				REQ_RD: begin
					leds_reg[1:0] <= 2'b00;
					app_req <= 1;
					app_req_wr_n <= 1;
					app_req_len <= 8;
					if (app_req_ack) begin
						xfer_counter <= 0;
						app_req <= 0;
						app_req_addr <= 'hx;
						app_wr_en_n <= 'hx;
						app_req_wr_n <= 'hx;
						app_req_len <= 'hx;
						state <= READ;
					end
				end
				READ: begin
					if (app_rd_valid) begin
						if (xfer_counter != app_rd_data) begin
							leds_reg[2] <= 0;
//							leds_reg <= app_rd_data[2:0];
						end
						xfer_counter <= xfer_counter + 1;
					end
					if (xfer_counter >= 5) begin
						state <= STALL;
					end
				end
				STALL: begin
					counter <= counter;
				end
			endcase
		end
	end
endmodule