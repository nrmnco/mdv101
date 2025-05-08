module mux2to1(
    input [15:0] reg0,
    input [15:0] reg1,
    input sel,
    output reg [15:0] out
);

    always @(*) begin
        if (sel)
            out = reg1;
        else
            out = reg0;
    end

endmodule