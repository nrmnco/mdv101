/*
 * Copyright (c) 2024 Moldir Azhimukhanbet, Maveric Lab
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_bitty (
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [7:0] ui_in,    // Dedicated inputs
    /* verilator lint_off UNDRIVEN */
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    /* verilator lint_off UNDRIVEN */
    output wire [7:0] uio_out,  // IOs: Output path
    /* verilator lint_off UNDRIVEN */
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    //top-module I/O ports assignment

    wire reset;
    wire rx_data_bit;
    wire tx_data_bit;
    wire [1:0] sel_baude_rate;

    assign reset = rst_n;
    assign rx_data_bit = ui_in[0];
    assign sel_baude_rate = ui_in[2:1];

    //Unused output ports assignment to zero
    assign uo_out[7:1] = 7'b0;
    assign uio_out[7:0] = 8'b0;
    assign uio_oe[7:0] = 8'b0;

    /* verilator lint_off UNUSED */
    wire _unused = &{ena, uio_out, uo_out[7:1], 1'b0, uio_oe, uio_in, ui_in[7:3]};

    assign uo_out[0] = tx_data_bit; //output


    //General ports declaration
    wire [7:0] new_pc;  // Declare new_pc as a wire
	wire [7:0] addr;

    wire [15:0] d_out;
    wire done;

    reg [3:0] cur_state, next_state;
	wire tx_done;
    wire rx_done;
    reg en_pc;

    reg run_bitty;
    reg [15:0] mem_out;    
    
    wire [7:0] from_uart_to_modules;
    wire [7:0] data_to_uart_from_fetch;
    wire [7:0] from_bitty_to_uart;
    wire tx_en, tx_en_fiu, tx_en_bitty;
   
	wire fetch_done;
    wire [7:0] tx_data;
    
    reg uart_sel;

    parameter S0 = 4'b0000;
    parameter S1 = 4'b0001;
    parameter S2 = 4'b0010;
    parameter S3 = 4'b0011;
    parameter S4 = 4'b0100;
    parameter S5 = 4'b0101;
    parameter S6 = 4'b0110;
    parameter S7 = 4'b0111;

    //Use in FSM
    reg stop_for_rw;

    // Fetch instruction instance
    fetch_instruction fi_inst(
        .clk(clk),
        .reset(reset),
        .address(addr),  
        .stop_for_rw(stop_for_rw),
        .rx_do(rx_done),          
        .rx_data(from_uart_to_modules),  
        .tx_done(tx_done),        
        .instruction_out(mem_out), 
        .tx_start_out(tx_en_fiu),       
        .tx_data_out(data_to_uart_from_fetch),  
        .done_out(fetch_done)
    );

    reg [12:0] clks_per_bit;
	 
    //Select baud rate of the external device
    always@(*) begin
		case (sel_baude_rate)
			2'b00:clks_per_bit = 5208; //9600
			2'b01:clks_per_bit = 2604; //19200
			2'b10:clks_per_bit = 868; //57600
			2'b11:clks_per_bit = 434; //115200
			default: clks_per_bit = 5208;
		endcase
		
    end

    // UART module instance
    uart_module uart_inst(
        .clk(clk), 
        .rst(reset),
        .clks_per_bit(clks_per_bit),
        .rx_data_bit(rx_data_bit),
        .rx_done(rx_done),
        .tx_data_bit(tx_data_bit),
        .data_tx(tx_data),
        .tx_en(tx_en),
        .tx_done(tx_done),
        .recieved_data(from_uart_to_modules)
    );

    //Branch Logic Instance
	 
	branch_logic bl_inst(
        .address(addr),
        .instruction(mem_out),
        .last_alu_result(d_out),
        .new_pc(new_pc)  // Connect new_pc here
    );

    // PC instance
    pc pc_inst(
        .clk(clk),
        .en_pc(en_pc),
        .reset(reset),
        .d_in(new_pc),   // Use new_pc for the input here
        .d_out(addr)
    );

    wire [7:0] unused_8bit;

    //MUX to select tx_data port for UART
    mux2to1 mux2to1_txdata(
        .reg0({8'b0, data_to_uart_from_fetch}),
        .reg1({8'b0,from_bitty_to_uart}),
        .sel(uart_sel),
        .out({unused_8bit,tx_data})
    );

    wire [14:0] unused_15bit;

    //MUX to select tx_en port for UART
    mux2to1 mux2to1_txen(
        .reg0({15'b0, tx_en_fiu}),
        .reg1({15'b0, tx_en_bitty}),
        .sel(uart_sel),
        .out({unused_15bit, tx_en})
    );

    //Bitty instance
    bitty bitty_inst(
        .clk(clk),
        .reset(reset),
        .run(run_bitty),
        .d_instr(mem_out),
        .rx_data(from_uart_to_modules),
        .rx_done(rx_done),
        .tx_done(tx_done),
        .tx_en(tx_en_bitty),
        .tx_data(from_bitty_to_uart),
        .done(done),
        .d_out(d_out)
    );

    always @(posedge clk) begin
        if(!reset) begin
            cur_state <= S0;
        end
        else begin
            cur_state <= next_state;
        end
    end

   always @(*) begin
         run_bitty = 1'b0;
         en_pc = 1'b0;
         uart_sel = 1'b0;
         stop_for_rw = 1'b0;
        case (cur_state)
            S0: begin
                stop_for_rw = 1'b0;
            end
            S2: begin
                en_pc = 1'b1;
            end 
            S5: begin
                run_bitty = 1'b1;
            end
            S6: begin
                stop_for_rw = 1'b0;
            end
            S7: begin
                uart_sel = 1'b1;
                stop_for_rw = 1'b1;
            end
            default: begin
                 run_bitty = 0;
            end
        endcase
    end

    always @(*) begin
        case(cur_state)
            S0: next_state = (fetch_done==1) ? S1:S0;
            S1: next_state = S2;
            S2: next_state = (mem_out[1:0]==2'b11) ? S3:S4;
            S3: next_state = S5;
            S4: next_state = S5; 
            S5: next_state = (mem_out[1:0]==2'b11) ? S7:S6;
            S6: next_state = (done==1) ? S0:S6;
            S7: next_state = (done==1) ? S0:S7;
            default: next_state = S0;
        endcase
    end

endmodule