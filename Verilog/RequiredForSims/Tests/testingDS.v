`timescale 1us / 1ps

module testingDS;

	// Inputs
	reg clock;
	reg bt_state;
	reg fpga_rxd;
	reg [15:0] ep01wireIn;
	reg [15:0] ep02wireIn;
	
	parameter uart_cpd = 10'd11;
	parameter uart_timer_cap = 10'd385;

	// Outputs
	wire bt_break;
	wire fpga_txd;
	wire [15:0] ep20wireOut;
	wire [15:0] ep21wireOut;
	wire [15:0] ep22wireOut;
	wire [15:0] ep23wireOut;
	wire [15:0] ep24wireOut;
	wire [15:0] ep25wireOut;
	wire [15:0] ep26wireOut;
	wire [15:0] ep27wireOut;
	wire [15:0] ep28wireOut;
	wire [15:0] ep29wireOut;
	wire [15:0] ep30wireOut;

	// Instantiate the Unit Under Test (UUT)
	FPGA_Bluetooth_connection uut (
		.clock(clock), 
		.bt_state(bt_state),  
		.fpga_txd(fpga_txd), 
		.fpga_rxd(fpga_rxd),
		.uart_cpd(uart_cpd),
		.uart_timer_cap(uart_timer_cap),
		.ep01wireIn(ep01wireIn), 
		.ep02wireIn(ep02wireIn),
		.ep20wireOut(ep20wireOut), 
		.ep21wireOut(ep21wireOut),
		.ep22wireOut(ep22wireOut),
		.ep23wireOut(ep23wireOut),
		.ep24wireOut(ep24wireOut), 
		.ep25wireOut(ep25wireOut),
		.ep26wireOut(ep26wireOut),
		.ep27wireOut(ep27wireOut),
		.ep28wireOut(ep28wireOut),
		.ep29wireOut(ep29wireOut),
		.ep30wireOut(ep30wireOut)
	);
	
	always begin
		#1 clock = !clock;
	end

	initial begin
		// Initialize Inputs
		clock = 0;
		bt_state = 0;
		fpga_rxd = 1;
		ep01wireIn = 0;
		ep02wireIn = 0;

		// Wait 100 us for global reset to finish
		#100;
        
		// Add stimulus here
		#0 ep02wireIn = 16'h0001;
		#100 ep02wireIn = 16'h0002;
		#300 bt_state = 1;
	end
	
endmodule

