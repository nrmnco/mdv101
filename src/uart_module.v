//Top level UART module
module uart_module #(
    parameter data_width = 8
)
(
	input        clk, 
	input        rst,
	input [12:0] clks_per_bit,

	input        rx_data_bit,
	output       rx_done,

	output       tx_data_bit,
	input  [data_width-1:0] data_tx,
	input        tx_en,
	output       tx_done,

	output [data_width-1:0] recieved_data


);


	uart_rx R0(
		.data_bit(rx_data_bit),
		.clk(clk),
		.rst(rst),
    	.CLKS_PER_BIT(clks_per_bit),
		.done(rx_done),
		.data_bus(recieved_data)
	);

	uart_tx T0(
		.data_bus(data_tx),
		.clk(clk),
		.rstn(rst), 
    	.CLKS_PER_BIT(clks_per_bit),
		.run(tx_en), //active when low
		.done(tx_done),
		.data_bit(tx_data_bit)
	);			

endmodule
