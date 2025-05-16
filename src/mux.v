module mux(
    input [15:0] in0, in1, in2, in3, in4, in5, in6, in7, imm_val,
    input [3:0] sel,
    output reg [15:0] out
);
    always @(*) begin
        case(sel)
            4'b0000: out = in0;
            4'b0001: out = in1;
            4'b0010: out = in2;
            4'b0011: out = in3;
            4'b0100: out = in4;
            4'b0101: out = in5;
            4'b0110: out = in6;
            4'b0111: out = in7;
            4'b1000: out = imm_val;
            default: out = in0;
            
        endcase 
    end

endmodule