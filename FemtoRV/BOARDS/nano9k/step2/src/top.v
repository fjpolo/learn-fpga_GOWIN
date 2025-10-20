module top (
    input   wire            i_sys_clk,          // clk input
    input   wire            i_sys_rst_n,        // reset input
    output  wire     [5:0]  o_led,              // 6 LEDS pin
    input                   i_uart_rx,
	output                  o_uart_tx
);

SOC i_soc(
    .CLK(i_sys_clk),
    .RESET(~i_sys_rst_n),
    .LEDS(o_led[4:0]),
    .RXD(i_uart_rx),
    .TXD(o_uart_tx)
);

endmodule
