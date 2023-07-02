module bus_interleave_3ports(
	input			clk,
	input			rst_n,
	// port 0 sink
	input			sink_0_stb,
	output reg	sink_0_ack,
	input			[7:0]sink_0_d,
	input			sink_0_last,
	// port 1 sink
	input			sink_1_stb,
	output reg	sink_1_ack,
	input			[7:0]sink_1_d,
	input			sink_1_last,
	// port 2 sink
	input			sink_2_stb,
	output reg	sink_2_ack,
	input			[7:0]sink_2_d,
	input			sink_2_last,
	// source
	output reg	source_stb,
	input			source_ack,
	output reg	[7:0]source_d,
	output reg	source_last
);

	wire [1:0]granted;
	reg release_wire;
	wire request;
	reg released;
	wire ce;
	reg grant_to_0;
	reg grant_to_1;
	reg grant_to_2;

	assign request = sink_0_stb | sink_1_stb | sink_2_stb;
	assign ce = request & released;
	
	rr_3req rr(
		.clk(clk),
		.rst_n(rst_n),
		.request0(sink_0_stb),
		.request1(sink_1_stb),
		.request2(sink_2_stb),
		.grant(granted),
		.ce(ce)
	);
	
	initial begin
		released = 1;
	end

	always @(*) begin
		// port 0
		grant_to_0 = (granted == 0) & !ce;
		if ((granted == 0) & !ce) begin
			source_d = sink_0_d;
			release_wire = source_ack & sink_0_stb & sink_0_last;
			source_stb = sink_0_stb;
		end
		sink_0_ack = source_ack & grant_to_0;
		// port 1
		grant_to_1 = (granted == 1) & !ce;
		if ((granted == 1) & !ce) begin
			source_d = sink_1_d;
			release_wire = source_ack & sink_1_stb & sink_1_last;
			source_stb = sink_1_stb;
		end
		sink_1_ack = source_ack & grant_to_1;
		// port 2
		grant_to_2 = (granted == 2) & !ce;
		if ((granted == 2) & !ce) begin
			source_d = sink_2_d;
			release_wire = source_ack & sink_2_stb & sink_2_last;
			source_stb = sink_2_stb;
		end
		sink_2_ack = source_ack & grant_to_2;
	end
	
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			released <= 1;
		end
		else begin
			if (ce) begin
				released <= 0;
			end
			else if (release_wire) begin
				released <= 1;
			end
		end
	end
endmodule