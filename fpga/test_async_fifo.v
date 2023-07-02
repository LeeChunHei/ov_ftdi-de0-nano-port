module test_async_fifo(wclk__, wrst_n__, winc__, wdata__, wfull__, awfull__, 
							  rclk__, rrst_n__, rinc__, rdata__, rempty__, arempty__);

	input		wclk__;
	input		wrst_n__;
	output	winc__;
	output	[7:0]wdata__;
	output	wfull__;
	output	awfull__;
	
	input		rclk__;
	input		rrst_n__;
	output	rinc__;
	output	[7:0]rdata__;
	output	rempty__;
	output	arempty__;
	
	wire	wclk;
	wire	wrst_n;
	reg	winc;
   reg	[7:0]wdata;
   wire	wfull;
   wire	awfull;
	
	wire	rclk;
	wire	rrst_n;
   reg	rinc;
   wire	[7:0]rdata;
   wire	rempty;
   wire	arempty;
	
	reg [2:0]state;
	reg [2:0]next_state;
	
	reg [7:0]wdata_reg;
	reg [7:0]rdata_reg;
	
	assign wclk		 = wclk__;
	assign wrst_n	 = wrst_n__;
	assign winc__   = winc;
   assign wdata__  = wdata;
   assign wfull__  = wfull;
   assign awfull__ = awfull;
	
	assign rclk		 = rclk__;
	assign rrst_n	 = rrst_n__;
   assign rinc__    = rinc;
   assign rdata__   = rdata_reg;
   assign rempty__  = rempty;
   assign arempty__ = arempty;	
	
	parameter IDLE = 3'b000;
	parameter WRITE1 = 3'b001;
	parameter WRITE2 = 3'b010;
	
	async_fifo 
	#(
        .DSIZE(8),
        .ASIZE(4),
        .FALLTHROUGH("TRUE")
   )
	afifo
	(
		.wclk(wclk),
      .wrst_n(wrst_n),
      .winc(winc),
      .wdata(wdata),
      .wfull(wfull),
      .awfull(awfull),
      .rclk(rclk),
      .rrst_n(rrst_n),
      .rinc(rinc),
      .rdata(rdata),
      .rempty(rempty),
      .arempty(arempty)
	);
	
	always @(posedge wclk or negedge wrst_n) begin
		if (!wrst_n) begin
			state <= IDLE;
			next_state <= IDLE;
			winc <= 1'b0;
			wdata <= 8'b00000000;
			wdata_reg <= 0;
		end
		else begin
			state <= next_state;
			if (state != IDLE) begin
				wdata_reg <= wdata_reg + 1;
			end
		end
		case(state)
			IDLE: begin
				winc <= 1'b0;
				wdata <= wdata_reg;
				next_state <= WRITE1;
			end
			WRITE1: begin
				winc <= 1'b1;
				wdata <= wdata_reg;
				next_state <= WRITE2;
			end
			WRITE2: begin
				winc <= 1'b1;
				wdata <= wdata_reg;
				next_state <= IDLE;
			end
		endcase
	end
	
	always @(posedge rclk or negedge rrst_n) begin
		if (!rrst_n) begin
			rinc <= 1'b0;
			rdata_reg <= 0;
		end
		else begin
			if (!rempty) begin
				rinc <= 1;
				rdata_reg <= rdata;
			end
			else begin
				rinc <= 0;
			end
		end
	end

endmodule