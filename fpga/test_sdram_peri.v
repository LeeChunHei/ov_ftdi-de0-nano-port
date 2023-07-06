module test_sdram_peri
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
		output reg [13:0]adr,
		output reg we,
		output reg [7:0]dat_w,
		output [7:0]dat_r,
		output reg [7:0]state
);

	reg [31:0]data[7:0];
	
	reg [31:0]xfer_counter;
	
	parameter IDLE = 8'd0;
	parameter WR_SETUP_0 = 8'd1;
	parameter WR_SETUP_1 = 8'd2;
	parameter WR_SETUP_2 = 8'd3;
	parameter WR_SETUP_3 = 8'd4;
	parameter WR_SETUP_4 = 8'd5;
	parameter WR_0 = 8'd6;
	parameter WR_1 = 8'd7;
	parameter WR_2 = 8'd8;
	parameter WR_3 = 8'd9;
	parameter WR_4 = 8'd10;
	parameter WR_START = 8'd11;
	parameter RD_SETUP_0 = 8'd12;
	parameter RD_SETUP_1 = 8'd13;
	parameter RD_SETUP_2 = 8'd14;
	parameter RD_SETUP_3 = 8'd15;
	parameter RD_SETUP_4 = 8'd16;
	parameter RD_START = 8'd17;
	parameter RD_0 = 8'd18;
	parameter RD_1 = 8'd19;
	parameter RD_2 = 8'd20;
	parameter RD_3 = 8'd21;
	parameter RD_4 = 8'd22;
	parameter STALL = 8'd255;
	
	sdram_peri peri
	(
		.clk(clk),
		.rst_n(rst_n),
		
		.io_cs_n(io_cs_n),
		.io_cke(io_cke),
		.io_ras_n(io_ras_n),
		.io_cas_n(io_cas_n),
		.io_we_n(io_we_n),
		.io_dqm(io_dqm),
		.io_ba(io_ba),
		.io_addr(io_addr),
		.io_dq(io_dq),
		.io_clk(io_clk),
		
		.adr(adr),
		.we(we),
		.dat_w(dat_w),
		.dat_r(dat_r),
	);

	initial begin
		adr = 0;
		we = 0;
		dat_w = 0;
		xfer_counter = 0;
		data[0] = 32'h1122;
		data[1] = 32'h2233;
		data[2] = 32'h3344;
		data[3] = 32'h4455;
		data[4] = 32'h5566;
		data[5] = 32'h6677;
		data[6] = 32'h7788;
		data[7] = 32'h8899;
		state = IDLE;
	end
	
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			adr <= 0;
			we <= 0;
			dat_w <= 0;
			xfer_counter <= 0;
			data[0] <= 32'h1122;
			data[1] <= 32'h2233;
			data[2] <= 32'h3344;
			data[3] <= 32'h4455;
			data[4] <= 32'h5566;
			data[5] <= 32'h6677;
			data[6] <= 32'h7788;
			data[7] <= 32'h8899;
			state <= IDLE;
		end
		else begin
			case (state)
				IDLE: begin
					if (xfer_counter > 254) begin
						state <= WR_SETUP_0;
						xfer_counter <= 0;
					end
					else begin
						xfer_counter <= xfer_counter + 1;
					end
				end
				WR_SETUP_0: begin
					adr <= {5'd1,9'd10};
					we <= 1;
					dat_w <= 8;
					state <= WR_SETUP_1;
				end
				WR_SETUP_1: begin
					adr <= {5'd1,9'd1};
					we <= 1;
					dat_w <= 16;
					state <= WR_SETUP_2;
				end
				WR_SETUP_2: begin
					adr <= {5'd1,9'd2};
					we <= 1;
					dat_w <= 0;
					state <= WR_SETUP_3;
				end
				WR_SETUP_3: begin
					adr <= {5'd1,9'd3};
					we <= 1;
					dat_w <= 0;
					state <= WR_SETUP_4;
				end
				WR_SETUP_4: begin
					adr <= {5'd1,9'd4};
					we <= 1;
					dat_w <= 0;
					state <= WR_0;
				end
				WR_0: begin
					if (xfer_counter < 8) begin
						adr <= {5'd1,9'd9};
						we <= 1;
						dat_w <= xfer_counter;
						state <= WR_1;
					end
					else begin
						adr <= {5'd0,9'd0};
						we <= 0;
						dat_w <= 0;
						state <= WR_START;
						xfer_counter <= 0;
					end
				end
				WR_1: begin
					adr <= {5'd1,9'd5};
					we <= 1;
					dat_w <= data[xfer_counter][7:0];
					state <= WR_2;
				end
				WR_2: begin
					adr <= {5'd1,9'd6};
					we <= 1;
					dat_w <= data[xfer_counter][15:8];
					state <= WR_3;
				end
				WR_3: begin
					adr <= {5'd1,9'd7};
					we <= 1;
					dat_w <= data[xfer_counter][23:16];
					state <= WR_4;
				end
				WR_4: begin
					adr <= {5'd1,9'd8};
					we <= 1;
					dat_w <= data[xfer_counter][31:24];
					xfer_counter <= xfer_counter + 1;
					state <= WR_0;
				end
				WR_START: begin
					if (xfer_counter == 0) begin
						adr <= {5'd1,9'd11};
						we <= 1;
						dat_w <= 0;
						state <= STALL;
//						xfer_counter <= xfer_counter + 1;
					end
//					else if (xfer_counter < 4294967296) begin
//						adr <= 0;
//						we <= 0;
//						dat_w <= 0;
//						xfer_counter <= xfer_counter + 1;
//					end
//					else begin
//						xfer_counter <= 0;
//						state <= RD_SETUP_0;
//					end
				end
				RD_SETUP_0: begin
					adr <= {5'd1,9'd10};
					we <= 1;
					dat_w <= 5;
					state <= RD_SETUP_1;
				end
				RD_SETUP_1: begin
					adr <= {5'd1,9'd1};
					we <= 1;
					dat_w <= 0;
					state <= RD_SETUP_2;
				end
				RD_SETUP_2: begin
					adr <= {5'd1,9'd2};
					we <= 1;
					dat_w <= 0;
					state <= RD_SETUP_3;
				end
				RD_SETUP_3: begin
					adr <= {5'd1,9'd3};
					we <= 1;
					dat_w <= 0;
					state <= RD_SETUP_4;
				end
				RD_SETUP_4: begin
					adr <= {5'd1,9'd4};
					we <= 1;
					dat_w <= 0;
					state <= RD_START;
				end
				RD_START: begin
					adr <= {5'd1,9'd11};
					we <= 1;
					dat_w <= 1;
					state <= STALL;
//					if (xfer_counter == 0) begin
//						adr <= {5'd1,9'd11};
//						we <= 1;
//						dat_w <= 1;
//						state <= STALL;
//					end
//					else if (xfer_counter < 255) begin
//						adr <= {5'd1,9'd0};
//						we <= 0;
//						dat_w <= 0;
//						xfer_counter <= xfer_counter + 1;
//					end
				end
				RD_0: begin
					if (xfer_counter < 5) begin
						adr <= {5'd1,9'd9};
						we <= 1;
						dat_w <= xfer_counter;
						state <= WR_1;
					end
					else begin
						state <= WR_START;
						xfer_counter <= 0;
					end
				end
				RD_1: begin
					adr <= {5'd1,9'd5};
					we <= 1;
					dat_w <= data[xfer_counter][7:0];
					state <= WR_2;
				end
				RD_2: begin
					adr <= {5'd1,9'd6};
					we <= 1;
					dat_w <= data[xfer_counter][15:8];
					state <= WR_3;
				end
				RD_3: begin
					adr <= {5'd1,9'd7};
					we <= 1;
					dat_w <= data[xfer_counter][23:16];
					state <= WR_4;
				end
				RD_4: begin
					adr <= {5'd1,9'd8};
					we <= 1;
					dat_w <= data[xfer_counter][31:24];
					xfer_counter <= xfer_counter + 1;
					state <= STALL;
				end
				STALL: begin
					adr <= {5'd1,9'd0};
					we <= 0;
					dat_w <= 8'hXXXX;
				end
			endcase
		end
	end
endmodule