module led_slave
 #(
	parameter N = 3,
	parameter MUX_N = 1,
	parameter ADDR = 0,
	parameter ACT_H = 0
 )
 (
	input		clk,
	input		rst_n,
	input		[13:0]adr,
	input		we,
	input		[7:0]dat_w,
	output reg	[7:0]dat_r,
	output	[N-1:0]leds_wire,
	input		[MUX_N*8-1:0]leds_external_signal	//bit[(i+1)*MUX_N-1:i*MUX_N] is i-th led's external signal
 );
 
	reg [7:0]internal_reg[N:0];
	wire [8:0]reg_addr;
 
	wire[N*(MUX_N+1)-1:0]leds_out_signal;

	genvar i;
	generate
		for (i = 0; i < N; i = i + 1) begin: gen_led_wire_connection
			assign leds_out_signal[i*(MUX_N+1)] = internal_reg[0][i];
			assign leds_out_signal[(i+1)*(MUX_N+1)-1:i*(MUX_N+1)+1] = leds_external_signal[(i+1)*MUX_N-1:i*MUX_N];
			if (ACT_H) begin
				assign leds_wire[i] = leds_out_signal[internal_reg[i+1]];
			end
			else begin
				assign leds_wire[i] = !(leds_out_signal[internal_reg[i+1]]);
			end
			
		end
	endgenerate
 
	integer j;
	initial begin
		for (j = 0; j < N; j = j + 1) begin
			internal_reg[j] = 0;
		end
		dat_r = 8'bzzzzzzzz;
	end
		
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			for (j = 0; j < N; j = j + 1) begin
				internal_reg[j] <= 0;
			end
			dat_r <= 8'bzzzzzzzz;
		end
		else begin
			if (adr[13:9] == ADDR) begin
				if (we) begin
					internal_reg[adr[8:0]] <= dat_w;
					dat_r <= 8'bzzzzzzzz;
				end
				else begin
					dat_r <= internal_reg[adr[8:0]];
				end
			end
		end
	end
	
endmodule