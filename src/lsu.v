module lsu (
    // General ports
    input  wire        clk,
    input  wire        reset,       // Active-low reset
    output reg         done_out,    // Signal indicating the operation is complete

    // Control and Data ports
    input  wire [1:0]  en_ls,       // Load/Store control signal
    input  wire [7:0]  address,     // 8-bit memory address
    input  wire [15:0] data_to_store, // Data to be sent for storing
    output reg  [15:0] data_to_load,  // Data received from loading

    // Ports for UART Interaction
    input  wire        rx_do,       // Signal indicating data received from UART
    input  wire [7:0]  rx_data,     // Data byte received from UART
    input  wire        tx_done,     // Signal indicating UART transmission is done
    output reg         tx_start_out,    // Signal to start UART transmission (active low)
    output reg  [7:0]  tx_data_out      // Data byte to be transmitted over UART
);

    parameter IDLE = 3'b000;
    parameter SEND_FLAG = 3'b001;
    parameter SEND_ADDR = 3'b010;
    parameter SEND_DATA_HIGH = 3'b011;
    parameter SEND_DATA_LOW = 3'b100;
    parameter RECEIVE_DATA_HIGH = 3'b101;
    parameter RECEIVE_DATA_LOW = 3'b110;
    parameter DONE = 3'b111;

    reg [2:0] current_state, next_state;
    reg [15:0] temp_data;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        case (current_state)
            IDLE: begin
                if (en_ls == 2'b01) begin        // load
                    next_state = SEND_FLAG;
                end else if (en_ls == 2'b10) begin // store
                    next_state = SEND_FLAG;
                end else begin
                    next_state = IDLE;
                end
            end
            
            SEND_FLAG: begin
                if (tx_done) begin
                    next_state = SEND_ADDR;
                end else begin
                    next_state = SEND_FLAG;
                end
            end
            
            SEND_ADDR: begin
                if (tx_done) begin
                    if (en_ls == 2'b01) begin    // load
                        next_state = RECEIVE_DATA_HIGH;
                    end else if (en_ls == 2'b10) begin // store
                        next_state = SEND_DATA_HIGH;
                    end else begin
                        next_state = IDLE;
                    end
                end else begin
                    next_state = SEND_ADDR;
                end
            end
            
            SEND_DATA_HIGH: begin
                if (tx_done) begin
                    next_state = SEND_DATA_LOW;
                end else begin
                    next_state = SEND_DATA_HIGH;
                end
            end
            
            SEND_DATA_LOW: begin
                if (tx_done) begin
                    next_state = DONE;
                end else begin
                    next_state = SEND_DATA_LOW;
                end
            end
            
            RECEIVE_DATA_HIGH: begin
                if (rx_do) begin
                    next_state = RECEIVE_DATA_LOW;
                end else begin
                    next_state = RECEIVE_DATA_HIGH;
                end
            end
            
            RECEIVE_DATA_LOW: begin
                if (rx_do) begin
                    next_state = DONE;
                end else begin
                    next_state = RECEIVE_DATA_LOW;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    always @(*) begin
        // $display("LSU: ", current_state);
        tx_start_out = 1'b1;
        tx_data_out = 8'b0;
        done_out = 1'b0;
        temp_data = 16'b0;
    
        case (current_state)
            IDLE: begin
                tx_start_out = 1'b1;
                done_out = 1'b0;
            end
            
            SEND_FLAG: begin
                tx_data_out = 8'h03;
                tx_start_out = 1'b0;
                // if (tx_start_out) begin
                //     // Set flag byte: 0x01 for load, 0x02 for store
                //     tx_data_out = (en_ls == 2'b01) ? 8'h01 : 8'h02;
                //     tx_start_out = 1'b0;
                // end else if (tx_done) begin
                //     tx_start_out = 1'b1;
                // end
            end
            
            SEND_ADDR: begin
                tx_data_out = address;
                tx_start_out = 1'b0;
                // if (tx_start_out) begin
                //     tx_data_out = address;
                //     tx_start_out = 1'b0;
                // end else if (tx_done) begin
                //     tx_start_out = 1'b1;
                // end
            end
            
            SEND_DATA_HIGH: begin
                tx_data_out = data_to_store[15:8];
                tx_start_out = 1'b0;
                // if (tx_start_out) begin
                //     tx_data_out = data_to_store[15:8];
                //     tx_start_out = 1'b0;
                // end else if (tx_done) begin
                //     tx_start_out = 1'b1;
                // end
            end
            
            SEND_DATA_LOW: begin
                tx_data_out = data_to_store[7:0];
                tx_start_out = 1'b0;
                // if (tx_start_out) begin
                //     tx_data_out = data_to_store[7:0];
                //     tx_start_out = 1'b0;
                // end else if (tx_done) begin
                //     tx_start_out = 1'b1;
                // end
            end
            
            RECEIVE_DATA_HIGH: begin
                if (rx_do) begin
                    temp_data[15:8] = rx_data;
                end
            end
            
            RECEIVE_DATA_LOW: begin
                if (rx_do) begin
                    temp_data[7:0] = rx_data;
                    // data_to_load = {temp_data[15:8], rx_data};
                end
            end
            
            DONE: begin
                done_out = 1'b1;
            end
        endcase
    end
    assign data_to_load = temp_data;

endmodule
