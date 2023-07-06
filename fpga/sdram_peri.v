module sdram_peri
(
	input		clk,
	input		rst_n,
	
	output io_cs_n,
	output io_cke,
	output io_ras_n,
	output io_cas_n,
	output io_we_n,
	output [1:0]io_dqm,
	output [1:0]io_ba,
	output [12:0]io_addr,
	inout [15:0]io_dq,
	output io_clk,
	
	input		[13:0]adr,
	input		we,
	input		[7:0]dat_w,
	output reg	[7:0]dat_r
);

	reg app_req;
	reg [31:0]app_req_addr;
	reg [7:0]app_req_len;
	reg app_req_wr_n;
	wire app_req_ack;
	reg [15:0]app_wr_data;
	reg [3:0]app_wr_en_n;
	wire [15:0]app_rd_data;
	wire app_rd_valid;
	wire app_last_rd;
	wire app_last_wr;
	wire app_wr_next_req;
	wire sdr_init_done;
 
	reg [31:0]data[31:0];
	
	reg [7:0]state;
	reg [7:0]xfer_counter;
	reg [7:0]req_len;
	reg [31:0]req_addr;
	
	parameter ADDR = 1;
	parameter IDLE = 8'd0;
	parameter REQ_WR = 8'd1;
	parameter WR = 8'd2;
	parameter REQ_RD = 8'd3;
	parameter RD = 8'd4;
	parameter WR1 = 8'd5;
	parameter RD1 = 8'd6;
	
	sdram_ctl
	#(
		.CLK_FREQ(100000000),
		.ADDR_WIDTH(13),
		.BA_WIDTH(2),
		.DQM_WIDTH(2),
		.DQ_WIDTH(16),
		.BST_LEN(8),	// Burst Length
		.CAS(3),			// CAS latency
		.TRP(3),			// tRP, Command Period (PRE to ACT), in cycle
		.TRC(9),			// tRC, Command Period (REF to REF / ACT to ACT), in cycle
		.TMRD(2),		// tMRD, Mode Register Set To Command Delay Time, in cycle
		.TRCD(3),		// tRCD, Active Command To Read/Write Command Delay Time, in cycle
		.TREF(32),		// tREF, Refresh Cycle Time, in ms
		.REFCNT(8192)	// Minimum Refresh execution in each tREF period
	)
	ram
	(
		.clk(clk),
		.rst_n(rst_n),
			
		.app_req(app_req),
		.app_req_ack(app_req_ack),
		.app_wr(app_req_wr_n),	// write = 0, read = 1
		.app_req_len(app_req_len),
		.app_req_addr(app_req_addr),
		.app_wr_data(app_wr_data),
		.app_wr_next_req(app_wr_next_req),
		.app_rd_data(app_rd_data),
		.app_rd_ready(app_rd_valid),
			
		.io_clk(io_clk),
		.io_cs_n(io_cs_n),
		.io_cke(io_cke),
		.io_ras_n(io_ras_n),
		.io_cas_n(io_cas_n),
		.io_we_n(io_we_n),
		.io_dqm(io_dqm),
		.io_ba(io_ba),
		.io_addr(io_addr),
		.io_dq(io_dq)
	); 
	
	initial begin
		data[0] = 0;
		data[1] = 0;
		data[2] = 0;
		data[3] = 0;
		data[4] = 0;
		data[5] = 0;
		data[6] = 0;
		data[7] = 0;
		dat_r = 8'bzzzzzzzz;
		state = IDLE;
	end
		
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			data[0] <= 0;
			data[1] <= 0;
			data[2] <= 0;
			data[3] <= 0;
			data[4] <= 0;
			data[5] <= 0;
			data[6] <= 0;
			data[7] <= 0;
			dat_r <= 8'bzzzzzzzz;
			state <= IDLE;
		end
		else begin
			if (adr[13:9] == ADDR) begin
				if (we) begin
					dat_r <= 8'bzzzzzzzz;
					case (adr[8:0])
						9'd0: begin
							state <= dat_w;
						end
						9'd1: begin
							req_addr[7:0] <= dat_w;
						end
						9'd2: begin
							req_addr[15:8] <= dat_w;
						end
						9'd3: begin
							req_addr[23:16] <= dat_w;
						end
						9'd4: begin
							req_addr[31:24] <= dat_w;
						end
						9'd5: begin
							data[xfer_counter][7:0] <= dat_w;
						end
						9'd6: begin
							data[xfer_counter][15:8] <= dat_w;
						end
						9'd7: begin
							data[xfer_counter][23:16] <= dat_w;
						end
						9'd8: begin
							data[xfer_counter][31:24] <= dat_w;
						end
						9'd9: begin
							xfer_counter <= dat_w;
						end
						9'd10: begin
							req_len <= dat_w;
						end
						9'd11: begin
							xfer_counter <= 0;
							if (!dat_w) begin
								app_wr_en_n <= 0;
								app_req_wr_n <= 0;
								app_req_len <= req_len;
								app_req_addr <= req_addr;
								app_wr_data <= data[0];
								state <= REQ_WR;
							end
							else begin
								app_req_wr_n <= 1;
								app_req_addr <= req_addr;
								app_req_len <= req_len;
								state <= REQ_RD;
							end
						end
					endcase
				end
				else begin
					case (adr[8:0])
						9'd0: begin
							dat_r <= state;
						end
						9'd1: begin
							dat_r <= req_addr[7:0];
						end
						9'd2: begin
							dat_r <= req_addr[15:8];
						end
						9'd3: begin
							dat_r <= req_addr[23:16];
						end
						9'd4: begin
							dat_r <= req_addr[31:24];
						end
						9'd5: begin
							dat_r <= data[xfer_counter][7:0];
						end
						9'd6: begin
							dat_r <= data[xfer_counter][15:8];
						end
						9'd7: begin
							dat_r <= data[xfer_counter][23:16];
						end
						9'd8: begin
							dat_r <= data[xfer_counter][31:24];
						end
						9'd9: begin
							dat_r <= xfer_counter;
						end
						9'd10: begin
							dat_r <= req_len;
						end
					endcase
				end
				case (state)
					IDLE: begin
						app_req <= 0;
						app_wr_en_n <= 0;
					end
					REQ_WR: begin
						app_req <= 1;
//						app_wr_en_n <= 0;
//						app_req_wr_n <= 0;
//						app_req_len <= req_len;
//						app_req_addr <= req_addr;
//						app_wr_data <= data[xfer_counter];
						if (app_req_ack) begin
							app_wr_data <= data[xfer_counter];
							app_req <= 0;
							app_wr_en_n <= 0;
							state <= WR;
						end
					end
					WR: begin
						if (app_wr_next_req) begin
							xfer_counter <= xfer_counter + 1;
							app_wr_data <= data[xfer_counter + 1];
						end
						if (xfer_counter >= req_len) begin
							state <= IDLE;
						end
					end
					REQ_RD: begin
						app_req <= 1;
//						app_req_wr_n <= 1;
//						app_req_addr <= req_addr;
//						app_req_len <= req_len;
						if (app_req_ack) begin
							app_req <= 0;
							state <= RD;
						end
					end
					RD: begin
						if (app_rd_valid) begin
//							state <= RD1;
							data[xfer_counter] <= app_rd_data;
							xfer_counter <= xfer_counter + 1;
						end
						if (xfer_counter >= req_len) begin
							state <= IDLE;
						end
					end
					RD1: begin
						data[xfer_counter] <= app_rd_data;
						xfer_counter <= xfer_counter + 1;
						state <= RD;
					end
				endcase
			end
		end
	end

//	wire	[15:0]pad_sdr_din;
//	wire	[15:0]sdr_dout;
//	wire	[1:0]sdr_den_n;
//
//	wire app_req;
//	wire [25:0]app_req_addr;
//	wire [8:0]app_req_len;
//	wire app_req_wr_n;
//	wire app_req_ack;
//	wire [31:0]app_wr_data;
//	reg [3:0]app_wr_en_n;
//	wire [31:0]app_rd_data;
//	wire app_rd_valid;
//	wire app_last_rd;
//	wire app_last_wr;
//	wire app_wr_next_req;
//	wire sdr_init_done;
// 
// 	reg cmd_fifo_winc;
//	reg [26+9+1-1:0]cmd_fifo_data;
//   wire cmd_fifo_wfull;
//	wire cmd_fifo_rempty;
// 
//	reg write_fifo_winc;
//	reg [31:0]write_fifo_wdata;
//	wire write_fifo_wfull;
//   wire write_fifo_rempty;
// 
//	wire read_fifo_wfull;
//	wire read_fifo_rinc;
//	wire [31:0]read_fifo_rdata;
//	wire read_fifo_rempty;
// 
//	reg [31:0]data[31:0];
//	
//	reg [7:0]state;
//	reg [7:0]xfer_counter;
//	reg [7:0]req_len;
//	reg [25:0]req_addr;
//	
//	parameter ADDR = 1;
//	parameter IDLE = 8'd0;
//	parameter REQ_WR = 8'd1;
//	parameter WR = 8'd2;
//	parameter REQ_RD = 8'd3;
//	parameter RD = 8'd4;
//	parameter WR1 = 8'd5;
//	parameter RD1 = 8'd6;
//	
//	assign app_req = !cmd_fifo_rempty;
//	assign read_fifo_rinc = !read_fifo_rempty;
//	
//	assign io_dq[7:0] = (sdr_den_n[0] == 1'b0) ? sdr_dout[7:0] : 8'hZZ;
//	assign io_dq[15:8] = (sdr_den_n[1] == 1'b0) ? sdr_dout[15:8] : 8'hZZ;
//	assign pad_sdr_din = io_dq;
//	assign io_clk = ~clk;
//	
//	
//	async_fifo 
//	#(
//        .DSIZE(26+9+1),
//        .ASIZE(4),
//        .FALLTHROUGH("TRUE")
//   )
//	command_fifo
//	(
//		.wclk(clk),
//      .wrst_n(rst_n),
//      .winc(cmd_fifo_winc),
//      .wdata(cmd_fifo_data),
//      .wfull(cmd_fifo_wfull),
//      .awfull(),
//      .rclk(clk),
//      .rrst_n(rst_n),
//      .rinc(app_req_ack),
//      .rdata({app_req_len,app_req_wr_n,app_req_addr}),
//      .rempty(cmd_fifo_rempty),
//      .arempty()
//	);
//	
////	async_fifo_1 #(.W(26+9+1),.DP(4),.WR_FAST(1'b0), .RD_FAST(1'b0)) u_cmdfifo (
////		.wr_clk             (clk),
////		.wr_reset_n         (rst_n),
////		.wr_en              (cmd_fifo_winc),
////		.wr_data            (cmd_fifo_data),
////		.afull              (                   ),
////		.full               (cmd_fifo_wfull),
////		.rd_clk             (clk          ),
////		.rd_reset_n         (rst_n       ),
////		.aempty             (                   ),
////		.empty              (cmd_fifo_rempty),
////		.rd_en              (app_req_ack),
////		.rd_data            ({app_req_len,app_req_wr_n,app_req_addr})
////	);
//
//	async_fifo 
//	#(
//        .DSIZE(32),
//        .ASIZE(6),
//        .FALLTHROUGH("TRUE")
//   )
//	write_fifo
//	(
//		.wclk(clk),
//      .wrst_n(rst_n),
//      .winc(write_fifo_winc),
//      .wdata(write_fifo_wdata),
//      .wfull(write_fifo_wfull),
//      .awfull(),
//      .rclk(clk),
//      .rrst_n(rst_n),
//      .rinc(app_wr_next_req),
//      .rdata(app_wr_data),
//      .rempty(write_fifo_rempty),
//      .arempty()
//	);
//
////    async_fifo_1 #(.W(32), .DP(8), .WR_FAST(1'b0), .RD_FAST(1'b1)) u_wrdatafifo (
////          .wr_clk             (clk),
////          .wr_reset_n         (rst_n),
////          .wr_en              (write_fifo_winc),
////          .wr_data            (write_fifo_wdata),
////          .afull              (                   ),
////          .full               (write_fifo_wfull),
////          .rd_clk             (clk),
////          .rd_reset_n         (rst_n),
////          .aempty             (                   ),
////          .empty              (write_fifo_rempty),
////          .rd_en              (app_wr_next_req),
////          .rd_data            (app_wr_data)
////     );
//
//	async_fifo 
//	#(
//        .DSIZE(32),
//        .ASIZE(6),
//        .FALLTHROUGH("TRUE")
//   )
//	read_fifo
//	(
//		.wclk(clk),
//      .wrst_n(rst_n),
//      .winc(app_rd_valid),
//      .wdata(app_rd_data),
//      .wfull(read_fifo_wfull),
//      .awfull(),
//      .rclk(clk),
//      .rrst_n(rst_n),
//      .rinc(read_fifo_rinc),
//      .rdata(read_fifo_rdata),
//      .rempty(read_fifo_rempty),
//      .arempty()
//	);
//	
////	async_fifo_1 #(.W(32), .DP(4), .WR_FAST(1'b0), .RD_FAST(1'b1) ) u_rddatafifo (
////		.wr_clk             (clk),
////		.wr_reset_n         (rst_n),
////		.wr_en              (app_rd_valid),
////		.wr_data            (app_rd_data),
////		.afull              (                   ),
////		.full               (read_fifo_wfull),
////		.rd_clk             (clk),
////		.rd_reset_n         (rst_n),
////		.empty              (read_fifo_rempty),
////		.aempty             (                   ),
////		.rd_en              (read_fifo_rinc),
////		.rd_data            (read_fifo_rdata)
////	);
//
//	sdrc_core
//	#(
//		.SDR_DW(16),	// SDR Data Width 
//		.SDR_BW(2)		// SDR Byte Width
//	)
//	ram
//	(
//		.clk(clk),
//		.pad_clk(io_clk),
//		.reset_n(rst_n),
//		.sdr_width(2'b01),
//		.cfg_colbits(2'b01),
//
//		/* Request from app */
//		.app_req            (app_req            ) ,// Transfer Request
//		.app_req_addr       (app_req_addr       ) ,// SDRAM Address
//		.app_req_len        (app_req_len        ) ,// Burst Length (in 16 bit words)
//		.app_req_wrap       (1'b0               ) ,// Wrap mode request 
//		.app_req_wr_n       (app_req_wr_n       ) ,// 0 => Write request, 1 => read req
//		.app_req_ack        (app_req_ack        ) ,// Request has been accepted
//		.cfg_req_depth      (2'b01) ,//how many req. buffer should hold
//
//		.app_wr_data        (app_wr_data        ) ,
//		.app_wr_en_n        (app_wr_en_n        ) ,
//		.app_rd_data        (app_rd_data        ) ,
//		.app_rd_valid       (app_rd_valid       ) ,
//		.app_last_rd        (app_last_rd        ) ,
//		.app_last_wr        (app_last_wr        ) ,
//		.app_wr_next_req    (app_wr_next_req    ) ,
//		.sdr_init_done      (sdr_init_done      ) ,
//		.app_req_dma_last   (app_req            ) ,
//
//		/* Interface to SDRAMs */
//		.sdr_cs_n(io_cs_n),
//		.sdr_cke(io_cke),
//		.sdr_ras_n(io_ras_n),
//		.sdr_cas_n(io_cas_n),
//		.sdr_we_n(io_we_n),
//		.sdr_dqm(io_dqm),
//		.sdr_ba(io_ba),
//		.sdr_addr(io_addr), 
//		.pad_sdr_din(pad_sdr_din),
//		.sdr_dout(sdr_dout),
//		.sdr_den_n(sdr_den_n),
//		
//		/* Parameters */
//		.cfg_sdr_en(1'b1),
//		.cfg_sdr_mode_reg(13'h033),
//		.cfg_sdr_tras_d(4'h6),
//		.cfg_sdr_trp_d(4'h3),
//		.cfg_sdr_trcd_d(4'h3),
//		.cfg_sdr_cas(3'h3),
//		.cfg_sdr_trcar_d(4'h9),
//		.cfg_sdr_twr_d(4'h2),
//		.cfg_sdr_rfsh(12'h10),
//		.cfg_sdr_rfmax(3'h15)
//	);
//	
//	initial begin
//		data[0] = 0;
//		data[1] = 0;
//		data[2] = 0;
//		data[3] = 0;
//		data[4] = 0;
//		data[5] = 0;
//		data[6] = 0;
//		data[7] = 0;
//		dat_r = 8'bzzzzzzzz;
//		state = IDLE;
//		app_wr_en_n = 0;
//		cmd_fifo_winc = 0;
//		cmd_fifo_data = 0;
//		write_fifo_winc = 0;
//		write_fifo_wdata = 0;
////		read_fifo_rinc = 0;
//	end
//		
//	always @(posedge clk or negedge rst_n) begin
//		if (!rst_n) begin
//			data[0] <= 0;
//			data[1] <= 0;
//			data[2] <= 0;
//			data[3] <= 0;
//			data[4] <= 0;
//			data[5] <= 0;
//			data[6] <= 0;
//			data[7] <= 0;
//			dat_r <= 8'bzzzzzzzz;
//			state <= IDLE;
//			app_wr_en_n <= 0;
//			cmd_fifo_winc <= 0;
//			cmd_fifo_data <= 0;
//			write_fifo_winc <= 0;
//			write_fifo_wdata <= 0;
////			read_fifo_rinc <= 0;
//		end
//		else begin
//			if (adr[13:9] == ADDR) begin
//				if (we) begin
//					dat_r <= 8'bzzzzzzzz;
//					case (adr[8:0])
//						9'd0: begin
//							state <= dat_w;
//						end
//						9'd1: begin
//							req_addr[7:0] <= dat_w;
//						end
//						9'd2: begin
//							req_addr[15:8] <= dat_w;
//						end
//						9'd3: begin
//							req_addr[23:16] <= dat_w;
//						end
//						9'd4: begin
//							req_addr[25:24] <= dat_w;
//						end
//						9'd5: begin
//							data[xfer_counter][7:0] <= dat_w;
//						end
//						9'd6: begin
//							data[xfer_counter][15:8] <= dat_w;
//						end
//						9'd7: begin
//							data[xfer_counter][23:16] <= dat_w;
//						end
//						9'd8: begin
//							data[xfer_counter][31:24] <= dat_w;
//						end
//						9'd9: begin
//							xfer_counter <= dat_w;
//						end
//						9'd10: begin
//							req_len <= dat_w;
//						end
//						9'd11: begin
//							xfer_counter <= 0;
//							if (!dat_w) begin
////								app_wr_en_n <= 0;
////								app_req_wr_n <= 0;
////								app_req_len <= req_len;
////								app_req_addr <= req_addr;
////								app_wr_data <= data[0];
//								state <= REQ_WR;
//							end
//							else begin
////								app_req_wr_n <= 1;
////								app_req_addr <= req_addr;
////								app_req_len <= req_len;
//								state <= REQ_RD;
//							end
//						end
//					endcase
//				end
//				else begin
//					case (adr[8:0])
//						9'd0: begin
//							dat_r <= state;
//						end
//						9'd1: begin
//							dat_r <= req_addr[7:0];
//						end
//						9'd2: begin
//							dat_r <= req_addr[15:8];
//						end
//						9'd3: begin
//							dat_r <= req_addr[23:16];
//						end
//						9'd4: begin
//							dat_r <= req_addr[25:24];
//						end
//						9'd5: begin
//							dat_r <= data[xfer_counter][7:0];
//						end
//						9'd6: begin
//							dat_r <= data[xfer_counter][15:8];
//						end
//						9'd7: begin
//							dat_r <= data[xfer_counter][23:16];
//						end
//						9'd8: begin
//							dat_r <= data[xfer_counter][31:24];
//						end
//						9'd9: begin
//							dat_r <= xfer_counter;
//						end
//						9'd10: begin
//							dat_r <= req_len;
//						end
//					endcase
//				end
//				case (state)
//					IDLE: begin
////						app_req <= 0;
////						app_wr_en_n <= 0;
//					end
//					REQ_WR: begin
//						if (xfer_counter < req_len) begin
//							write_fifo_winc <= 1;
//							write_fifo_wdata <= data[xfer_counter];
//							xfer_counter <= xfer_counter + 1;
//						end
//						else begin
//							write_fifo_winc <= 0;
//							state <= WR;
//							cmd_fifo_data <= {req_len, 1'b0, req_addr};
//							cmd_fifo_winc <= 1;
//						end
//					end
//					WR: begin
//						cmd_fifo_winc <= 0;
//						state <= IDLE;
//					end
//					REQ_RD: begin
//						cmd_fifo_data <= {req_len, 1'b1, req_addr};
//						cmd_fifo_winc <= 1;
//						state <= RD;
//					end
//					RD: begin
//						cmd_fifo_winc <= 0;
//						if (!read_fifo_rempty) begin
////							read_fifo_rinc <= 1;
//							data[xfer_counter] <= read_fifo_rdata;
//							xfer_counter <= xfer_counter + 1;
//						end
////						if (xfer_counter < req_len) begin
////
//////							else begin
//////								read_fifo_rinc <= 0;
//////							end
////						end
//						else if (xfer_counter >= req_len) begin
////								read_fifo_rinc <= 0;
//							state <= IDLE;
//						end
//					end
//				endcase
//			end
//		end
//	end

//	wire	[15:0]pad_sdr_din;
//	wire	[15:0]sdr_dout;
//	wire	[1:0]sdr_den_n;
//
//	reg app_req;
//	reg [25:0]app_req_addr;
//	reg [8:0]app_req_len;
//	reg app_req_wr_n;
//	wire app_req_ack;
//	reg [31:0]app_wr_data;
//	reg [3:0]app_wr_en_n;
//	wire [31:0]app_rd_data;
//	wire app_rd_valid;
//	wire app_last_rd;
//	wire app_last_wr;
//	wire app_wr_next_req;
//	wire sdr_init_done;
// 
//	reg [31:0]data[31:0];
//	
//	reg [7:0]state;
//	reg [7:0]xfer_counter;
//	reg [7:0]req_len;
//	reg [31:0]req_addr;
//	
//	parameter ADDR = 1;
//	parameter IDLE = 8'd0;
//	parameter REQ_WR = 8'd1;
//	parameter WR = 8'd2;
//	parameter REQ_RD = 8'd3;
//	parameter RD = 8'd4;
//	parameter WR1 = 8'd5;
//	parameter RD1 = 8'd6;
//	
//	assign io_dq[7:0] = (sdr_den_n[0] == 1'b0) ? sdr_dout[7:0] : 8'hZZ;
//	assign io_dq[15:8] = (sdr_den_n[1] == 1'b0) ? sdr_dout[15:8] : 8'hZZ;
//	assign pad_sdr_din = io_dq;
//	assign io_clk = ~clk;
//	
//	
//	sdrc_core
//	#(
//		.SDR_DW(16),	// SDR Data Width 
//		.SDR_BW(2)		// SDR Byte Width
//	)
//	ram
//	(
//		.clk(clk),
//		.pad_clk(io_clk),
//		.reset_n(rst_n),
//		.sdr_width(2'b01),
//		.cfg_colbits(2'b01),
//
//		/* Request from app */
//		.app_req            (app_req            ) ,// Transfer Request
//		.app_req_addr       (app_req_addr       ) ,// SDRAM Address
//		.app_req_len        (app_req_len        ) ,// Burst Length (in 16 bit words)
//		.app_req_wrap       (1'b0               ) ,// Wrap mode request 
//		.app_req_wr_n       (app_req_wr_n       ) ,// 0 => Write request, 1 => read req
//		.app_req_ack        (app_req_ack        ) ,// Request has been accepted
//		.cfg_req_depth      (2'b11) ,//how many req. buffer should hold
//
//		.app_wr_data        (app_wr_data        ) ,
//		.app_wr_en_n        (app_wr_en_n        ) ,
//		.app_rd_data        (app_rd_data        ) ,
//		.app_rd_valid       (app_rd_valid       ) ,
//		.app_last_rd        (app_last_rd        ) ,
//		.app_last_wr        (app_last_wr        ) ,
//		.app_wr_next_req    (app_wr_next_req    ) ,
//		.sdr_init_done      (sdr_init_done      ) ,
//		.app_req_dma_last   (app_req            ) ,
//
//		/* Interface to SDRAMs */
//		.sdr_cs_n(io_cs_n),
//		.sdr_cke(io_cke),
//		.sdr_ras_n(io_ras_n),
//		.sdr_cas_n(io_cas_n),
//		.sdr_we_n(io_we_n),
//		.sdr_dqm(io_dqm),
//		.sdr_ba(io_ba),
//		.sdr_addr(io_addr), 
//		.pad_sdr_din(pad_sdr_din),
//		.sdr_dout(sdr_dout),
//		.sdr_den_n(sdr_den_n),
//		
//		/* Parameters */
//		.cfg_sdr_en(1'b1),
//		.cfg_sdr_mode_reg(13'h033),
//		.cfg_sdr_tras_d(4'h6),
//		.cfg_sdr_trp_d(4'h3),
//		.cfg_sdr_trcd_d(4'h3),
//		.cfg_sdr_cas(3'h3),
//		.cfg_sdr_trcar_d(4'h9),
//		.cfg_sdr_twr_d(4'h2),
//		.cfg_sdr_rfsh(12'h10),
//		.cfg_sdr_rfmax(3'h15)
//	);
//	
//	initial begin
//		data[0] = 0;
//		data[1] = 0;
//		data[2] = 0;
//		data[3] = 0;
//		data[4] = 0;
//		data[5] = 0;
//		data[6] = 0;
//		data[7] = 0;
//		dat_r = 8'bzzzzzzzz;
//		state = IDLE;
//	end
//		
//	always @(posedge clk or negedge rst_n) begin
//		if (!rst_n) begin
//			data[0] <= 0;
//			data[1] <= 0;
//			data[2] <= 0;
//			data[3] <= 0;
//			data[4] <= 0;
//			data[5] <= 0;
//			data[6] <= 0;
//			data[7] <= 0;
//			dat_r <= 8'bzzzzzzzz;
//			state <= IDLE;
//		end
//		else begin
//			if (adr[13:9] == ADDR) begin
//				if (we) begin
//					dat_r <= 8'bzzzzzzzz;
//					case (adr[8:0])
//						9'd0: begin
//							state <= dat_w;
//						end
//						9'd1: begin
//							req_addr[7:0] <= dat_w;
//						end
//						9'd2: begin
//							req_addr[15:8] <= dat_w;
//						end
//						9'd3: begin
//							req_addr[23:16] <= dat_w;
//						end
//						9'd4: begin
//							req_addr[31:24] <= dat_w;
//						end
//						9'd5: begin
//							data[xfer_counter][7:0] <= dat_w;
//						end
//						9'd6: begin
//							data[xfer_counter][15:8] <= dat_w;
//						end
//						9'd7: begin
//							data[xfer_counter][23:16] <= dat_w;
//						end
//						9'd8: begin
//							data[xfer_counter][31:24] <= dat_w;
//						end
//						9'd9: begin
//							xfer_counter <= dat_w;
//						end
//						9'd10: begin
//							req_len <= dat_w;
//						end
//						9'd11: begin
//							xfer_counter <= 0;
//							if (!dat_w) begin
//								app_wr_en_n <= 0;
//								app_req_wr_n <= 0;
//								app_req_len <= req_len;
//								app_req_addr <= req_addr;
//								app_wr_data <= data[0];
//								state <= REQ_WR;
//							end
//							else begin
//								app_req_wr_n <= 1;
//								app_req_addr <= req_addr;
//								app_req_len <= req_len;
//								state <= REQ_RD;
//							end
//						end
//					endcase
//				end
//				else begin
//					case (adr[8:0])
//						9'd0: begin
//							dat_r <= state;
//						end
//						9'd1: begin
//							dat_r <= req_addr[7:0];
//						end
//						9'd2: begin
//							dat_r <= req_addr[15:8];
//						end
//						9'd3: begin
//							dat_r <= req_addr[23:16];
//						end
//						9'd4: begin
//							dat_r <= req_addr[31:24];
//						end
//						9'd5: begin
//							dat_r <= data[xfer_counter][7:0];
//						end
//						9'd6: begin
//							dat_r <= data[xfer_counter][15:8];
//						end
//						9'd7: begin
//							dat_r <= data[xfer_counter][23:16];
//						end
//						9'd8: begin
//							dat_r <= data[xfer_counter][31:24];
//						end
//						9'd9: begin
//							dat_r <= xfer_counter;
//						end
//						9'd10: begin
//							dat_r <= req_len;
//						end
//					endcase
//				end
//				case (state)
//					IDLE: begin
//						app_req <= 0;
//						app_wr_en_n <= 0;
//					end
//					REQ_WR: begin
//						app_req <= 1;
////						app_wr_en_n <= 0;
////						app_req_wr_n <= 0;
////						app_req_len <= req_len;
////						app_req_addr <= req_addr;
////						app_wr_data <= data[xfer_counter];
//						if (app_req_ack) begin
//							app_wr_data <= data[xfer_counter];
//							app_req <= 0;
//							app_wr_en_n <= 0;
//							state <= WR;
//						end
//					end
//					WR: begin
//						if (app_wr_next_req) begin
//							xfer_counter <= xfer_counter + 1;
//							app_wr_data <= data[xfer_counter + 1];
//						end
//						if (xfer_counter >= req_len) begin
//							state <= IDLE;
//						end
//					end
//					REQ_RD: begin
//						app_req <= 1;
////						app_req_wr_n <= 1;
////						app_req_addr <= req_addr;
////						app_req_len <= req_len;
//						if (app_req_ack) begin
//							app_req <= 0;
//							state <= RD;
//						end
//					end
//					RD: begin
//						if (app_rd_valid) begin
////							state <= RD1;
//							data[xfer_counter] <= app_rd_data;
//							xfer_counter <= xfer_counter + 1;
//						end
//						if (xfer_counter >= req_len) begin
//							state <= IDLE;
//						end
//					end
//					RD1: begin
//						data[xfer_counter] <= app_rd_data;
//						xfer_counter <= xfer_counter + 1;
//						state <= RD;
//					end
//				endcase
//			end
//		end
//	end

//	reg stb_i;
//	reg we_i;
//	reg cyc_i;
//	reg [31:0]addr_i;
//	reg [31:0]data_i;
//	wire [31:0]data_o;
//	wire stall_o;
//	wire ack_o;
// 
//	reg [31:0]data[31:0];
//	
//	reg [7:0]state;
//	reg [7:0]xfer_counter;
//	reg [7:0]req_len;
//	reg [31:0]req_addr;
//	
//	parameter ADDR = 1;
//	parameter IDLE = 8'd0;
//	parameter REQ_WR = 8'd1;
//	parameter WR = 8'd2;
//	parameter REQ_RD = 8'd3;
//	parameter RD = 8'd4;
//	
//	sdram
//	#(
//		.SDRAM_MHZ(100),
//		.SDRAM_ADDR_W(24),
//		.SDRAM_COL_W(9),    
//		.SDRAM_BANK_W(2),
//		.SDRAM_DQM_W(2),
//		.SDRAM_BANKS(2 ** 2),
//		.SDRAM_ROW_W(24 - 9 - 2),
//		.SDRAM_REFRESH_CNT(2 ** (24 - 9 - 2)),
//		.SDRAM_START_DELAY(100000 / (1000 / 100)), // 100uS
//		.SDRAM_REFRESH_CYCLES((32000*100) / (2 ** (24 - 9 - 2))-1),
//		.SDRAM_READ_LATENCY(3),
//		.SDRAM_TARGET("SIMULATION")
//	)
//	ram
//	(
//		.clk_i(clk),
//		.rst_i(rst),
//
//	// Wishbone Interface
//		.stb_i(stb_i),
//		.we_i(we_i),
//		.sel_i(4'b1111),
//		.cyc_i(cyc_i),
//		.addr_i(addr_i),
//		.data_i(data_i),
//		.data_o(data_o),
//		.stall_o(stall_o),
//		.ack_o(ack_o),
//
//	// SDRAM Interface
//		.sdram_clk_o(io_clk),
//		.sdram_cke_o(io_cke),
//		.sdram_cs_o(io_cs_n),
//		.sdram_ras_o(io_ras_n),
//		.sdram_cas_o(io_cas_n),
//		.sdram_we_o(io_we_n),
//		.sdram_dqm_o(io_dqm),
//		.sdram_addr_o(io_addr),
//		.sdram_ba_o(io_ba),
//		.sdram_data_io(io_dq)
//	);
//	
//	initial begin
//		data[0] = 0;
//		data[1] = 0;
//		data[2] = 0;
//		data[3] = 0;
//		data[4] = 0;
//		data[5] = 0;
//		data[6] = 0;
//		data[7] = 0;
//		dat_r = 8'bzzzzzzzz;
//		state = IDLE;
//	end
//		
//	always @(posedge clk or negedge rst_n) begin
//		if (!rst_n) begin
//			data[0] <= 0;
//			data[1] <= 0;
//			data[2] <= 0;
//			data[3] <= 0;
//			data[4] <= 0;
//			data[5] <= 0;
//			data[6] <= 0;
//			data[7] <= 0;
//			dat_r <= 8'bzzzzzzzz;
//			state <= IDLE;
//		end
//		else begin
//			if (adr[13:9] == ADDR) begin
//				if (we) begin
//					dat_r <= 8'bzzzzzzzz;
//					case (adr[8:0])
//						9'd0: begin
//							state <= dat_w;
//						end
//						9'd1: begin
//							req_addr[7:0] <= dat_w;
//						end
//						9'd2: begin
//							req_addr[15:8] <= dat_w;
//						end
//						9'd3: begin
//							req_addr[23:16] <= dat_w;
//						end
//						9'd4: begin
//							req_addr[31:24] <= dat_w;
//						end
//						9'd5: begin
//							data[xfer_counter][7:0] <= dat_w;
//						end
//						9'd6: begin
//							data[xfer_counter][15:8] <= dat_w;
//						end
//						9'd7: begin
//							data[xfer_counter][23:16] <= dat_w;
//						end
//						9'd8: begin
//							data[xfer_counter][31:24] <= dat_w;
//						end
//						9'd9: begin
//							xfer_counter <= dat_w;
//						end
//						9'd10: begin
//							req_len <= dat_w;
//						end
//						9'd11: begin
//							xfer_counter <= 0;
//							if (!dat_w) begin
//								state <= REQ_WR;
//							end
//							else begin
//								state <= REQ_RD;
//							end
//						end
//					endcase
//				end
//				else begin
//					case (adr[8:0])
//						9'd0: begin
//							dat_r <= state;
//						end
//						9'd1: begin
//							dat_r <= req_addr[7:0];
//						end
//						9'd2: begin
//							dat_r <= req_addr[15:8];
//						end
//						9'd3: begin
//							dat_r <= req_addr[23:16];
//						end
//						9'd4: begin
//							dat_r <= req_addr[31:24];
//						end
//						9'd5: begin
//							dat_r <= data[xfer_counter][7:0];
//						end
//						9'd6: begin
//							dat_r <= data[xfer_counter][15:8];
//						end
//						9'd7: begin
//							dat_r <= data[xfer_counter][23:16];
//						end
//						9'd8: begin
//							dat_r <= data[xfer_counter][31:24];
//						end
//						9'd9: begin
//							dat_r <= xfer_counter;
//						end
//						9'd10: begin
//							dat_r <= req_len;
//						end
//					endcase
//				end
//				case (state)
//					IDLE: begin
//						stb_i <= 0;
//						cyc_i <= 0;
//						addr_i <= 0;
//						data_i <= 0;
//					end
//					REQ_WR: begin
//						stb_i <= 1;
//						we_i <= 1;
//						cyc_i <= 1;
//						data_i <= data[xfer_counter];
//						addr_i <= req_addr;
//						if (ack_o && !stall_o) begin
//							xfer_counter <= xfer_counter + 1;
//							addr_i <= req_addr + (xfer_counter+1) * 4;
//							data_i <= data[xfer_counter+1];
//						end
//						if (xfer_counter >= req_len) begin
//							state <= IDLE;
//						end
//					end
//					REQ_RD: begin
//						stb_i <= 1;
//						we_i <= 0;
//						cyc_i <= 1;
//						addr_i <= req_addr;
//						if (ack_o && !stall_o) begin
//							xfer_counter <= xfer_counter + 1;
//							addr_i <= req_addr + (xfer_counter+1) * 4;
//							data[xfer_counter] <= data_o;
//						end
//						if (xfer_counter >= req_len) begin
//							state <= IDLE;
//						end
//					end
//				endcase
//			end
//		end
//	end

endmodule