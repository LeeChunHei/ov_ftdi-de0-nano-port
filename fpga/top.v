module top(
	input		CLOCK_50,
	output	[7:0]LED,
	output	[2:0]leds,
	input		ftdi_clk,
	inout		[7:0]ftdi_d,
	input		ftdi_rxf_n,
	input		ftdi_txe_n,
	output	ftdi_rd_n,
	output	ftdi_wr_n,
	inout		ftdi_siwua_n,
	output	ftdi_oe_n,
	
	output	DRAM_CS_N,
	output	DRAM_CKE,
	output	DRAM_RAS_N,
	output	DRAM_CAS_N,
	output	DRAM_WE_N,
	output	[1:0]DRAM_DQM,
	output	[1:0]DRAM_BA,
	output	[12:0]DRAM_ADDR,
	inout		[15:0]DRAM_DQ,
	output	DRAM_CLK
);

//	input		CLOCK_50;
//	output	[7:0]LED;
//	output	[2:0]leds;
//	input		ftdi_clk;
//	inout		[7:0]ftdi_d;
//	input		ftdi_rxf_n;
//	input		ftdi_txe_n;
//	output	ftdi_rd_n;
//	output	ftdi_wr_n;
//	inout		ftdi_siwua_n;
//	output	ftdi_oe_n;

//	wire pll_rst;
//	wire pll_locked;
//	wire sys_clk;
//	wire sys_rst_n;
//	
//	reg [31:0]counter;
//	reg [7:0]counter0;
//	reg [2:0]counter1;
//
//	assign pll_rst = 0;
//	assign sys_rst_n = pll_locked;	
//	assign LED = counter0;
//	assign leds = counter1;
//	
//	pll pll_0(
//		.areset(pll_rst),
//		.inclk0(CLOCK_50),
//		.c0(sys_clk),
//		.locked(pll_locked)
//	);
//	
//	always @(posedge sys_clk or negedge sys_rst_n) begin
//		if (!sys_rst_n) begin
//			counter  <= 0;
//			counter0 <= 0;
//			counter1 <= 0;
//		end
//		else begin
//			counter <= counter + 1;
//			if (counter >= 100000000) begin
//				counter <= 0;
//				counter0 <= counter0 + 1;
//				counter1 <= counter1 + 1;
//			end
//		end
//	end
	
	wire pll_rst;
	wire pll_locked;
	wire sys_clk;
	wire sys_rst_n;
	
	wire fifo_rinc;
	wire [7:0]fifo_rdata;
	wire fifo_rempty;
	wire fifo_winc;
	wire [7:0]fifo_wdata;
	wire fifo_wfull;
	wire fifo_tx_ind;
	wire fifo_rx_ind;
	
	wire bdec_sink_stb;
	wire bdec_sink_ack;
	wire [7:0]bdec_sink_d;
	wire bdec_source_stb;
	wire bdec_source_ack;
	wire bdec_source_wr;
	wire [13:0]bdec_source_a;
	wire [7:0]bdec_source_d;
	
	wire [13:0]bm_adr;
	wire bm_we;
	wire [7:0]bm_dat_w;
	wire [7:0]bm_dat_r;
	
	wire benc_sink_stb;
	wire benc_sink_ack;
	wire benc_sink_wr;
	wire [13:0]benc_sink_a;
	wire [7:0]benc_sink_d;
	wire benc_source_stb;
	wire benc_source_ack;
	wire [7:0]benc_source_d;
	wire benc_source_last;
	
//	reg [2:0]leds_reg;
	
	wire heartbeat;
	
	assign pll_rst = 0;
	assign sys_rst_n = pll_locked;
	
	// ftdi_fifo to bus_decode
	assign bdec_sink_stb = !fifo_rempty;
	assign bdec_sink_d = fifo_rdata;
	assign fifo_rinc = bdec_sink_ack;

	// bus_encode to fidi_fifo
	assign fifo_winc = benc_source_stb;
	assign fifo_wdata = benc_source_d;
	assign benc_source_ack = !fifo_wfull;
	
//	assign leds = leds_reg;
//	assign leds[0] = fifo_tx_ind;
//	assign leds[1] = fifo_rx_ind;
	
	pll pll_0(
		.areset(pll_rst),
		.inclk0(CLOCK_50),
		.c0(sys_clk),
		.locked(pll_locked));
	
	syncFT245 ft245_bus(
		.io_clk(ftdi_clk),
		.io_d(ftdi_d),
		.io_rxf_n(ftdi_rxf_n),
		.io_txe_n(ftdi_txe_n),
		.io_rd_n(ftdi_rd_n),
		.io_wr_n(ftdi_wr_n),
		.io_siwua_n(ftdi_siwua_n),
		.io_oe_n(ftdi_oe_n),
		.rst_n(sys_rst_n),
		.sys_clk(sys_clk),
		.rinc(fifo_rinc),
		.rdata(fifo_rdata),
		.rempty(fifo_rempty),
		.winc(fifo_winc),
		.wdata(fifo_wdata),
		.wfull(fifo_wfull),
		.tx_ind(fifo_tx_ind),
		.rx_ind(fifo_rx_ind)
	);

	bus_decode bdec(
		.clk(sys_clk),
		.rst_n(sys_rst_n),
		.sink_stb(bdec_sink_stb),
		.sink_ack(bdec_sink_ack),
		.sink_d(bdec_sink_d),
		.source_stb(bdec_source_stb),
		.source_ack(bdec_source_ack),
		.source_wr(bdec_source_wr),
		.source_a(bdec_source_a),
		.source_d(bdec_source_d)
	);
	
	bus_master bm(
		.clk(sys_clk),
		.rst_n(sys_rst_n),
		.sink_stb(bdec_source_stb),
		.sink_ack(bdec_source_ack),
		.sink_wr(bdec_source_wr),
		.sink_a(bdec_source_a),
		.sink_d(bdec_source_d),
		.source_stb(benc_sink_stb),
		.source_ack(benc_sink_ack),
		.source_wr(benc_sink_wr),
		.source_a(benc_sink_a),
		.source_d(benc_sink_d),
		.adr(bm_adr),
		.we(bm_we),
		.dat_w(bm_dat_w),
		.dat_r(bm_dat_r)
	);

	bus_encode benc(
		.clk(sys_clk),
		.rst_n(sys_rst_n),
		.sink_stb(benc_sink_stb),
		.sink_ack(benc_sink_ack),
		.sink_wr(benc_sink_wr),
		.sink_a(benc_sink_a),
		.sink_d(benc_sink_d),
		.source_stb(benc_source_stb),
		.source_ack(benc_source_ack),
		.source_d(benc_source_d),
		.source_last(benc_source_last)
	);
		
	led_slave
	#(
		.N(3),
		.MUX_N(2),
		.ADDR(0),
		.ACT_H(0)
	 )
	 led_peri(
		.clk(sys_clk),
		.rst_n(sys_rst_n),
		.adr(bm_adr),
		.we(bm_we),
		.dat_w(bm_dat_w),
		.dat_r(bm_dat_r),
		.leds_wire(leds),
		.leds_external_signal({	1'b0, fifo_tx_ind,
										1'b0, fifo_rx_ind,
										heartbeat, 1'b0})
	);
	
	timer
	#
	(
		.BITS(32)
	)
	timer0
	(
		.clk(sys_clk),
		.rst_n(sys_rst_n),
		.reload_cnt(100000000),
		.threshold(50000000),
		.channel_0(heartbeat)
	);
	
	
	wire [15:0]f_dram_dq;
	wire [12:0]f_dram_addr;
	wire [1:0]f_dram_ba;
	wire f_dram_clk;
	wire f_dram_cke;
	wire f_dram_cs;
	wire f_dram_ras;
	wire f_dram_cas;
	wire f_dram_we;
	wire [1:0]f_dram_dqm;
	
	sdram_peri ram_peri(
		.clk(sys_clk),
		.rst_n(sys_rst_n),
		.io_cs_n(DRAM_CS_N),
		.io_cke(DRAM_CKE),
		.io_ras_n(DRAM_RAS_N),
		.io_cas_n(DRAM_CAS_N),
		.io_we_n(DRAM_WE_N),
		.io_dqm(DRAM_DQM),
		.io_ba(DRAM_BA),
		.io_addr(DRAM_ADDR),
		.io_dq(DRAM_DQ),
		.io_clk(DRAM_CLK),
	
		.adr(bm_adr),
		.we(bm_we),
		.dat_w(bm_dat_w),
		.dat_r(bm_dat_r)
	);
	
endmodule