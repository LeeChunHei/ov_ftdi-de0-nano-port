module bus_master(
	input			clk,
	input			rst_n,
	input			sink_stb,
	output reg	sink_ack,
	input			sink_wr,
	input			[13:0]sink_a,
	input			[7:0]sink_d,
	output reg	source_stb,
	input			source_ack,
	output reg	source_wr,
	output reg	[13:0]source_a,
	output reg	[7:0]source_d,
	
	output reg	[13:0]adr,
	output reg	we,
	output reg	[7:0]dat_w,
	input			[7:0]dat_r
);

//	input		sink_stb;
//	output	sink_ack;
//	input		sink_wr;
//	input		[13:0]sink_a;
//	input		[7:0]sink_d;
//	output	source_stb;
//	input		source_ack;
//	output	source_wr;
//	output	[13:0]source_a;
//	output	[7:0]source_d;
//	
//	output	[13:0]adr;
//	output	we;
//	output	[7:0]dat_w;
//	input		[7:0]dat_r;

	reg samp_comp;
	
	reg [1:0]fsm_state;
	
	parameter IDLE  = 3'b00;
	parameter READ  = 3'b01;
	parameter WAIT  = 3'b10;

	initial begin
		fsm_state = IDLE;
		sink_ack = 0;
		samp_comp = 0;
		source_stb = 0;
	end	
	
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			fsm_state <= IDLE;
			sink_ack <= 0;
			samp_comp <= 0;
			source_stb <= 0;
		end
		else begin
			if (sink_ack) begin
				source_a <= sink_a;
				source_wr <= sink_wr;
				if (sink_wr) begin
					source_d <= dat_w;
				end
			end
			
			if (samp_comp & !source_wr) begin
				source_d <= dat_r;
			end
			
			case (fsm_state)
				IDLE: begin
					sink_ack <= 0;
					samp_comp <= 0;
					source_stb <= 0;
					if (sink_stb) begin
						sink_ack <= 1;
						we <= sink_wr;
						adr <= sink_a;
						dat_w <= sink_d;
						fsm_state <= READ;
					end
				end
				READ: begin
					sink_ack <= 0;
					samp_comp <= 1;
					source_stb <= 0;
					fsm_state <= WAIT;
				end
				WAIT: begin
					sink_ack <= 0;
					samp_comp <= 0;
					source_stb <= 1;
					if (source_ack) begin
						fsm_state = IDLE;
					end
				end
			endcase
		end
	end
endmodule