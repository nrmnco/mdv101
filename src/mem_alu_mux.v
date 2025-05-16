module mem_alu_mux (
    input en_mem,
    input [15:0] memory_data, alu_data,
    output reg [15:0] data
);

always @(*) begin
    // $display("en_mem: ", en_mem);
    if (en_mem) begin
        data = memory_data;
    end
    else begin
        data = alu_data;
    end
end

endmodule