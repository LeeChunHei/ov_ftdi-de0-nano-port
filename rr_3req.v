module round_robin_3req(
    input       clk,
    input       rst_n,
    input       request0,
    input       request1,
    input       request2,
    output reg  [1:0]grant,
    input       ce
);

    initial begin
        grant = 0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grant <= 0;
        end
        else begin
            if (ce) begin
                case (grant)
                    0: begin
                        if (request1) begin
                            grant <= 1;
                        end
                        else begin
                            if (request2) begin
                                grant <= 2;
                            end
                            else begin
                            end
                        end
                    end
                    1: begin
                        if (request2) begin
                            grant <= 2;
                        end
                        else begin
                            if (request0) begin
                                grant <= 0;
                            end
                            else begin
                            end
                        end
                    end
                    2: begin
                        if (request0) begin
                            grant <= 0;
                        end
                        else begin
                            if (request1) begin
                                grant <= 1;
                            end
                            else begin
                            end
                        end
                    end
                endcase
            end
        end
    end
endmodule
