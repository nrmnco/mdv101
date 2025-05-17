module register(
    input clk,
    input [15:0] d_in,
    input reset,
    input en,
    output reg [15:0] d_out
);
    always @(posedge clk or negedge reset) begin
        if (!reset)
            d_out <= 16'h0000;
        else if (en)
            d_out <= d_in;
    end
endmodule

