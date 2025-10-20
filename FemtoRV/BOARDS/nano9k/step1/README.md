#  Step 1: your first blinky

Let us start and create our first blinky ! Our blinky is implemented as a VERILOG module,
connected to inputs and outputs, as follows ([step1.v](../../../TUTORIALS/FROM_BLINKER_TO_RISCV/step1.v)):
```verilog
   module SOC (
       input  CLK,        
       input  RESET,      
       output [4:0] LEDS, 
       input  RXD,        
       output TXD         
   );

   reg [4:0] count = 0;
   always @(posedge CLK) begin
      count <= count + 1;
   end
   assign LEDS = count;
   assign TXD  = 1'b0; // not used for now

   endmodule
```
We call it SOC (System On Chip), which is a big name for a blinky, but
that's what our blinky will be morphed into after all the steps of
this tutorial. Our SOC is connected to the following signals:

- `CLK` (input) is the system clock.
- `LEDS` (output) is connected to the 5 LEDs of the board.
- `RESET` (input) is a reset button. You'll say that the IceStick
   has no button, but in fact ... (we'll talk about that
   later)
- `RXD` and `TXD` (input,output) connected to the FTDI chip that emulates 
   a serial port through USB. We'll also talk about that
   later.

You can synthesize and send the bitstream to the device as follows:
```
$ yosys step1.ys
```

To flash the board, run [nano9k.gprj](step1/nano9k.gprj), synthesize, place&route and flash.

The five leds will light on... but they are not blinking. Why is this so ?
In fact they are blinking, but it is too fast for you to distinguish anything.

To see something, it is possible to use simulation. To use simulation, we write
a new VERILOG file [bench_iverilog.v](bench_iverilog.v),
with a module `bench` that encapsulates our `SOC`:
```verilog
module bench();
   reg CLK;
   wire RESET = 0; 
   wire [4:0] LEDS;
   reg  RXD = 1'b0;
   wire TXD;

   SOC uut(
     .CLK(CLK),
     .RESET(RESET),
     .LEDS(LEDS),
     .RXD(RXD),
     .TXD(TXD)
   );

   reg[4:0] prev_LEDS = 0;
   initial begin
      CLK = 0;
      forever begin
	 #1 CLK = ~CLK;
	 if(LEDS != prev_LEDS) begin
	    $display("LEDS = %b",LEDS);
	 end
	 prev_LEDS <= LEDS;
      end
   end
endmodule   
```
The module `bench` drives all the signals of our `SOC` (called
`uut` here for "unit under test"). The `forever` loop wiggles
the `CLK` signal and displays the status of the LEDs whenever
it changes.

Now we can start the simulation:
```
  $ iverilog -DBENCH -DBOARD_FREQ=10 bench_iverilog.v step1.v
  $ vvp a.out
```
... but that's a lot to remember, so I created a script for that,
you'll prefer to do:
```
  $ ./run.sh step1.v
```

You will see the LEDs counting. Simulation is precious, it lets
you insert "print" statements (`$display`) in your VERILOG code,
which is not directly possible when you run on the device !

To exit the simulation:
```
  <ctrl><c>
  finish
```
_Note: I developped the first version of femtorv completely on device,
 using only the LEDs to debug because I did not know how to
 use simulation, don't do that, it's stupid !_
 
**Try this** How would you modify [step1.v](../../../TUTORIALS/FROM_BLINKER_TO_RISCV/step1.v) to slow it down
sufficiently for one to see the LEDs blinking ?

**Try this** Can you implement a "Knight driver"-like blinking
pattern instead of counting ?