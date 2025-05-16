module alu(
    input [15:0] in_a, in_b,
    input [2:0] sel,
    output reg [15:0] out
);

    always @(*) begin
        case(sel)
            3'b000: out = in_a + in_b;
            3'b001: out = in_a - in_b;
            3'b010: out = in_a & in_b;
            3'b011: out = in_a | in_b;
            3'b100: out = in_a ^ in_b;
            3'b101: out = in_a << in_b;
            3'b110: out = in_a >> in_b;
            3'b111: out = (in_a == in_b) ? 16'h0000 : (in_a > in_b) ? 16'h0001 : 16'h0002;
        endcase
        // $display("out: ", out);
    end
endmodule