/*
Anthony De Caria - December 28, 2016

This module is a 3 bit adder/subtractor.

It will output B - A if desired.
*/

module adder_subtractor_3bit(a, b, want_subtract, c_out, s);
  
  /*
   * I/Os
   */
  input [2:0] a, b;
  input want_subtract;		// If want_subtract == 1, we subtract. Otherwise we add.
  output [2:0] s;
  output c_out;
  
  wire [1:0]c;
  wire [2:0]a_adder;
  
  mux_2_1bit m_0( .data0(a[0]), .data1(~a[0]), .sel(want_subtract), .result(a_adder[0]) );
  mux_2_1bit m_1( .data0(a[1]), .data1(~a[1]), .sel(want_subtract), .result(a_adder[1]) );
  mux_2_1bit m_2( .data0(a[2]), .data1(~a[2]), .sel(want_subtract), .result(a_adder[2]) );
  
  full_adder_1bit a_0( .a(a_adder[0]), .b(b[0]), .c_in(want_subtract), .c_out(c[0]), .s(s[0]) );
  full_adder_1bit a_1( .a(a_adder[1]), .b(b[1]), .c_in(c[0]), .c_out(c[1]), .s(s[1]) );
  full_adder_1bit a_2( .a(a_adder[2]), .b(b[2]), .c_in(c[1]), .c_out(c_out), .s(s[2]) );
  
endmodule
