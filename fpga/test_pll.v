module test_pll(clk, rst_n, pll_clk, locked);

input clk;
input rst_n;
output pll_clk;
output locked;

pll pll_1(
	.areset(!rst_n),
	.inclk0(clk),
	.c0(pll_clk),
	.locked(locked));

endmodule