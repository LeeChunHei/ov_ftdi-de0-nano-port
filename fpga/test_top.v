module test_top(
	input		CLOCK_50,
	input		sys_rst_n,
	output	[7:0]LED,
	output	[2:0]leds,
	input		ftdi_clk,
	output	[7:0]ftdi_d__,
	output	ftdi_rxf_n__,
	output	ftdi_txe_n__,
	output	ftdi_rd_n__,
	output	ftdi_wr_n__,
	output	ftdi_siwua_n__,
	output	ftdi_oe_n__,
	output	fifo_winc__,
	output	[7:0]fifo_wdata__,
	output	fifo_wfull__,
	output	fifo_tx_ind__,
	output	fifo_rx_ind__,
	output	fifo_rinc__,
	output	[7:0]fifo_rdata__,
	output	fifo_rempty__,
	output	[2:0]p_bdec_state,
	output	[13:0]p_bm_adr,
	output	p_bm_we,
	output	[7:0]p_bm_dat_w,
	output	[7:0]p_bm_dat_r,
	output	p_pll
);

	wire pll_rst;
	wire pll_locked;
	wire sys_clk;
	
	
	wire	[7:0]ftdi_d;
	reg	[7:0]ftdi_d_reg;
	reg	ftdi_d_oe;
	reg	_ftdi_rxf_n;
	reg	_ftdi_txe_n;
	wire	ftdi_rd_n;
	wire	ftdi_wr_n;
	wire	ftdi_siwua_n;
	wire	ftdi_oe_n;
	
	assign pll_rst = 0;
	
	assign ftdi_d = ftdi_d_oe ? ftdi_d_reg : 8'bzzzzzzzz;
	assign ftdi_d__ = ftdi_d;
	assign ftdi_rxf_n__ = _ftdi_rxf_n;
	assign ftdi_txe_n__ = _ftdi_txe_n;
	assign ftdi_rd_n__ = ftdi_rd_n;
	assign ftdi_wr_n__ = ftdi_wr_n;
	assign ftdi_siwua_n__ = ftdi_siwua_n;
	assign ftdi_oe_n__ = ftdi_oe_n;
	
	top t(
		.CLOCK_50(CLOCK_50),
		.LED(LED),
		.leds(leds),
		.ftdi_clk(ftdi_clk),
		.ftdi_d(ftdi_d),
		.ftdi_rxf_n(_ftdi_rxf_n),
		.ftdi_txe_n(_ftdi_txe_n),
		.ftdi_rd_n(ftdi_rd_n),
		.ftdi_wr_n(ftdi_wr_n),
		.ftdi_siwua_n(ftdi_siwua_n),
		.ftdi_oe_n(ftdi_oe_n),
		.p_ftdi_rinc(fifo_rinc__),
		.p_ftdi_rempty(fifo_rempty__),
		.p_ftdi_rdata(fifo_rdata__),
		.p_bdec_state(p_bdec_state),
		.p_bm_adr(p_bm_adr),
		.p_bm_we(p_bm_we),
		.p_bm_dat_w(p_bm_dat_w),
		.p_bm_dat_r(p_bm_dat_r),
		.p_pll(p_pll)
	);
	
	reg [7:0]ft_state;
	reg [7:0]count;
	
	reg [7:0]state;
	reg [7:0]next_state;
	
	parameter IDLE = 0;
	parameter WRITE0 = 1;
	parameter WRITE1 = 2;
	parameter WRITE2 = 3;
	parameter WRITE3 = 4;
	parameter WRITE4 = 5;
	parameter WRITE5 = 6;
	parameter WRITE6 = 7;
	parameter WRITE7 = 8;
	parameter READ0 = 9;
	parameter READ1 = 10;
	parameter READ2 = 11;
	parameter READ3 = 12;
	parameter READ4 = 13;
	parameter READ5 = 14;
	parameter READ6 = 15;
	parameter READ7 = 16;
	
	always @(posedge ftdi_clk or negedge sys_rst_n) begin
		if (!sys_rst_n) begin
			ftdi_d_oe <= 0;
			_ftdi_rxf_n <= 1;
			_ftdi_txe_n <= 1;
			count <= 1;
			ft_state <= IDLE;
		end
		else begin
			case (ft_state)
				IDLE: begin
					ftdi_d_oe <= 0;
					_ftdi_rxf_n <= 1;
					_ftdi_txe_n <= 1;
					ft_state <= WRITE0;
				end
				WRITE0: begin
					_ftdi_rxf_n <= 0;
					ft_state <= WRITE1;
				end
				WRITE1: begin
					if (!ftdi_oe_n) begin
						count <= count + 1;
						ftdi_d_reg <= 8'h55;//count;
						ftdi_d_oe <= 1;
						if (!ftdi_rd_n) begin
							ft_state <= WRITE2;
						end
					end
				end
				WRITE2: begin
					ftdi_d_oe <= !ftdi_oe_n;
					ftdi_d_reg <= {1'b1, 1'b0, 6'b0};
					if (!ftdi_rd_n) begin
						ft_state <= WRITE3;
					end
				end
				WRITE3: begin
					ftdi_d_oe <= !ftdi_oe_n;
					ftdi_d_reg <= 8'b0;
					if (!ftdi_rd_n) begin
						ft_state <= WRITE4;
					end
				end
				WRITE4: begin
					ftdi_d_oe <= !ftdi_oe_n;
					ftdi_d_reg <= 8'b111;
					if (!ftdi_rd_n) begin
						ft_state <= WRITE5;
					end
				end
				WRITE5: begin
					ftdi_d_oe <= !ftdi_oe_n;
					ftdi_d_reg <= 8'h55 + {1'b1, 1'b0, 6'b0} + 8'b0 + 8'b111;
					if (!ftdi_rd_n) begin
						ft_state <= WRITE6;
					end
				end
				WRITE6: begin
					_ftdi_rxf_n <= 1;
					if (ftdi_oe_n) begin
						ftdi_d_oe <= 0;
						ft_state <= WRITE7;
					end
				end
				WRITE7: begin
					ftdi_d_oe <= 0;
					_ftdi_rxf_n <= 1;
					_ftdi_txe_n <= 1;
					ft_state <= READ0;
				end
				READ0: begin
					_ftdi_txe_n <= 0;
				end
			endcase
		end
	end
	
	always @(posedge sys_clk or negedge sys_rst_n) begin
		if (!sys_rst_n) begin
//			fifo_rinc <= 0;
//			fifo_winc <= 0;
//			fifo_wdata <= 0;
			state <= IDLE;
			next_state <= IDLE;
		end
		else begin
//			if (!fifo_rempty) begin
//				fifo_rinc <= 1;
//			end
//			else begin
//				fifo_rinc <= 0;
//			end
		
			state <= next_state;
//			case (ft_state)
//				IDLE: begin
//					ftdi_rxf_n <= 1;
//					ftdi_txe_n <= 1;
//					fifo_rinc <= 0;
//					fifo_winc <= 0;
//					fifo_wdata <= 0;
//				end
//			endcase
		end
	end
	
endmodule