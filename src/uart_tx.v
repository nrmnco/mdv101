module uart_tx
#(
    parameter data_width   = 8,
              IDLE         = 3'b000,
              START_BIT    = 3'b001,
              DATA_BITS    = 3'b010,
              STOP_BIT     = 3'b011,
              DONE         = 3'b101
)
(
    input [data_width - 1:0] data_bus,
    input                    clk,
    input                    rstn,
    input [12:0]              CLKS_PER_BIT,
    input                    run,
    output                   done,
    output                   data_bit
);
    // FSM states
    reg [2:0] PS;
    reg [2:0] NS;
    reg [12:0] clk_counter;
    reg [2:0]  bit_counter;
    reg        data_reg;
     
    // Output assignments
    assign done         = PS == DONE;
   
    // FSM: PS synchronization
    always @(posedge clk) begin
        if (!rstn) begin
            PS <= IDLE;
        end
        else begin
            PS <= NS;
        end
    end

    // FSM: Data and control logic
    always @(negedge clk) begin
        // Default values
        data_reg<=1'b1;
        clk_counter<=clk_counter;
        bit_counter<=bit_counter;

        case (PS)
            IDLE: begin
                data_reg <=1'b1;
                bit_counter <=0;
                clk_counter <=0;
                
                if (!run) begin
                    //$display("tx_idle");
                end
            end

            START_BIT: begin
                data_reg <=1'b0;
                
                if (clk_counter < CLKS_PER_BIT - 1) begin
                    clk_counter <=clk_counter + 1'b1;
                end
                else begin
                    clk_counter <=0;
                end
            end

            DATA_BITS: begin
                data_reg <=data_bus[bit_counter];
                
                if (clk_counter < CLKS_PER_BIT - 1) begin
                    clk_counter <=clk_counter + 1'b1;
                end
                else begin
                    clk_counter <=0;
                    
                    if (bit_counter < 7) begin
                        bit_counter <=bit_counter + 1'b1;
                    end
                end
            end

            STOP_BIT: begin
                data_reg <=1'b1;
                
                if (clk_counter < CLKS_PER_BIT - 1) begin
                    clk_counter <=clk_counter + 1'b1;
                end
                else begin
                    clk_counter <=0;
                end
            end

            DONE: begin
                // Reset to initial state
            end

            default: begin
                data_reg <=1'b1;
                clk_counter <=0;
                bit_counter <=0;
            end
        endcase
    end

    
    // Next state transition logic
    always @(negedge clk) begin
        // Default next state
        NS <=PS;

        case (PS)
            IDLE: begin
                NS <=(!run) ? START_BIT : IDLE;
            end

            START_BIT: begin
                NS <=(clk_counter == CLKS_PER_BIT - 1) ? DATA_BITS : START_BIT;
            end

            DATA_BITS: begin
                if (clk_counter == CLKS_PER_BIT - 1) begin
                    if (bit_counter < 7) begin
                        NS <=DATA_BITS;
                    end else begin
                        NS <=STOP_BIT;
                    end
                end
            end

            STOP_BIT: begin
                NS<=(clk_counter == CLKS_PER_BIT - 1) ? DONE : STOP_BIT;
            end

            DONE: begin
                NS<=IDLE;
            end

            default: begin
                NS<=IDLE;
            end
        endcase
    end


    // Output assignment
    assign data_bit = data_reg;
endmodule