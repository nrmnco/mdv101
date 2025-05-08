module fetch_instruction(
    input wire clk,
    input wire reset,
    //input next_instr_en,
    input wire [7:0] address,  // 8-bit address to be sent
    input wire rx_do,          // Signal indicating data received
    input wire [7:0] rx_data,  // Data received from UART
    input wire tx_done,        // Signal indicating transmission is done

    input stop_for_rw,         //Stop the FIU while UART works

    output [15:0] instruction_out, // 16-bit instruction received
    output tx_start_out,       // Signal to start UART transmission
    output [7:0] tx_data_out,  // Data to be transmitted over UART
    output done_out            // Signal indicating the operation is complete
);

    reg [15:0] instruction;    // 16-bit instruction received
    reg tx_start;              // Signal to start UART transmission
    reg [7:0] tx_data;         // Data to be transmitted over UART
    reg done;                  // Signal indicating the operation is complete

    assign done_out = done;
    assign instruction_out = instruction;
    assign tx_start_out = tx_start;
    assign tx_data_out = tx_data;

    // State encoding
    parameter IDLE = 3'b000;
    parameter SEND_FLAG = 3'b001;
    parameter SEND_ADDR = 3'b010;
    parameter RECEIVE_INST_LOW = 3'b100;
    parameter RECEIVE_INST_HIGH = 3'b101;
    parameter DONE = 3'b110;
    
    reg [2:0] state, next_state;

    // Sequential logic for state transition
    always @(posedge clk) begin
        //ff_a <= instruction;
		if (!reset | stop_for_rw==1) begin
			state <= IDLE;
		end
		else begin
			state <= next_state;
		end
    end

    // State machine logic
    /* verilator lint_off LATCH */
    always @(*) begin
        // Default values
        tx_start = 1;  // No transmission by default
        tx_data = 8'b00000000;
        done = 0;
        instruction = instruction;
        case (state)
            IDLE: begin
			   done = 0;
            end

            SEND_FLAG: begin

                tx_data = 8'b00000011;  // Send flag byte
                tx_start = 0;  // Start transmission
            end

            SEND_ADDR: begin
                tx_data = address;  // Send address byte
                tx_start = 0;  // Start transmission
            end

            RECEIVE_INST_HIGH: begin
                if (rx_do) begin
                    instruction[15:8] = rx_data;  // Store lower 8 bits of instruction
                    //$display(instruction);
                end
            end

            RECEIVE_INST_LOW: begin
                if (rx_do) begin
                    instruction[7:0] = rx_data;  // Store upper 8 bits of instruction
                    //$display(instruction);

                end
            end

            DONE: begin
                done = 1;  // Set done signal
            end

            default: begin
				tx_start = 1;  // No transmission by default
                tx_data = 8'b00000000;
                done = 0;
                instruction = instruction;
            end
        endcase
    end

    always @(*) begin
        case (state)
            IDLE: begin
                next_state = SEND_FLAG;
                //$display("idle");
            end
            SEND_FLAG: begin
                /*if(tx_done) begin
                    $display("tx_done in FLAG state");
                end*/
                next_state = (tx_done==1'b1) ? SEND_ADDR:SEND_FLAG; 
            end
            SEND_ADDR: begin
                /*if(tx_done) begin
                    $display("tx_done in ADDR");
                end*/
                next_state = (tx_done==1'b1) ? RECEIVE_INST_HIGH:SEND_ADDR;
            end
            RECEIVE_INST_HIGH: begin
                next_state = (rx_do==1'b1) ? RECEIVE_INST_LOW:RECEIVE_INST_HIGH;
            end
            RECEIVE_INST_LOW:begin 
                next_state = (rx_do==1'b1) ? DONE:RECEIVE_INST_LOW;
            end
            DONE:
            begin
                next_state = IDLE;
                $display("done");
            end
            default: next_state = IDLE;
        endcase 
    end
endmodule
