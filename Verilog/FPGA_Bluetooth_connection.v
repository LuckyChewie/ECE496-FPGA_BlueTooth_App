/*
	Anthony De Caria - September 28, 2016

	This module creates a connection between an ion sensor_stream and a Bluetooth module.
	It assumes input and output wires created by Opal Kelly, and the Bluetooth wires can be abstracted.
	
	Algorithm:
		Starting at #Idle
			If we want_at and the user_data_loaded
				Put the user data into AT_FIFO - #Load_AT_FIFO
				Check with the user - #Rest_AT_FIFO
					If the user doesn't know we stored
						Wait for their response (Stay in #Rest_AT_FIFO)
					If they do
						And they're done loading data
							Go to #Wait_for_MS
						Otherwise
							Go to #Load_AT_FIFO to store it
			Or If we don't want_at, but the datastream_ready
				Let the Master Switch settle down - #Wait_for_MS
				If it is
					Access the Data from the FIFO - #Release_from_FIFO
					Put the data into a buffer for the UART - #Load_Transmission
					If we are to send
						Send it - #Begin_Transmission
						Once the data is transmitted
							Set a timer - #Rest_Transmission
							If the timer does off
								And we have more data to send
									#Wait_for_MS
								If we don't
									But we wanted AT
										#Receive_AT_Response from the receiver_centre
										Once we have it
											We wait for the user to access_RFIFO - #Wait_for_RFIFO_Request
												When they do
													#Read_RFIFO
													Check with the user - #Rest_RFIFO
													If the user doesn't know we pulled out the data
														Wait for their response (Stay in #Rest_RFIFO)
													If they do
														And they're done getting the data
															Go to #Idle
														Otherwise
															Go to #Wait_for_RFIFO_Request
									Else
										Go back to #Idle
							Else
								Wait for it (#Rest_Transmission)
					Else
						Go back to #Idle
				Else
					Wait for it (#Wait_for_MS)
			Else
				Stay in #Idle
*/

module FPGA_Bluetooth_connection(
		clock, 
		bt_state, fpga_txd, fpga_rxd,
		uart_cpd, uart_spacing_limit,
//		sensor_stream0, sensor_stream1, sensor_stream2, sensor_stream3, sensor_stream4, sensor_stream5, sensor_stream6, sensor_stream7,
//		sensor_stream_ready,
		ep01wireIn, ep02wireIn, 
		ep20wireOut, ep21wireOut, ep22wireOut, ep23wireOut, ep24wireOut, 
		ep25wireOut, ep26wireOut, ep27wireOut, ep28wireOut, ep29wireOut,
		ep30wireOut
	);
	
	/*
		I/Os
	*/
	input clock;
	input [9:0] uart_cpd, uart_spacing_limit;
	
	//	FPGA
	input fpga_rxd, bt_state;
	output fpga_txd;
	
	// OK
	input [15:0] ep01wireIn, ep02wireIn;
	output [15:0] ep20wireOut, ep21wireOut, ep22wireOut, ep23wireOut, ep24wireOut; 
	output [15:0] ep25wireOut, ep26wireOut, ep27wireOut, ep28wireOut, ep29wireOut;
	output [15:0] ep30wireOut;
	
	// Sensor
	wire [127:0] sensor_stream0, sensor_stream1, sensor_stream2, sensor_stream3, sensor_stream4, sensor_stream5, sensor_stream6, sensor_stream7;
	wire [7:0] sensor_stream_ready;
	
	/*
		Wires 
	*/
	// General Wires
	wire reset, want_at, access_datastreams;
	wire user_data_loaded, user_knows_stored, user_data_done;
	wire RFIFO_access, user_received_data, finished_with_RFIFO;
	
	// Flags
	wire ds_sending_flag, at_sending_flag, sending_flag, have_at_response, uart_timer_done, tx_done, select_ready, command_from_app;

	// FIFO Wires
	wire [15:0] datastream0, datastream1, datastream2, datastream3, datastream4, datastream5, datastream6, datastream7;
	wire [7:0] at;
	wire [5:0] DS0_rd_count, DS1_rd_count, DS2_rd_count, DS3_rd_count, DS4_rd_count, DS5_rd_count, DS6_rd_count, DS7_rd_count;
	wire [8:0] fifo_state_full, fifo_state_empty, wr_en, rd_en;
	
	// Datastream Selector Wires
	wire [15:0] datastream;
	wire [7:0] uart_input;
	wire [7:0] streams_selected;
	wire [2:0] m_datastream_select;
	
	// UART Timer Wires
	wire [9:0] uart_timer, n_uart_timer;
	wire l_r_uart_timer, r_r_uart_timer;
	
	/*
		General Assignments
	*/
	assign reset = ep02wireIn[0];
	assign access_datastreams = ep02wireIn[1];
	assign want_at = ep02wireIn[2];
	assign user_data_loaded = ep02wireIn[3];
	assign user_knows_stored = ep02wireIn[4];
	assign user_data_done = ep02wireIn[5];
	assign access_RFIFO = ep02wireIn[6];
	assign user_received_data = ep02wireIn[7];
	assign finished_with_RFIFO = ep02wireIn[8];
	
	/*
		FSM Parameters
	*/
	parameter Idle = 4'b0000;
	parameter Wait_for_MS = 4'b0001;
	parameter Load_AT_FIFO = 4'b0010, Rest_AT_FIFO = 4'b0011;
	parameter Release_from_FIFO = 4'b0100, Load_Transmission = 4'b0101, Begin_Transmission = 4'b0110, Rest_Transmission = 4'b0111;
	parameter Receive_AT_Response = 4'b1000, Wait_for_TCS = 4'b1001;
	parameter Wait_for_RFIFO_Request = 4'b1101, Read_RFIFO = 4'b1110, Rest_RFIFO = 4'b1111;
	
	reg [3:0] fbc_curr, fbc_next;
	
	parameter No_Char_Sent = 2'b00, One_Char_Sent = 2'b01, Two_Char_Sent = 2'b10;
	
	reg [1:0] sent_c, sent_n;
	
	/*
		Ion Sensor
	*/	
	wire[109:0] data_out0, data_out1, data_out2, data_out3, data_out4, data_out5, data_out6, data_out7;
	ion sensor0(
		.i0(ep28wireOut[13:8]),
		
		.clock(clock),
		.resetn(~reset),
		.ready(sensor_stream_ready),
		.data_out0(data_out0),
		.data_out1(data_out1),
		.data_out2(data_out2),
		.data_out3(data_out3),
		.data_out4(data_out4),
		.data_out5(data_out5),
		.data_out6(data_out6),
		.data_out7(data_out7)
	);
	
	assign sensor_stream0[7:0] = 8'h00;
	assign sensor_stream0[117:8] = data_out0;
	assign sensor_stream0[119:118] = 2'b00;
	assign sensor_stream0[127:120] = 8'h00;
	
	assign sensor_stream1[7:0] = 8'h01;
	assign sensor_stream1[117:8] = data_out1;
	assign sensor_stream1[119:118] = 2'b00;
	assign sensor_stream1[127:120] = 8'h01;
	
	assign sensor_stream2[7:0] = 8'h02;
	assign sensor_stream2[117:8] = data_out2;
	assign sensor_stream2[119:118] = 2'b00;
	assign sensor_stream2[127:120] = 8'h02;
	
	assign sensor_stream3[7:0] = 8'h03;
	assign sensor_stream3[117:8] = data_out3;
	assign sensor_stream3[119:118] = 2'b00;
	assign sensor_stream3[127:120] = 8'h03;
	
	assign sensor_stream4[7:0] = 8'h04;
	assign sensor_stream4[117:8] = data_out4;
	assign sensor_stream4[119:118] = 2'b00;
	assign sensor_stream4[127:120] = 8'h04;
	
	assign sensor_stream5[7:0] = 8'h05;
	assign sensor_stream5[117:8] = data_out5;
	assign sensor_stream5[119:118] = 2'b00;
	assign sensor_stream5[127:120] = 8'h05;
	
	assign sensor_stream6[7:0] = 8'h06;
	assign sensor_stream6[117:8] = data_out6;
	assign sensor_stream6[119:118] = 2'b00;
	assign sensor_stream6[127:120] = 8'h06;
	
	assign sensor_stream7[7:0] = 8'h07;
	assign sensor_stream7[117:8] = data_out7;
	assign sensor_stream7[119:118] = 2'b00;
	assign sensor_stream7[127:120] = 8'h07;
	
	/*
		Output to Bluetooth
	*/
	//	FIFO	
	assign wr_en[0] = ~fifo_state_full[0] & sensor_stream_ready[0];
	assign rd_en[0] = (fbc_curr == Release_from_FIFO) & (m_datastream_select == 3'b000);
	
	assign wr_en[1] = ~fifo_state_full[1] & sensor_stream_ready[1];
	assign rd_en[1] = (fbc_curr == Release_from_FIFO) & (m_datastream_select == 3'b001);
	
	assign wr_en[2] = ~fifo_state_full[2] & sensor_stream_ready[2];
	assign rd_en[2] = (fbc_curr == Release_from_FIFO) & (m_datastream_select == 3'b010);
	
	assign wr_en[3] = ~fifo_state_full[3] & sensor_stream_ready[3];
	assign rd_en[3] = (fbc_curr == Release_from_FIFO) & (m_datastream_select == 3'b011);
	
	assign wr_en[4] = ~fifo_state_full[4] & sensor_stream_ready[4];
	assign rd_en[4] = (fbc_curr == Release_from_FIFO) & (m_datastream_select == 3'b100);
	
	assign wr_en[5] = ~fifo_state_full[5] & sensor_stream_ready[5];
	assign rd_en[5] = (fbc_curr == Release_from_FIFO) & (m_datastream_select == 3'b101);
	
	assign wr_en[6] = ~fifo_state_full[6] & sensor_stream_ready[6];
	assign rd_en[6] = (fbc_curr == Release_from_FIFO) & (m_datastream_select == 3'b110);
	
	assign wr_en[7] = ~fifo_state_full[7] & sensor_stream_ready[7];
	assign rd_en[7] = (fbc_curr == Release_from_FIFO) & (m_datastream_select == 3'b111);
	
	assign wr_en[8] = (fbc_curr == Load_AT_FIFO);
	assign rd_en[8] = (fbc_curr == Release_from_FIFO) & want_at;
	
	FIFO_centre warehouse(
		.read_clock(clock),
		.write_clock(clock),
		.reset(reset),
		
		.DS0_in(sensor_stream0), .DS1_in(sensor_stream1), .DS2_in(sensor_stream2), .DS3_in(sensor_stream3), 
		.DS4_in(sensor_stream4), .DS5_in(sensor_stream5), .DS6_in(sensor_stream6), .DS7_in(sensor_stream7),
		.DS0_out(datastream0), .DS1_out(datastream1), .DS2_out(datastream2), .DS3_out(datastream3), 
		.DS4_out(datastream4), .DS5_out(datastream5), .DS6_out(datastream6), .DS7_out(datastream7),
		.DS0_rd_count(DS0_rd_count), .DS1_rd_count(DS1_rd_count), .DS2_rd_count(DS2_rd_count), .DS3_rd_count(DS3_rd_count), 
		.DS4_rd_count(DS4_rd_count), .DS5_rd_count(DS5_rd_count), .DS6_rd_count(DS6_rd_count), .DS7_rd_count(DS7_rd_count),
		.DS0_wr_count(), .DS1_wr_count(), .DS2_wr_count(), .DS3_wr_count(), 
		.DS4_wr_count(), .DS5_wr_count(), .DS6_wr_count(), .DS7_wr_count(),
		
		.AT_in(ep01wireIn),
		.AT_out(at),
		.AT_rd_count(),
		.AT_wr_count(),
		
		.write_enable(wr_en),
		.read_enable(rd_en),
		
		.full_flag(fifo_state_full), 
		.empty_flag(fifo_state_empty)
	);
	
	// Datastream Selector
	wire all_at_data_sent, ds_data_exists, both_chars_sent;
	assign all_at_data_sent = fifo_state_empty[8];
	assign ds_data_exists = (fifo_state_empty[7:0] != 8'hFF) ? 1'b1 : 1'b0;
	
	assign ds_sending_flag = access_datastreams & command_from_app & ds_data_exists;
	assign at_sending_flag = ~all_at_data_sent;
	
	mux_2_1bit m_sending_flag(.data0(ds_sending_flag), .data1(at_sending_flag), .sel(want_at), .result(sending_flag) );
	
	assign both_chars_sent = (sent_c == Two_Char_Sent);
	
	master_switch_ece496 control_valve(
		.clock(clock),
		.resetn(~reset),
		.sending_flag(sending_flag),
		.both_chars_sent(both_chars_sent),
		.selected_streams(streams_selected),
		.empty_fifo_flags(fifo_state_empty[7:0]),
		.mux_select(m_datastream_select),
		.select_ready(select_ready),
		
		.DS0_rd_count(DS0_rd_count), .DS1_rd_count(DS1_rd_count), .DS2_rd_count(DS2_rd_count), .DS3_rd_count(DS3_rd_count), 
		.DS4_rd_count(DS4_rd_count), .DS5_rd_count(DS5_rd_count), .DS6_rd_count(DS6_rd_count), .DS7_rd_count(DS7_rd_count),
		
		.ms_curr(ep28wireOut[2:0]), .ms_next(ep28wireOut[6:4])
	);

	mux_8_16bit m_datastream(
		.data0(datastream0), 
		.data1(datastream1), 
		.data2(datastream2), 
		.data3(datastream3), 
		.data4(datastream4), 
		.data5(datastream5), 
		.data6(datastream6), 
		.data7(datastream7),
		.sel(m_datastream_select), 
		.result(datastream) 
	);
	
	wire [7:0] datastream_high_8, datastream_low_8;
	wire [1:0] uart_select;
	wire l_r_datastream, r_r_datastream, send_high;
	assign l_r_datastream = (fbc_curr == Load_Transmission);
	assign r_r_datastream = ~(reset | (fbc_curr == Wait_for_MS));
	assign send_low = (sent_c == One_Char_Sent);
	assign uart_select[0] = send_low;
	assign uart_select[1] = want_at;
	
	register_8bit_enable_async r_datastream_high(.clk(clock), .resetn(r_r_datastream), .enable(l_r_datastream), .select(l_r_datastream), .d(datastream[15:8]), .q(datastream_high_8) );
	register_8bit_enable_async r_datastream_low(.clk(clock), .resetn(r_r_datastream), .enable(l_r_datastream), .select(l_r_datastream), .d(datastream[7:0]), .q(datastream_low_8) );
	mux_3_8bit m_uart_select(.data0(datastream_high_8), .data1(datastream_low_8), .data2(at), .sel(uart_select), .result(uart_input) );
	
	//	UART Timer
	assign l_r_uart_timer = (fbc_curr == Rest_Transmission);
	assign r_r_uart_timer = ~(reset | (fbc_curr == Idle) | (fbc_curr == Release_from_FIFO) | (fbc_curr == Begin_Transmission) ) ;
	
	adder_subtractor_10bit a_uart_timer(.a(uart_timer), .b(10'b0000000001), .want_subtract(1'b0), .c_out(), .s(n_uart_timer) );
	register_10bit_enable_async r_uart_timer(.clk(clock), .resetn(r_r_uart_timer), .enable(l_r_uart_timer), .select(l_r_uart_timer), .d(n_uart_timer), .q(uart_timer) );
	
	assign uart_timer_done = (uart_timer == uart_spacing_limit) ? 1'b1 : 1'b0;

	//	UART
	wire start_tx;
	assign start_tx = (fbc_curr == Begin_Transmission);
	
	UART_tx tx(
		.clk(clock), 
		.resetn(~reset), 
		.start(start_tx), 
		.cycles_per_databit(uart_cpd), 
		.tx_line(fpga_txd), 
		.tx_data(uart_input), 
		.tx_done(tx_done)
	);
	
	/*
		Input from Bluetooth
	*/	
	wire [15:0] RFIFO_out;
	wire [7:0] RFIFO_wr_count;
	wire [6:0] RFIFO_rd_count;
	wire RFIFO_rd_en;
	
	assign RFIFO_rd_en = (fbc_curr == Read_RFIFO);
	
	receiver_centre Purolator(
		.clock(clock), 
		.reset(reset),
		
		.fpga_rxd(fpga_rxd),

		.uart_cpd(uart_cpd),
		.uart_spacing_limit(uart_spacing_limit),
		
		.at_response_flag(have_at_response),
		
		.RFIFO_rd_en(RFIFO_rd_en),
		.RFIFO_out(RFIFO_out), 
		.RFIFO_wr_count(RFIFO_wr_count), 
		.RFIFO_rd_count(RFIFO_rd_count), 
		.RFIFO_full(), 
		.RFIFO_empty(),
		
		.stream_select(streams_selected),
		.ds_sending_flag(command_from_app),
		
		.want_at(want_at),
		
		.commands(ep27wireOut[7:0]), .operands(ep27wireOut[15:8])
	);
	
	/*
		FSM
	*/
	// Idle Signals
	wire datastream_ready;
	assign datastream_ready = ds_sending_flag;
	
	// Begin_Transmission Signals
	wire is_bt_done;
	assign is_bt_done = tx_done;
	
	// Rest_Transmission Signals
	wire all_data_sent;
	mux_2_1bit m_all_data_sent(.data0(~ds_data_exists), .data1(all_at_data_sent), .sel(want_at), .result(all_data_sent) );
	
	always@(*)
	begin
		case(fbc_curr)
			Idle: 
			begin
				if(want_at)
				begin
					if(user_data_loaded)
						fbc_next = Load_AT_FIFO;
					else
						fbc_next = Idle;
				end
				else
				begin
					if(datastream_ready)
						fbc_next = Wait_for_MS;
					else
						fbc_next = Idle;
				end
			end
			
			Load_AT_FIFO:
			begin
				fbc_next = Rest_AT_FIFO;
			end
			
			Rest_AT_FIFO:
			begin
				if(user_knows_stored)
				begin
					if(user_data_done)
						fbc_next = Release_from_FIFO;
					else
						fbc_next = Idle;
				end
				else
					fbc_next = Rest_AT_FIFO;
			end
			
			Wait_for_MS:
			begin
				if(select_ready)
					fbc_next = Release_from_FIFO;
				else
					fbc_next = Wait_for_MS;
			end
			
			Release_from_FIFO:
			begin
				if(sending_flag)
					fbc_next = Load_Transmission;
				else
					fbc_next = Idle;
			end
			
			Load_Transmission:
			begin
				fbc_next = Begin_Transmission;
			end
			
			Begin_Transmission:
			begin
				if(is_bt_done)
					fbc_next = Rest_Transmission;
				else
					fbc_next = Begin_Transmission;
			end
			
			Rest_Transmission:
			begin
				if(uart_timer_done)
				begin
					if(!want_at)
					begin
						if(sent_c == No_Char_Sent)
						begin
							fbc_next = Begin_Transmission;
						end
						else
						begin
							if(all_data_sent)
								fbc_next = Idle;
							else
								fbc_next = Wait_for_TCS;
						end
					end
					else
					begin
						if(all_data_sent)
							fbc_next = Receive_AT_Response; 
						else
							fbc_next = Release_from_FIFO;
					end
				end
				else
					fbc_next = Rest_Transmission;
			end
			
			Wait_for_TCS:
			begin
				if(sent_c == Two_Char_Sent)
					fbc_next = Wait_for_MS;
				else
					fbc_next = Wait_for_TCS;
			end
			
			Receive_AT_Response:
			begin
				if(have_at_response)
					fbc_next = Wait_for_RFIFO_Request;
				else
					fbc_next = Receive_AT_Response;
			end
			
			Wait_for_RFIFO_Request:
			begin
				if(access_RFIFO)
					fbc_next = Read_RFIFO;
				else
					fbc_next = Wait_for_RFIFO_Request;
			end
			
			Read_RFIFO:
			begin
				fbc_next = Rest_RFIFO;
			end
			
			Rest_RFIFO:
			begin
				if(user_received_data)
				begin
					if(finished_with_RFIFO)
						fbc_next = Idle;
					else
						fbc_next = Wait_for_RFIFO_Request;
				end
				else
					fbc_next = Rest_RFIFO;
			end
			
			default:
			begin
				fbc_next = Idle;
			end
		endcase
	end
	
	always@(*)
	begin
		case(sent_c)
			No_Char_Sent:
			begin
				if( (fbc_curr == Rest_Transmission) && !want_at && uart_timer_done)
					sent_n = One_Char_Sent;
				else
					sent_n = No_Char_Sent;
			end
			One_Char_Sent:
			begin
				if(fbc_curr == Rest_Transmission && uart_timer_done)
					sent_n = Two_Char_Sent;
				else
					sent_n = One_Char_Sent;
			end
			Two_Char_Sent:
			begin
				sent_n = No_Char_Sent;
			end
		endcase
	end
	
	always@(posedge clock or posedge reset)
	begin
		if(reset)
		begin
			fbc_curr <= Idle;
			sent_c <= No_Char_Sent;
		end
		else
		begin
			fbc_curr <= fbc_next;
			sent_c <= sent_n;
		end
	end
	
	/*
		WireOut Assignments
	*/
	assign ep20wireOut = RFIFO_out;
	
	assign ep21wireOut[15:8] = 8'h00;
	assign ep21wireOut[7:0] = RFIFO_wr_count[7:0];
	
	assign ep22wireOut[15:7] = 9'h000;
	assign ep22wireOut[6:0] = RFIFO_rd_count[6:0];
	
	assign ep23wireOut = ep01wireIn;
	
	assign ep24wireOut = ep02wireIn;
	
	// User Signals
	wire data_stored_for_user, data_ready_for_user;
	assign data_stored_for_user = (fbc_curr == Rest_AT_FIFO);
	assign data_ready_for_user = (fbc_curr == Rest_RFIFO);
	
	assign ep25wireOut[0] = fbc_curr[0];
	assign ep25wireOut[1] = fbc_curr[1];
	assign ep25wireOut[2] = fbc_curr[2];
	assign ep25wireOut[3] = fbc_curr[3];
	assign ep25wireOut[4] = fbc_next[0];
	assign ep25wireOut[5] = fbc_next[1];
	assign ep25wireOut[6] = fbc_next[2];
	assign ep25wireOut[7] = fbc_next[3];
	assign ep25wireOut[8] = data_stored_for_user;
	assign ep25wireOut[9] = data_ready_for_user;
	assign ep25wireOut[11:10] = uart_select;
	assign ep25wireOut[13:12] = sent_c;
	assign ep25wireOut[15:14] = sent_n;
	
	assign ep26wireOut[15:13] = m_datastream_select;
	assign ep26wireOut[12:11] = rd_en[1:0];
	assign ep26wireOut[10:4] = DS0_rd_count;
	assign ep26wireOut[3] = ds_data_exists;
	assign ep26wireOut[2] = command_from_app;
	assign ep26wireOut[1] = access_datastreams;
	assign ep26wireOut[0] = ds_sending_flag;
	
//	assign ep28wireOut = uart_timer;

	assign ep28wireOut[3] = 1'b0;
	assign ep28wireOut[7] = 1'b0;
	
	assign ep29wireOut[7:0] = sensor_stream_ready;
	assign ep29wireOut[15:8] = fifo_state_empty[7:0];
	
	assign ep30wireOut = datastream;

endmodule

