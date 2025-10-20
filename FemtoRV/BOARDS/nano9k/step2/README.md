## Step 2: slower blinky

You probably got it right: the blinky can be slowed-down either
by counting on a larger number of bits (and wiring the most
significant bits to the leds), or inserting a "clock divider"
(also called a "gearbox") that counts on a large number
of bits (and driving the counter
with its most significant bit). The second solution is interesting,
because you do not need to modify your design, you just insert
the clock divider between the `CLK` signal of the board and your
design. Then, even on the device you can distinguish what happens
with the LEDs.

To do that, I created a `Clockworks` module in [clockworks.v](../../../TUTORIALS/FROM_BLINKER_TO_RISCV/clockworks.v),
that contains the gearbox and a mechanism related with the `RESET` signal (that
I'll talk about later). `Clockworks` is implemented as follows:
```verilog
module Clockworks 
(
   input  CLK,   // clock pin of the board
   input  RESET, // reset pin of the board
   output clk,   // (optionally divided) clock for the design.
   output resetn // (optionally timed) negative reset for the design (more on this later)
);
   parameter SLOW;
...
   reg [SLOW:0] slow_CLK = 0;
   always @(posedge CLK) begin
      slow_CLK <= slow_CLK + 1;
   end
   assign clk = slow_CLK[SLOW];
...
endmodule
```
This divides clock frequency by `2^SLOW`.

The `Clockworks` module is then inserted
between the `CLK` signal of the board
and the design, using an internal `clk`
signal, as follows, in [step2.v](step2.v):

```verilog
`include "clockworks.v"

module SOC (
    input  CLK,        // system clock 
    input  RESET,      // reset button
    output [4:0] LEDS, // system LEDs
    input  RXD,        // UART receive
    output TXD         // UART transmit
);

   wire clk;    // internal clock
   wire resetn; // internal reset signal, goes low on reset
   
   // A blinker that counts on 5 bits, wired to the 5 LEDs
   reg [4:0] count = 0;
   always @(posedge clk) begin
      count <= !resetn ? 0 : count + 1;
   end

   // Clock gearbox (to let you see what happens)
   // and reset circuitry (to workaround an
   // initialization problem with Ice40)
   Clockworks #(
     .SLOW(21) // Divide clock frequency by 2^21
   )CW(
     .CLK(CLK),
     .RESET(RESET),
     .clk(clk),
     .resetn(resetn)
   );
   
   assign LEDS = count;
   assign TXD  = 1'b0; // not used for now   
endmodule
```
It also handles the `RESET` signal. 

Now you can try it on simulation:
```
  $ yosys step2.ys

  === SOC ===

        +----------Local Count, excluding submodules.
        | 
       70 wires
       99 wire bits
       70 public wires
       99 public wire bits
        5 ports
        9 port bits
       68 cells
        1   $scopeinfo
       27   ALU
       22   DFF
        5   DFFR
        1   GND
        3   IBUF
        2   LUT1
        6   OBUF
        1   VCC
```

As you can see, the counter is now much slower. Try it also on device:
   - Open nano9k.gprj
   - Run all
   - Programmer -> Program/Configure

Yes, now we can see clearly what happens! And what about the `RESET`
button? The Nano9k has a S1 button on `IO_LOC = 3`, that can be used as reset.

**Try this** Knight-driver mode, and `RESET` toggles direction.

If you take a look at [clockworks.v](clockworks.v), you will see it can
also create a `PLL`, it is a component that can be used to generate
*faster* clocks. For instance, the IceStick has a 12 MHz system clock,
but the core that we will generate will run at 45 MHz. We will see that
later.