# Step 4: the instruction decoder

Now the idea is to have a memory with RISC-V instructions in it, load all instructions
sequentially (like in our christmas tinsel), in an `instr` register, and see how to recognize
among the 11 instructions (and light a different LED in function of the recognized instruction). Each
instruction is encoded in a 32-bits word, and we need to decode the different bits of this word to
recognize the instruction and its parameters.

The [RISC-V reference manual](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMAFDQC/riscv-spec-20191213.pdf)
has all the information that we need summarized in two tables in page 130 (RV32/64G Instruction Set Listings). 

Let us take a look at the big table, first thing to notice is that the 7 LSBs tells you which instruction it is
(there are 10 possibilities, we do not count `FENCE` for now).

```verilog
   reg [31:0] instr;
   ...
   wire isALUreg  =  (instr[6:0] == 7'b0110011); // rd <- rs1 OP rs2   
   wire isALUimm  =  (instr[6:0] == 7'b0010011); // rd <- rs1 OP Iimm
   wire isBranch  =  (instr[6:0] == 7'b1100011); // if(rs1 OP rs2) PC<-PC+Bimm
   wire isJALR    =  (instr[6:0] == 7'b1100111); // rd <- PC+4; PC<-rs1+Iimm
   wire isJAL     =  (instr[6:0] == 7'b1101111); // rd <- PC+4; PC<-PC+Jimm
   wire isAUIPC   =  (instr[6:0] == 7'b0010111); // rd <- PC + Uimm
   wire isLUI     =  (instr[6:0] == 7'b0110111); // rd <- Uimm   
   wire isLoad    =  (instr[6:0] == 7'b0000011); // rd <- mem[rs1+Iimm]
   wire isStore   =  (instr[6:0] == 7'b0100011); // mem[rs1+Simm] <- rs2
   wire isSYSTEM  =  (instr[6:0] == 7'b1110011); // special
```

Besides the instruction type, we need also to decode the arguments of the instruction.
The table on the top distinguishes 6 types of instructions
(`R-type`,`I-type`,`S-type`,`B-type`,`U-type`,`J-type`), depending on the arguments
of the instruction and how they are encoded within the 32 bits of the instruction word.

`R-type` instructions take two source registers `rs1` and `rs2`,
 apply an operation on them and stores the result in a
 third destination register `rd` (`ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`,
 `SRL`, `SRA`, `OR`, `AND`).

 Since RISC-V has 32 registers,
 each of `rs1`,`rs2` and `rd` use 5 bits of the instruction
 word. Interestingly, these are the same bits for all
 instruction formats. Hence, "decoding" `rs1`,`rs2`
 and `rd` is just a matter of drawing some wires
 from the instruction word:
```verilog
   wire [4:0] rs1Id = instr[19:15];
   wire [4:0] rs2Id = instr[24:20];
   wire [4:0] rdId  = instr[11:7];
```

 Then, one needs to recognize among the 10 R-type instructions.
 It is done mostly with the `funct3` field, a 3-bits code. With
 a 3-bits code, one can only encode 8 different instructions, hence
 there is also a `funct7` field (7 MSBs of instruction word). Bit
 30 of the instruction word encodes `ADD`/`SUB` and `SRA`/`SRL`
 (arithmetic right shift with sign expansion/logical right shift).
 The instruction decoder has wires for `funct3` and `funct7`:
```verilog
   wire [2:0] funct3 = instr[14:12];
   wire [6:0] funct7 = instr[31:25];
```

`I-type` instructions take one register `rs1`, an immediate value
`Iimm`, applies an operation on them and stores the result in the
destination register `rd` (`ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`,
`ANDI`, `SLLI`, `SRLI`, `SRAI`).

_Wait a minute:_ there are 10 R-Type instructions but only 9 I-Type
instructions, why is this so ? If you look carefully, you will see
that there is no `SUBI`, but one can instead use `ADDI` with a
negative immediate value. This is a general rule in RISC-V, if an
existing functionality can be used, do not create a new functionality.

As for R-type instructions, the instruction can be distinguished using
`funct3` and `funct7` (and in `funct7`, only the bit 30 of the instruction
word is used, to distinguish `SRAI`/`SRLI` arithmetic and logical right shifts).

The immediate value is encoded in the 12 MSBs of the instruction word,
hence we will draw additional wires to get it:
```verilog
   wire [31:0] Iimm={{21{instr[31]}}, instr[30:20]};
```

As can be seen, bit 31 of the instruction word is repeated 21 times,
this is "sign expansion" (converts a 12-bits signed quantity into
a 32-bits one).

There are four other instruction formats `S-type` (for Store),
`B-type` (for Branch), `U-type` (for Upper immediates that
are left-shifted by 12), and `J-type` (for Jumps). Each
instruction format has a different way of encoding an immediate
value in the instruction word.

To understand what it means, let's get back to Chapter 2, page 16.
The different instruction types correspond to the way _immediate values_ are encoded in them.

| Instr. type | Description                                    | Immediate value encoding                             |
|-------------|------------------------------------------------|------------------------------------------------------|
| `R-type`    | register-register ALU ops. [more on this here](https://www.youtube.com/watch?v=pVWtI0426mU) | None    |
| `I-type`    | register-immediate integer ALU ops and `JALR`. | 12 bits, sign expansion                              |
| `S-type`    | store                                          | 12 bits, sign expansion                              |
| `B-type`    | branch                                         | 12 bits, sign expansion, upper `[31:1]` (bit 0 is 0) |
| `U-type`    | `LUI`,`AUIPC`                                  | 20 bits, upper `31:12` (bits `[11:0]` are 0)         |
| `J-type`    | `JAL`                                          | 12 bits, sign expansion, upper `[31:1]` (bit 0 is 0) |

Note that `I-type` and `S-type` encode the same type of values (but they are taken from different parts of `instr`).
Same thing for `B-type` and `J-type`.

One can decode the different types of immediates as follows:
```verilog
   wire [31:0] Uimm={    instr[31],   instr[30:12], {12{1'b0}}};
   wire [31:0] Iimm={{21{instr[31]}}, instr[30:20]};
   wire [31:0] Simm={{21{instr[31]}}, instr[30:25],instr[11:7]};
   wire [31:0] Bimm={{20{instr[31]}}, instr[7],instr[30:25],instr[11:8],1'b0};
   wire [31:0] Jimm={{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};
```
Note that `Iimm`, `Simm`, `Bimm` and `Jimm` do sign expansion (by copying
bit 31 the required number of times to fill the MSBs).

And that's all for our instruction decoder ! To summarize, the instruction
decoder gets the following information from the instruction word:
- signals isXXX that recognizes among the 11 possible RISC-V instructions
- source and destination registers `rs1`,`rs2` and `rd`
- function codes `funct3` and `funct7`
- the five formats for immediate values (with sign expansion for `Iimm`, `Simm`, `Bimm` and `Jimm`).

Let us now initialize the memory with a few RISC-V instruction and see whether we can recognize them
by lighting a different LED depending on the instruction ([step4.v](../../../TUTORIALS/FROM_BLINKER_TO_RISCV/step4.v)). To do that, we use
the big table in page 130 of the
[RISC-V reference manual](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMAFDQC/riscv-spec-20191213.pdf).
It is a bit painful (we will see easier ways later !). Using the `_` character to separate fields of a binary constant is
especially interesting under this circumstance.

```verilog
   initial begin
      // add x1, x0, x0
      //                    rs2   rs1  add  rd  ALUREG
      MEM[0] = 32'b0000000_00000_00000_000_00001_0110011;
      // addi x1, x1, 1
      //             imm         rs1  add  rd   ALUIMM
      MEM[1] = 32'b000000000001_00001_000_00001_0010011;
      ...
      // lw x2,0(x1)
      //             imm         rs1   w   rd   LOAD
      MEM[5] = 32'b000000000000_00001_010_00010_0000011;
      // sw x2,0(x1)
      //             imm   rs2   rs1   w   imm  STORE
      MEM[6] = 32'b000000_00001_00010_010_00000_0100011;
      // ebreak
      //                                        SYSTEM
      MEM[7] = 32'b000000000001_00000_000_00000_1110011;
   end	   
```

Then we can fetch and recognize the instructions as follows:
```verilog
   always @(posedge clk) begin
      if(!resetn) begin
	 PC <= 0;
      end else if(!isSYSTEM) begin
	 instr <= MEM[PC];
	 PC <= PC+1;
      end
   end
   assign LEDS = isSYSTEM ? 31 : {PC[0],isALUreg,isALUimm,isStore,isLoad};
```
(first led is wired to `PC[0]` so that we will see it blinking even if
 there is the same instruction several times).

As you can see, the program counter is only incremented if instruction
is not `SYSTEM`. For now, the only `SYSTEM` instruction that we support
is `EBREAK`, that halts execution. 

In simulation mode, we can in addition display the name of the recognized instruction
and the fields:
```verilog
`ifdef BENCH   
   always @(posedge clk) begin
      $display("PC=%0d",PC);
      case (1'b1)
	isALUreg: $display("ALUreg rd=%d rs1=%d rs2=%d funct3=%b",rdId, rs1Id, rs2Id, funct3);
	isALUimm: $display("ALUimm rd=%d rs1=%d imm=%0d funct3=%b",rdId, rs1Id, Iimm, funct3);
	isBranch: $display("BRANCH");
	isJAL:    $display("JAL");
	isJALR:   $display("JALR");
	isAUIPC:  $display("AUIPC");
	isLUI:    $display("LUI");	
	isLoad:   $display("LOAD");
	isStore:  $display("STORE");
	isSYSTEM: $display("SYSTEM");
      endcase 
   end
`endif
```

**Try this** run `step4.v` in simulation and on the device. Try initializing the memory with
different RISC-V instruction and test whether the decoder recognizes them.