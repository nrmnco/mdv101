module branch_logic(
    input [7:0]  address,
    /* verilator lint_off UNUSED */
    input [15:0] instruction,
    input [15:0] last_alu_result,
    /* verilator lint_on UNUSED */
    output reg [7:0] new_pc   // Updated program counter based on branch condition
);

    always @(*) begin
        // $display(instruction[15:0]);
        if (instruction[1:0] == 2'b10) begin
            case(instruction[3:2])
                2'b00: 
                    new_pc = (last_alu_result == 0) ? instruction[11:4] : address + 1; // BIE
                2'b01: 
                    new_pc = (last_alu_result == 1) ? instruction[11:4] : address + 1; // BIG
                2'b10:
                    new_pc = (last_alu_result == 2) ? instruction[11:4] : address + 1; // BIL
                default: 
                    new_pc = address + 1;
            endcase
            // $display(instruction[11:4]);
            // $display(alu_res);
            // $display(pc_out);
        end
        else begin
            new_pc = address + 1;
        end
        // $display(pc_out);
    end


endmodule