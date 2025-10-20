# Step 3: a blinker that loads LEDs patterns from ROM

Now we got all the tools that we need, so let's see how to
transform this blinker into a fully-functional RISC-V
processor. This goal seems to be far far away, but the
processor we will have created at step 16 is not longer
than 200 lines of VERILOG ! I was amazed to discover
that it is that simple to create a processor. OK, let us
go there one step at a time.

We know already that a processor has a memory, and fetches
instructions from there, in a sequential manner most of
the time (except when there are jumps and branches). Let us
start with something similar, but much simpler: a pre-programmed
christmas tinsel, that loads the LEDs pattern from a memory (see
[step4.v](../../../TUTORIALS/FROM_BLINKER_TO_RISCV/step4.v)). Our tinsel has a memory with the patterns:
```verilog
   reg [4:0] MEM [0:20];
   initial begin
       MEM[0]  = 5'b00000;
       MEM[1]  = 5'b00001;
       MEM[2]  = 5'b00010;
       MEM[3]  = 5'b00100;
       ...
       MEM[19] = 5'b10000;
       MEM[20] = 5'b00000;       
   end
```
_Note that what's in the initial block does not generate any circuitry
when synthesized, it is directly translated into the initialization
data for the BRAMs of the FPGA._

We will also have a "program counter" `PC` incremented at each clock, and
a mechanism to fetch `MEM` contents indexed by `PC`:

```verilog
   reg [4:0] PC = 0;
   reg [4:0] leds = 0;

   always @(posedge clk) begin
      leds <= MEM[PC];
      PC <= (!resetn || PC==20) ? 0 : (PC+1);
   end
```
_Note the test `PC==20` to make it cycle._

Now try it with simulation and on device.

**Try this** create several blinking modes, and switch between
  modes using `RESET`.