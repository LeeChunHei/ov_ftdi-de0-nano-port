module timer
#
(
	parameter BITS = 32
)
(
	input			clk,
	input			rst_n,
	input			[BITS-1:0]reload_cnt,
	input			[BITS-1:0]threshold,
	output reg	channel_0
);

reg	[BITS-1:0]counter;

initial begin
	channel_0 = 0;
	counter = 0;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		channel_0 <= 0;
		counter <= 0;
	end
	else begin
		channel_0 <= (counter < threshold) ? 0 : 1;
		counter <= counter + 1;
		if (counter == reload_cnt) begin
			counter <= 0;
		end
	end
end

endmodule