module E15Counter1HzB(Clk, D, Q);

	input Clk;
	input [3:0] D;
	output [3:0] Q;

	reg [25:0] R;
	reg [3:0] CntOut;
	assign Q=CntOut;

	always @(posedge Clk)
	begin
		if (R<50000000)
			R <= R+26'b1;
		else
			begin
				R <= 26'b0;
				CntOut <= ((CntOut<D) ? CntOut+4'b1 : 4'b0);
			end
	end	

endmodule