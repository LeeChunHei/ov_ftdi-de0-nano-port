module syncFT245(
	input			io_clk,
	inout			[7:0]io_d,
	input			io_rxf_n,
	input			io_txe_n,
	output reg	io_rd_n,
	output reg	io_wr_n,
	inout			io_siwua_n,
	output reg	io_oe_n,
	input			rst_n,
	input			sys_clk,
	input			rinc,
	output		[7:0]rdata,
	output		rempty,
	input			winc,
	input			[7:0]wdata,
	output		wfull,
	output		tx_ind,
	output		rx_ind
);

//	input			io_clk;
//	inout			[7:0]io_d;
//	input			io_rxf_n;
//	input			io_txe_n;
//	output reg	io_rd_n;
//	output reg	io_wr_n;
//	inout			io_siwua_n;
//	output reg	io_oe_n;
//	input			rst_n;
//	input			sys_clk;
//	input			rinc;
//	output		[7:0]rdata;
//	output		rempty;
//	input			winc;
//	input			[7:0]wdata;
//	output		wfull;
//	output		tx_ind;
//	output		rx_ind;
	
	reg next_RD;
	reg next_WR;
	reg next_OE;
	reg next_dOE;
	
	reg [2:0]fsm_state;
	
	wire can_write;
	wire can_read;
	wire output_fifo_rempty;
	wire incoming_fifo_wfull;
	wire [7:0]output_fifo_rdata;
	reg	output_fifo_rinc;
	reg	incoming_fifo_winc;
	
	parameter IDLE		= 3'b000;
	parameter I2W		= 3'b001;
	parameter WRITE	= 3'b010;
	parameter W2I		= 3'b011;
	parameter READ		= 3'b100;
	parameter READ2	= 3'b101;
	
	assign io_d 		= next_dOE ? output_fifo_rdata : 8'bzzzzzzzz;
	assign io_siwua_n = 1;
	assign can_write	= !io_txe_n & !output_fifo_rempty;
	assign can_read	= !io_rxf_n & !incoming_fifo_wfull;
	
	assign tx_ind = !io_wr_n;
	assign rx_ind = !io_rd_n;
	
	async_fifo 
	#(
        .DSIZE(8),
        .ASIZE(6),
        .FALLTHROUGH("FALSE")
   )
	incoming_fifo
	(
		.wclk(io_clk),
      .wrst_n(rst_n),
      .winc(incoming_fifo_winc),
      .wdata(io_d),
      .wfull(incoming_fifo_wfull),
      .awfull(),
      .rclk(sys_clk),
      .rrst_n(rst_n),
      .rinc(rinc),
      .rdata(rdata),
      .rempty(rempty),
      .arempty()
	);
	
	async_fifo 
	#(
        .DSIZE(8),
        .ASIZE(6),
        .FALLTHROUGH("FALSE")
   )
	output_fifo
	(
		.wclk(sys_clk),
      .wrst_n(rst_n),
      .winc(winc),
      .wdata(wdata),
      .wfull(wfull),
      .awfull(),
      .rclk(io_clk),
      .rrst_n(rst_n),
      .rinc(output_fifo_rinc),
      .rdata(output_fifo_rdata),
      .rempty(output_fifo_rempty),
      .arempty()
	);
	
	always @(posedge io_clk or negedge rst_n) begin
		if (!rst_n) begin
			io_wr_n <= 1;
			io_rd_n <= 1;
			io_oe_n <= 1;
			next_RD <= 0;
			next_WR <= 0;
			next_OE <= 0;
			next_dOE <= 0;
			output_fifo_rinc <= 0;
			incoming_fifo_winc <= 0;
			fsm_state <= IDLE;
		end
		else begin
			io_rd_n <= !next_RD | io_rxf_n;
			io_oe_n <= !next_OE;
			
			case (fsm_state)
				IDLE: begin
					incoming_fifo_winc <= 0;
					if (can_read) begin
						fsm_state <= READ;
						next_OE <= 1;
					end
					else if (can_write) begin
						fsm_state <= I2W;
						next_OE <= 0;
					end
				end
				I2W: begin
					if (!can_write) begin
						fsm_state <= IDLE;
						next_dOE <= 0;
					end
					else begin
						next_WR <= 1;
						next_dOE <= 1;
						output_fifo_rinc <= 1;
						fsm_state <= WRITE;
					end
				end
				WRITE: begin
					if(!can_write) begin
						fsm_state <= W2I;
						io_wr_n <= 1;
						next_dOE <= 0;
						output_fifo_rinc <= 0;
					end
					else begin
						io_wr_n <= 0;
						next_dOE <= 1;
						output_fifo_rinc <= 1;
						next_WR <= 1;
					end
				end
				W2I: begin
					fsm_state <= IDLE;
					next_OE <= 1;
				end
				READ: begin
					if (can_read) begin
						next_RD <= 1;
						next_OE <= 1;
						fsm_state <= READ2;
					end
					else begin
						fsm_state <= IDLE;
						next_OE <= 0;
					end
				end
				READ2: begin
					incoming_fifo_winc <= 1;
					next_RD <= 0;
					next_OE <= 0;
					fsm_state <= IDLE;
				end
			endcase
		end
	end
	
endmodule