module bus_encode(
	input			clk,
	input			rst_n,
	input			sink_stb,
	output reg	sink_ack,
	input			sink_wr,
	input			[13:0]sink_a,
	input			[7:0]sink_d,
	output reg	source_stb,
	input			source_ack,
	output reg	[7:0]source_d,
	output reg	source_last
);

//	input		sink_stb;
//	output	sink_ack;
//	input		sink_wr;
//	input		[13:0]sink_a;
//	input		[7:0]sink_d;
//	output	source_stb;
//	input		source_ack;
//	output	[7:0]source_d;
//	output	source_last;

	reg token_wr;
	reg [13:0]token_a;
	reg [7:0]token_d;
	reg next_token_wr;
	reg [13:0]next_token_a;
	reg [7:0]next_token_d;
	reg [7:0]ssum;
	
	reg [2:0]fsm_state;
	
	parameter IDLE		= 3'b000;
	parameter HEADER	= 3'b001;
	parameter ADRH		= 3'b010;
	parameter ADRL		= 3'b011;
	parameter DATA		= 3'b100;
	parameter CKSUM	= 3'b101;

//	assign next_token_wr	= token_wr;
//	assign next_token_a	= token_a;
//	assign next_token_d	= token_d;
	
	initial begin
		fsm_state = IDLE;
	end
	
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			fsm_state <= IDLE;
		end
		else begin
			token_wr	<= next_token_wr;
			token_a	<= next_token_a;
			token_d	<= next_token_d;
						
//			next_token_wr	<= token_wr;
//			next_token_a	<= token_a;
//			next_token_d	<= token_d;
			
			ssum <= 8'h55 + {token_wr, 1'b0, token_a[13:8]} + token_a[7:0] + token_d;
			
			case (fsm_state)
				IDLE: begin
					source_stb <= 0;
					source_last <= 0;
					if (!sink_stb) begin
						sink_ack <= 0;
					end
					else begin
						sink_ack <= 1;
						next_token_wr <= sink_wr;
						next_token_a <= sink_a;
						next_token_d <= sink_d;
						fsm_state = HEADER;
					end
				end
				HEADER: begin
					sink_ack <= 0;
					source_stb <= 1;
					source_last <= 0;
					source_d <= 8'h55;
					if (source_ack) begin
						fsm_state = ADRH;
					end
				end
				ADRH: begin
					sink_ack <= 0;
					source_stb <= 1;
					source_last <= 0;
					source_d <= {token_wr, 1'b0, token_a[13:8]};
					if (source_ack) begin
						fsm_state = ADRL;
					end
				end
				ADRL: begin
					sink_ack <= 0;
					source_stb <= 1;
					source_last <= 0;
					source_d <= token_a[7:0];
					if (source_ack) begin
						fsm_state = DATA;
					end
				end
				DATA: begin
					sink_ack <= 0;
					source_stb <= 1;
					source_last <= 0;
					source_d <= token_d;
					if (source_ack) begin
						fsm_state = CKSUM;
					end
				end
				CKSUM: begin
					sink_ack <= 0;
					source_stb <= 1;
					source_last <= 1;
					source_d <= ssum;
					if (source_ack) begin
						fsm_state = IDLE;
					end
				end
			endcase
		end
	end
endmodule