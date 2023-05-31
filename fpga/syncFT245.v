module syncFT245(
	io_clk,
	io_d,
	io_rxf_n,
	io_txe_n,
	io_rd_n,
	io_wr_n,
	io_siwua_n,
	io_oe_n,
	rst,
	sys_clk
);

	input  io_clk;   // 50 MHz clock input
	output [9:0]LED;  // LED's will represent input and output of adder
	
	wire cout1;
	wire [3:0]Q;    // output from counter and input to adder
	wire [2:0]sum;  // output from adder

	assign LED[9:6] = Q;    // output from counter and input to adder
	assign LED[5:3] = 3'b0; // turn off these LED's
	assign LED[2:0] = sum;  // output from adder

	// Instantiate counter
	E15Counter1HzB myCounter(CLOCK_50, 4'd15, Q);  // count from 0 to 15.

	// create a two bit adder, a half adder and a full adder
	hadd myHalfAdder(Q[0], Q[2], cout1, sum[0]);			// Add low bits
	fadd myFullAdder(Q[1], Q[3], cout1, sum[2], sum[1]);// Add high bits

endmodule