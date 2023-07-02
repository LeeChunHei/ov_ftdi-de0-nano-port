module bus_decode(
	input			clk,
	input			rst_n,
	input			sink_stb,
	output reg	sink_ack,
	input			[7:0]sink_d,
	output reg	source_stb,
	input			source_ack,
	output reg	source_wr,
	output reg	[13:0]source_a,
	output reg	[7:0]source_d
);

//	input		sink_stb;
//	output	sink_ack;
//	input		[7:0]sink_d;
//	output	source_stb;
//	input		source_ack;
//	output	source_wr;
//	output	[13:0]source_a;
//	output	[7:0]source_d;

	reg next_source_wr;
	reg [13:0]next_source_a;
	reg [7:0]next_source_d;
	
	reg [2:0]fsm_state;
	reg [2:0]fsm_next_state;
	
	parameter IDLE  = 3'b000;
	parameter ADRH  = 3'b001;
	parameter ADRL  = 3'b010;
	parameter DATA  = 3'b011;
	parameter CKSUM = 3'b100;
	parameter ISSUE = 3'b101;

//	assign next_source_wr = source_wr;
//	assign next_source_a = source_a;
//	assign next_source_d = source_d;
		
	initial begin
		fsm_state = IDLE;
		sink_ack = 0;
		source_stb = 0;
	end
	
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			fsm_state <= IDLE;
			sink_ack <= 0;
			source_stb <= 0;
		end
		else begin
			source_wr <= next_source_wr;
			source_a <= next_source_a;
			source_d <= next_source_d;
						
//			next_source_wr <= source_wr;
//			next_source_a  <= source_a;
//			next_source_d  <= source_d;
			
			case (fsm_state)
				IDLE: begin
					sink_ack <= 1;
					source_stb <= 0;
					if (sink_stb) begin
						if (sink_d == 8'h55) begin
							fsm_state <= ADRH;
						end
					end
				end
				ADRH: begin
					sink_ack <= 1;
					source_stb <= 0;
					if (sink_stb) begin
						fsm_state <= ADRL;
						next_source_wr <= sink_d[7];
						next_source_a[13:8] <= sink_d[5:0];
					end
				end
				ADRL: begin
					sink_ack <= 1;
					source_stb <= 0;
					if (sink_stb) begin
						fsm_state <= DATA;
						next_source_a[7:0] <= sink_d;
					end
				end
				DATA: begin
					sink_ack <= 1;
					source_stb <= 0;
					if (sink_stb) begin
						fsm_state <= CKSUM;
						next_source_d <= sink_d;
					end
				end
				CKSUM: begin
					sink_ack <= 1;
					source_stb <= 0;
					if (sink_stb) begin
						fsm_state <= ISSUE;
					end
				end
				ISSUE: begin
					sink_ack <= 0;
					source_stb <= 1;
					if (source_ack) begin
						fsm_state <= IDLE;
					end
				end
			endcase
		end
	end
endmodule