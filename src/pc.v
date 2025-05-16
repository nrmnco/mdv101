module pc (
    input clk,
    input en_pc, // Enable PC
    input reset, // Active-low reset
    input [7:0] d_in, // Input memory address
    output reg [7:0] d_out // Output memory address
);
    register pc_inst(
        .clk(clk), 
        .reset(reset), 
        .en(en_pc), 
        .d_in(d_in),
        .d_out(d_out)
    );


endmodule
