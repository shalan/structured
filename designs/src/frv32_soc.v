/******************************************************************************/
// Complete FemtoRV32 SoC with SPI Flash, RAM, UART, GPIO, Timer, and PWM
//
// This file combines:
//   - FemtoRV32 "Gracilis" RV32IMC CPU core
//   - MappedSPIFlash controller
//   - buart (Basic UART)
//   - GPIO (2x8-bit ports with direction control)
//   - Timer (32-bit with prescaler, compare, interrupt)
//   - PWM (4 channels, 16-bit resolution)
//   - ASIC top-level wrapper (sasic_top)
//
// Memory Map:
//   0x0000 - 0x1FFF : SPI Flash (read-only, 8KB addressable)
//   0x2000 - 0x21FF : RAM (128 words x 32 bits = 512 bytes)
//   0x4000          : UART Data Register (R/W)
//   0x4004          : UART Status Register (RO: bit[0]=rx_valid, bit[1]=tx_busy)
//   0x5000          : GPIO_A Data Register (R/W)
//   0x5004          : GPIO_A Direction Register (R/W, 0=input, 1=output)
//   0x5008          : GPIO_B Data Register (R/W)
//   0x500C          : GPIO_B Direction Register (R/W, 0=input, 1=output)
//   0x6000          : TIMER Control Register (bit[0]=enable, bit[1]=reset, bit[2]=irq_enable)
//   0x6004          : TIMER Prescaler Register
//   0x6008          : TIMER Counter Register (R/W)
//   0x600C          : TIMER Compare Register
//   0x7000-0x701C   : PWM Channels 0-3 (16-bit each, 2 registers per channel)
//
// IO Pin Assignment (40 pins total):
//   IO  0: UART TX (output)
//   IO  1: UART RX (input)
//   IO  2: SPI Flash CLK (output)
//   IO  3: SPI Flash CS_N (output)
//   IO  4: SPI Flash MOSI (output)
//   IO  5: SPI Flash MISO (input)
//   IO  6-13: GPIO Port A (8 bits, configurable direction)
//   IO 14-21: GPIO Port B (8 bits, configurable direction)
//   IO 22-25: PWM Channels 0-3 (outputs)
//   IO 26-39: Unused (inputs, reserved for future use)
//
// Bruno Levy, Matthias Koch, Clifford Wolf, 2020-2021
// Extended by Mohamed Shalan, 2025
/******************************************************************************/

// Firmware generation flags for this processor
`define NRV_ARCH     "rv32imac"
`define NRV_ABI      "ilp32"
`define NRV_OPTIMIZE "-O3"
`define NRV_INTERRUPTS
//`define MUL
//`define DIV

// SPI Flash configuration
`define SPI_FLASH_FAST_READ
`define SPI_FLASH_DUMMY_CLOCKS 8

/******************************************************************************/
// FemtoRV32 CPU Core
/******************************************************************************/

module FemtoRV32(
   input          clk,

   output [31:0] mem_addr,  // address bus
   output [31:0] mem_wdata, // data to be written
   output  [3:0] mem_wmask, // write mask for the 4 bytes of each word
   input  [31:0] mem_rdata, // input lines for both data and instr
   output        mem_rstrb, // active to initiate memory read (used by IO)
   input         mem_rbusy, // asserted if memory is busy reading value
   input         mem_wbusy, // asserted if memory is busy writing value

   input         interrupt_request,

   input         reset      // set to 0 to reset the processor
);

   parameter RESET_ADDR       = 32'h00000000;
   parameter ADDR_WIDTH       = 16;

   /***************************************************************************/
   // Instruction decoding.
   /***************************************************************************/

   // Extracts rd,rs1,rs2,funct3,imm and opcode from instruction.
   // Reference: Table page 104 of:
   // https://content.riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf

   // The destination register
   wire [4:0] rdId = instr[11:7];

   // The ALU function, decoded in 1-hot form (doing so reduces LUT count)
   // It is used as follows: funct3Is[val] <=> funct3 == val
   (* onehot *)
   wire [7:0] funct3Is = 8'b00000001 << instr[14:12];

   // The five imm formats, see RiscV reference (link above), Fig. 2.4 p. 12
   wire [31:0] Uimm={    instr[31],   instr[30:12], {12{1'b0}}};
   wire [31:0] Iimm={{21{instr[31]}}, instr[30:20]};
   /* verilator lint_off UNUSED */ // MSBs of SBJimms not used by addr adder.
   wire [31:0] Simm={{21{instr[31]}}, instr[30:25],instr[11:7]};
   wire [31:0] Bimm={{20{instr[31]}}, instr[7],instr[30:25],instr[11:8],1'b0};
   wire [31:0] Jimm={{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};
   /* verilator lint_on UNUSED */

   // Base RISC-V (RV32I) has only 10 different instructions !
   wire isLoad    =  (instr[6:2] == 5'b00000); // rd <- mem[rs1+Iimm]
   wire isALUimm  =  (instr[6:2] == 5'b00100); // rd <- rs1 OP Iimm
   wire isAUIPC   =  (instr[6:2] == 5'b00101); // rd <- PC + Uimm
   wire isStore   =  (instr[6:2] == 5'b01000); // mem[rs1+Simm] <- rs2
   wire isALUreg  =  (instr[6:2] == 5'b01100); // rd <- rs1 OP rs2
   wire isLUI     =  (instr[6:2] == 5'b01101); // rd <- Uimm
   wire isBranch  =  (instr[6:2] == 5'b11000); // if(rs1 OP rs2) PC<-PC+Bimm
   wire isJALR    =  (instr[6:2] == 5'b11001); // rd <- PC+4; PC<-rs1+Iimm
   wire isJAL     =  (instr[6:2] == 5'b11011); // rd <- PC+4; PC<-PC+Jimm
   wire isSYSTEM  =  (instr[6:2] == 5'b11100); // rd <- CSR <- rs1/uimm5

   wire isALU = isALUimm | isALUreg;

   /***************************************************************************/
   // The register file.
   /***************************************************************************/

   reg [31:0] rs1;
   reg [31:0] rs2;
   reg [31:0] registerFile [31:0];

   always @(posedge clk) begin
     if (writeBack)
       if (rdId != 0)
         registerFile[rdId] <= writeBackData;
   end

   /***************************************************************************/
   // The ALU. Does operations and tests combinatorially, except divisions.
   /***************************************************************************/

   // First ALU source, always rs1
   wire [31:0] aluIn1 = rs1;

   // Second ALU source, depends on opcode:
   //    ALUreg, Branch:     rs2
   //    ALUimm, Load, JALR: Iimm
   wire [31:0] aluIn2 = isALUreg | isBranch ? rs2 : Iimm;

   wire aluWr;               // ALU write strobe, starts dividing.

   // The adder is used by both arithmetic instructions and JALR.
   wire [31:0] aluPlus = aluIn1 + aluIn2;

   // Use a single 33 bits subtract to do subtraction and all comparisons
   // (trick borrowed from swapforth/J1)
   wire [32:0] aluMinus = {1'b1, ~aluIn2} + {1'b0,aluIn1} + 33'b1;
   wire        LT  = (aluIn1[31] ^ aluIn2[31]) ? aluIn1[31] : aluMinus[32];
   wire        LTU = aluMinus[32];
   wire        EQ  = (aluMinus[31:0] == 0);

   /***************************************************************************/

   // Use the same shifter both for left and right shifts by
   // applying bit reversal

   wire [31:0] shifter_in = funct3Is[1] ?
     {aluIn1[ 0], aluIn1[ 1], aluIn1[ 2], aluIn1[ 3], aluIn1[ 4], aluIn1[ 5],
      aluIn1[ 6], aluIn1[ 7], aluIn1[ 8], aluIn1[ 9], aluIn1[10], aluIn1[11],
      aluIn1[12], aluIn1[13], aluIn1[14], aluIn1[15], aluIn1[16], aluIn1[17],
      aluIn1[18], aluIn1[19], aluIn1[20], aluIn1[21], aluIn1[22], aluIn1[23],
      aluIn1[24], aluIn1[25], aluIn1[26], aluIn1[27], aluIn1[28], aluIn1[29],
      aluIn1[30], aluIn1[31]} : aluIn1;

   /* verilator lint_off WIDTH */
   wire [31:0] shifter =
               $signed({instr[30] & aluIn1[31], shifter_in}) >>> aluIn2[4:0];
   /* verilator lint_on WIDTH */

   wire [31:0] leftshift = {
     shifter[ 0], shifter[ 1], shifter[ 2], shifter[ 3], shifter[ 4],
     shifter[ 5], shifter[ 6], shifter[ 7], shifter[ 8], shifter[ 9],
     shifter[10], shifter[11], shifter[12], shifter[13], shifter[14],
     shifter[15], shifter[16], shifter[17], shifter[18], shifter[19],
     shifter[20], shifter[21], shifter[22], shifter[23], shifter[24],
     shifter[25], shifter[26], shifter[27], shifter[28], shifter[29],
     shifter[30], shifter[31]};

   /***************************************************************************/

   wire funcM     = instr[25];
   wire isDivide = isALUreg & funcM & instr[14];
   wire aluBusy   = |quotient_msk; // ALU is busy if division is in progress.

   // funct3: 1->MULH, 2->MULHSU  3->MULHU
   wire isMULH   = funct3Is[1];
   wire isMULHSU = funct3Is[2];

   wire sign1 = aluIn1[31] &  isMULH;
   wire sign2 = aluIn2[31] & (isMULH | isMULHSU);

   wire signed [32:0] signed1 = {sign1, aluIn1};
   wire signed [32:0] signed2 = {sign2, aluIn2};
`ifdef MUL
   wire signed [63:0] multiply = signed1 * signed2;
`else
   wire signed [63:0] multiply = 'b0;
`endif


   /***************************************************************************/

   // Notes:
   // - instr[30] is 1 for SUB and 0 for ADD
   // - for SUB, need to test also instr[5] to discriminate ADDI:
   //    (1 for ADD/SUB, 0 for ADDI, and Iimm used by ADDI overlaps bit 30 !)
   // - instr[30] is 1 for SRA (do sign extension) and 0 for SRL

   wire [31:0] aluOut_base =
     (funct3Is[0]  ? instr[30] & instr[5] ? aluMinus[31:0] : aluPlus : 32'b0) |
     (funct3Is[1]  ? leftshift                                       : 32'b0) |
     (funct3Is[2]  ? {31'b0, LT}                                     : 32'b0) |
     (funct3Is[3]  ? {31'b0, LTU}                                    : 32'b0) |
     (funct3Is[4]  ? aluIn1 ^ aluIn2                                 : 32'b0) |
     (funct3Is[5]  ? shifter                                         : 32'b0) |
     (funct3Is[6]  ? aluIn1 | aluIn2                                 : 32'b0) |
     (funct3Is[7]  ? aluIn1 & aluIn2                                 : 32'b0) ;

   wire [31:0] aluOut_muldiv =
     (  funct3Is[0]   ?  multiply[31: 0] : 32'b0) | // 0:MUL
     ( |funct3Is[3:1] ?  multiply[63:32] : 32'b0) | // 1:MULH, 2:MULHSU, 3:MULHU
     (  instr[14]     ?  div_sign ? -divResult : divResult : 32'b0) ;
                                                 // 4:DIV, 5:DIVU, 6:REM, 7:REMU

   wire [31:0] aluOut = isALUreg & funcM ? aluOut_muldiv : aluOut_base;

   //wire [31:0] aluOut = aluOut_base;


   /***************************************************************************/
   // Implementation of DIV/REM instructions, highly inspired by PicoRV32

   reg [31:0] dividend;
   reg [62:0] divisor;
   reg [31:0] quotient;
   reg [31:0] quotient_msk;

   wire divstep_do = (divisor <= {31'b0, dividend});

   wire [31:0] dividendN     = divstep_do ? dividend - divisor[31:0] : dividend;
   wire [31:0] quotientN     = divstep_do ? quotient | quotient_msk  : quotient;

   wire div_sign = ~instr[12] & (instr[13] ? aluIn1[31] :
                                          (aluIn1[31] != aluIn2[31]) & |aluIn2);

   always @(posedge clk) begin
      if (isDivide & aluWr) begin
         dividend <=   ~instr[12] & aluIn1[31] ? -aluIn1 : aluIn1;
         divisor  <= {(~instr[12] & aluIn2[31] ? -aluIn2 : aluIn2), 31'b0};
         quotient <= 0;
         quotient_msk <= 1 << 31;
      end else begin
         dividend     <= dividendN;
         divisor      <= divisor >> 1;
         quotient     <= quotientN;
         quotient_msk <= quotient_msk >> 1;
      end
   end

   reg  [31:0] divResult;
`ifdef DIV
   always @(posedge clk) begin
      divResult <= instr[13] ? dividendN : quotientN;
   end
`else
   always @(posedge clk) begin
      divResult <= 'b0;
   end
`endif
   /***************************************************************************/
   // The predicate for conditional branches.
   /***************************************************************************/

   wire predicate =
        funct3Is[0] &  EQ  | // BEQ
        funct3Is[1] & !EQ  | // BNE
        funct3Is[4] &  LT  | // BLT
        funct3Is[5] & !LT  | // BGE
        funct3Is[6] &  LTU | // BLTU
        funct3Is[7] & !LTU ; // BGEU

   /***************************************************************************/
   // Program counter and branch target computation.
   /***************************************************************************/

   reg  [ADDR_WIDTH-1:0] PC; // The program counter.
   reg  [31:2] instr;        // Latched instruction. Note that bits 0 and 1 are
                             // ignored (not used in RV32I base instr set).

   wire [ADDR_WIDTH-1:0] PCplus2 = PC + 2;
   wire [ADDR_WIDTH-1:0] PCplus4 = PC + 4;
   wire [ADDR_WIDTH-1:0] PCinc   = long_instr ? PCplus4 : PCplus2;

   // An adder used to compute branch address, JAL address and AUIPC.
   // branch->PC+Bimm    AUIPC->PC+Uimm    JAL->PC+Jimm
   // Equivalent to PCplusImm = PC + (isJAL ? Jimm : isAUIPC ? Uimm : Bimm)
   wire [ADDR_WIDTH-1:0] PCplusImm = PC + ( instr[3] ? Jimm[ADDR_WIDTH-1:0] :
                                            instr[4] ? Uimm[ADDR_WIDTH-1:0] :
                                                       Bimm[ADDR_WIDTH-1:0] );

   // A separate adder to compute the destination of load/store.
   // testing instr[5] is equivalent to testing isStore in this context.
   wire [ADDR_WIDTH-1:0] loadstore_addr = rs1[ADDR_WIDTH-1:0] +
                   (instr[5] ? Simm[ADDR_WIDTH-1:0] : Iimm[ADDR_WIDTH-1:0]);

   /* verilator lint_off WIDTH */
   assign mem_addr =   state[WAIT_INSTR_bit] | state[FETCH_INSTR_bit] ?
                       fetch_second_half ? {PCplus4[ADDR_WIDTH-1:2], 2'b00}
                                         : {PC     [ADDR_WIDTH-1:2], 2'b00}
                       : loadstore_addr  ;
   /* verilator lint_on WIDTH */

   /***************************************************************************/
   // Interrupt logic, CSR registers and opcodes.
   /***************************************************************************/

   // Remember interrupt requests as they are not checked for every cycle
   reg  interrupt_request_sticky;

   // Interrupt enable and lock logic
   wire interrupt = interrupt_request_sticky & mstatus & ~mcause;

   // Processor accepts interrupts in EXECUTE state.
   wire interrupt_accepted = interrupt & state[EXECUTE_bit];

   // If current interrupt is accepted, there already might be the next one,
   //  which should not be missed:
   always @(posedge clk) begin
     interrupt_request_sticky <=
         interrupt_request | (interrupt_request_sticky & ~interrupt_accepted);
   end

   // Decoder for mret opcode
   wire interrupt_return = isSYSTEM & funct3Is[0]; // & (instr[31:20]==12'h302);

   // CSRs:
   reg  [ADDR_WIDTH-1:0] mepc;    // The saved program counter.
   reg  [ADDR_WIDTH-1:0] mtvec;   // The address of the interrupt handler.
   reg                   mstatus; // Interrupt enable
   reg                   mcause;  // Interrupt cause (and lock)
   reg  [63:0]           cycles;  // Cycle counter

   always @(posedge clk) cycles <= cycles + 1;

   wire sel_mstatus = (instr[31:20] == 12'h300);
   wire sel_mtvec   = (instr[31:20] == 12'h305);
   wire sel_mepc    = (instr[31:20] == 12'h341);
   wire sel_mcause  = (instr[31:20] == 12'h342);
   wire sel_cycles  = (instr[31:20] == 12'hC00);
   wire sel_cyclesh = (instr[31:20] == 12'hC80);

   // Read CSRs
   /* verilator lint_off WIDTH */
   wire [31:0] CSR_read =
     (sel_mstatus ? {28'b0, mstatus, 3'b0} : 32'b0) |
     (sel_mtvec   ? mtvec                  : 32'b0) |
     (sel_mepc    ? mepc                   : 32'b0) |
     (sel_mcause  ? {mcause, 31'b0}        : 32'b0) |
     (sel_cycles  ? cycles[31:0]           : 32'b0) |
     (sel_cyclesh ? cycles[63:32]          : 32'b0) ;
   /* verilator lint_on WIDTH */

   // Write CSRs: 5 bit unsigned immediate or content of RS1
   wire [31:0] CSR_modifier = instr[14] ? {27'd0, instr[19:15]} : rs1;

   wire [31:0] CSR_write = (instr[13:12] == 2'b10) ? CSR_modifier | CSR_read  :
                           (instr[13:12] == 2'b11) ? ~CSR_modifier & CSR_read :
                        /* (instr[13:12] == 2'b01) ? */  CSR_modifier ;

   always @(posedge clk) begin
      if(!reset) begin
	 mstatus <= 0;
      end else begin
	 // Execute a CSR opcode
	 if (isSYSTEM & (instr[14:12] != 0) & state[EXECUTE_bit]) begin
	    if (sel_mstatus) mstatus <= CSR_write[3];
	    if (sel_mtvec  ) mtvec   <= CSR_write[ADDR_WIDTH-1:0];
	 end
      end
   end

   /***************************************************************************/
   // The value written back to the register file.
   /***************************************************************************/

   /* verilator lint_off WIDTH */
   wire [31:0] writeBackData  =
      (isSYSTEM            ? CSR_read  : 32'b0) |  // SYSTEM
      (isLUI               ? Uimm      : 32'b0) |  // LUI
      (isALU               ? aluOut    : 32'b0) |  // ALUreg, ALUimm
      (isAUIPC             ? PCplusImm : 32'b0) |  // AUIPC
      (isJALR   | isJAL    ? PCinc     : 32'b0) |  // JAL, JALR
      (isLoad              ? LOAD_data : 32'b0);   // Load
   /* verilator lint_on WIDTH */

   /***************************************************************************/
   // LOAD/STORE
   /***************************************************************************/

   // All memory accesses are aligned on 32 bits boundary. For this
   // reason, we need some circuitry that does unaligned halfword
   // and byte load/store, based on:
   // - funct3[1:0]:  00->byte 01->halfword 10->word
   // - mem_addr[1:0]: indicates which byte/halfword is accessed

   wire mem_byteAccess     = instr[13:12] == 2'b00; // funct3[1:0] == 2'b00;
   wire mem_halfwordAccess = instr[13:12] == 2'b01; // funct3[1:0] == 2'b01;

   // LOAD, in addition to funct3[1:0], LOAD depends on:
   // - funct3[2] (instr[14]): 0->do sign expansion   1->no sign expansion

   wire LOAD_sign =
        !instr[14] & (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]);

   wire [31:0] LOAD_data =
         mem_byteAccess ? {{24{LOAD_sign}},     LOAD_byte} :
     mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} :
                          mem_rdata ;

   wire [15:0] LOAD_halfword =
               loadstore_addr[1] ? mem_rdata[31:16] : mem_rdata[15:0];

   wire  [7:0] LOAD_byte =
               loadstore_addr[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];

   // STORE

   assign mem_wdata[ 7: 0] = rs2[7:0];
   assign mem_wdata[15: 8] = loadstore_addr[0] ? rs2[7:0]  : rs2[15: 8];
   assign mem_wdata[23:16] = loadstore_addr[1] ? rs2[7:0]  : rs2[23:16];
   assign mem_wdata[31:24] = loadstore_addr[0] ? rs2[7:0]  :
                             loadstore_addr[1] ? rs2[15:8] : rs2[31:24];

   // The memory write mask:
   //    1111                     if writing a word
   //    0011 or 1100             if writing a halfword
   //                                (depending on loadstore_addr[1])
   //    0001, 0010, 0100 or 1000 if writing a byte
   //                                (depending on loadstore_addr[1:0])

   wire [3:0] STORE_wmask =
              mem_byteAccess      ?
                    (loadstore_addr[1] ?
                          (loadstore_addr[0] ? 4'b1000 : 4'b0100) :
                          (loadstore_addr[0] ? 4'b0010 : 4'b0001)
                    ) :
              mem_halfwordAccess ?
                    (loadstore_addr[1] ? 4'b1100 : 4'b0011) :
              4'b1111;

   /***************************************************************************/
   // Unaligned fetch mechanism and compressed opcode handling
   /***************************************************************************/

   reg [ADDR_WIDTH-1:2] cached_addr;
   reg           [31:0] cached_data;

   wire current_cache_hit = cached_addr == PC     [ADDR_WIDTH-1:2];
   wire    next_cache_hit = cached_addr == PC_new [ADDR_WIDTH-1:2];

   wire current_unaligned_long = &cached_mem [17:16] & PC    [1];
   wire    next_unaligned_long = &cached_data[17:16] & PC_new[1];

   reg fetch_second_half;
   reg long_instr;

   wire [31:0] cached_mem   = current_cache_hit ? cached_data : mem_rdata;
   wire [31:0] decomp_input = PC[1] ? {mem_rdata[15:0], cached_mem[31:16]}
                                    : cached_mem;
   wire [31:0] decompressed;

   decompressor _decomp ( .c(decomp_input), .d(decompressed) );

   /*************************************************************************/
   // And, last but not least, the state machine.
   /*************************************************************************/

   localparam FETCH_INSTR_bit          = 0;
   localparam WAIT_INSTR_bit           = 1;
   localparam EXECUTE_bit              = 2;
   localparam WAIT_ALU_OR_MEM_bit      = 3;
   localparam WAIT_ALU_OR_MEM_SKIP_bit = 4;

   localparam NB_STATES                = 5;

   localparam FETCH_INSTR          = 1 << FETCH_INSTR_bit;
   localparam WAIT_INSTR           = 1 << WAIT_INSTR_bit;
   localparam EXECUTE              = 1 << EXECUTE_bit;
   localparam WAIT_ALU_OR_MEM      = 1 << WAIT_ALU_OR_MEM_bit;
   localparam WAIT_ALU_OR_MEM_SKIP = 1 << WAIT_ALU_OR_MEM_SKIP_bit;

   (* onehot *)
   reg [NB_STATES-1:0] state;

   // The signals (internal and external) that are determined
   // combinatorially from state and other signals.

   // register write-back enable.
   wire writeBack = ~(isBranch | isStore ) & (
            state[EXECUTE_bit] |
	    state[WAIT_ALU_OR_MEM_bit] |
            state[WAIT_ALU_OR_MEM_SKIP_bit]
   );

   // The memory-read signal.
   assign mem_rstrb = state[EXECUTE_bit] & isLoad | state[FETCH_INSTR_bit];

   // The mask for memory-write.
   assign mem_wmask = {4{state[EXECUTE_bit] & isStore}} & STORE_wmask;

   // aluWr starts computation (divide) in the ALU.
   assign aluWr = state[EXECUTE_bit] & isALU;

   wire jumpToPCplusImm = isJAL | (isBranch & predicate);

   wire needToWait = isLoad | isStore | isDivide;

   wire [ADDR_WIDTH-1:0] PC_new =
           isJALR           ? {aluPlus[ADDR_WIDTH-1:1],1'b0} :
           jumpToPCplusImm  ? PCplusImm :
           interrupt_return ? mepc :
                              PCinc;

   always @(posedge clk) begin
      if(!reset) begin
         state             <= WAIT_ALU_OR_MEM;     //Just waiting for !mem_wbusy
         PC                <= RESET_ADDR[ADDR_WIDTH-1:0];
         mcause            <= 0;
         cached_addr       <= {ADDR_WIDTH-2{1'b1}};//Needs to be an invalid addr
         fetch_second_half <= 0;
      end else begin

	 // See note [1] at the end of this file.
	 (* parallel_case *)
	 case(1'b1)

           state[WAIT_INSTR_bit]: begin
              if(!mem_rbusy) begin // may be high when executing from SPI flash
		 // Update cache
		 if (~current_cache_hit | fetch_second_half) begin
                    cached_addr <= mem_addr[ADDR_WIDTH-1:2];
                    cached_data <= mem_rdata;
		 end;

		 // Decode instruction
		 rs1 <= registerFile[decompressed[19:15]];
		 rs2 <= registerFile[decompressed[24:20]];
		 instr      <= decompressed[31:2];
		 long_instr <= &decomp_input[1:0];

		 // Long opcode, unaligned, first part fetched,
		 // happens in non-linear code
		 if (current_unaligned_long & ~fetch_second_half) begin
                    fetch_second_half <= 1;
                    state <= FETCH_INSTR;
		 end else begin
                    fetch_second_half <= 0;
                    state <= EXECUTE;
		 end
              end
           end

           state[EXECUTE_bit]: begin
              if (interrupt) begin
		 PC     <= mtvec;
		 mepc   <= PC_new;
		 mcause <= 1;
		 state  <= needToWait ? WAIT_ALU_OR_MEM : FETCH_INSTR;
              end else begin
		 PC <= PC_new;
		 if (interrupt_return) mcause <= 0;

		 state <= next_cache_hit & ~next_unaligned_long
 		        ? (needToWait ? WAIT_ALU_OR_MEM_SKIP : WAIT_INSTR)
			: (needToWait ? WAIT_ALU_OR_MEM      : FETCH_INSTR);

		 fetch_second_half <= next_cache_hit & next_unaligned_long;
              end
           end

           state[WAIT_ALU_OR_MEM_bit]: begin
              if(!aluBusy & !mem_rbusy & !mem_wbusy) state <= FETCH_INSTR;
           end

           state[WAIT_ALU_OR_MEM_SKIP_bit]: begin
              if(!aluBusy & !mem_rbusy & !mem_wbusy) state <= WAIT_INSTR;
           end

           default: begin // FETCH_INSTR
              state <= WAIT_INSTR;
           end
	 endcase
      end
   end

`ifdef BENCH
   initial begin
      cycles = 0;
      registerFile[0] = 0;
   end
`endif

endmodule

/*****************************************************************************/

// if c[15:0] is a compressed instrution, decompresses it in d
// else copies c to d
module decompressor(
   input  wire [31:0] c,
   output reg  [31:0] d
);

   // How to handle illegal and unknown opcodes

   localparam illegal = 32'h00000000;
   localparam unknown = 32'h00000000;

   // Register decoder

   wire [4:0] rcl = {2'b01, c[4:2]}; // Register compressed low
   wire [4:0] rch = {2'b01, c[9:7]}; // Register compressed high

   wire [4:0] rwl  = c[ 6:2];  // Register wide low
   wire [4:0] rwh  = c[11:7];  // Register wide high

   localparam x0 = 5'b00000;
   localparam x1 = 5'b00001;
   localparam x2 = 5'b00010;

   // Immediate decoder

   wire  [4:0]    shiftImm = c[6:2];

   wire [11:0] addi4spnImm = {2'b00, c[10:7], c[12:11], c[5], c[6], 2'b00};
   wire [11:0]     lwswImm = {5'b00000, c[5], c[12:10] , c[6], 2'b00};
   wire [11:0]     lwspImm = {4'b0000, c[3:2], c[12], c[6:4], 2'b00};
   wire [11:0]     swspImm = {4'b0000, c[8:7], c[12:9], 2'b00};

   wire [11:0] addi16spImm = {{ 3{c[12]}}, c[4:3], c[5], c[2], c[6], 4'b0000};
   wire [11:0]      addImm = {{ 7{c[12]}}, c[6:2]};

   /* verilator lint_off UNUSED */
   wire [12:0]        bImm = {{ 5{c[12]}}, c[6:5], c[2], c[11:10], c[4:3], 1'b0};
   wire [20:0]      jalImm = {{10{c[12]}}, c[8], c[10:9], c[6], c[7], c[2], c[11], c[5:3], 1'b0};
   wire [31:0]      luiImm = {{15{c[12]}}, c[6:2], 12'b000000000000};
   /* verilator lint_on UNUSED */

   always @*
   casez (c[15:0])
                                                     // imm / funct7   +   rs2  rs1     fn3                   rd    opcode
      16'b???___????????_???_11 : d =                                                                            c  ; // Long opcode, no need to decompress

/* verilator lint_off CASEOVERLAP */

      16'b000___00000000_000_00 : d =                                                                       illegal ; // c.illegal   -->  illegal
      16'b000___????????_???_00 : d = {      addi4spnImm,             x2, 3'b000,                 rcl, 7'b00100_11} ; // c.addi4spn  -->  addi rd', x2, nzuimm[9:2]
/* verilator lint_on CASEOVERLAP */

      16'b010_???_???_??_???_00 : d = {          lwswImm,            rch, 3'b010,                 rcl, 7'b00000_11} ; // c.lw        -->  lw   rd', offset[6:2](rs1')
      16'b110_???_???_??_???_00 : d = {    lwswImm[11:5],       rcl, rch, 3'b010,        lwswImm[4:0], 7'b01000_11} ; // c.sw        -->  sw   rs2', offset[6:2](rs1')

      16'b000_???_???_??_???_01 : d = {           addImm,            rwh, 3'b000,                 rwh, 7'b00100_11} ; // c.addi      -->  addi rd, rd, nzimm[5:0]
      16'b001____???????????_01 : d = {     jalImm[20], jalImm[10:1], jalImm[11], jalImm[19:12],   x1, 7'b11011_11} ; // c.jal       -->  jal  x1, offset[11:1]
      16'b010__?_?????_?????_01 : d = {           addImm,             x0, 3'b000,                 rwh, 7'b00100_11} ; // c.li        -->  addi rd, x0, imm[5:0]
      16'b011__?_00010_?????_01 : d = {      addi16spImm,            rwh, 3'b000,                 rwh, 7'b00100_11} ; // c.addi16sp  -->  addi x2, x2, nzimm[9:4]
      16'b011__?_?????_?????_01 : d = {    luiImm[31:12],                                         rwh, 7'b01101_11} ; // c.lui       -->  lui  rd, nzuimm[17:12]
      16'b100_?_00_???_?????_01 : d = {       7'b0000000,  shiftImm, rch, 3'b101,                 rch, 7'b00100_11} ; // c.srli      -->  srli rd', rd', shamt[5:0]
      16'b100_?_01_???_?????_01 : d = {       7'b0100000,  shiftImm, rch, 3'b101,                 rch, 7'b00100_11} ; // c.srai      -->  srai rd', rd', shamt[5:0]
      16'b100_?_10_???_?????_01 : d = {           addImm,            rch, 3'b111,                 rch, 7'b00100_11} ; // c.andi      -->  andi rd', rd', imm[5:0]
      16'b100_011_???_00_???_01 : d = {       7'b0100000,       rcl, rch, 3'b000,                 rch, 7'b01100_11} ; // c.sub       -->  sub  rd', rd', rs2'
      16'b100_011_???_01_???_01 : d = {       7'b0000000,       rcl, rch, 3'b100,                 rch, 7'b01100_11} ; // c.xor       -->  xor  rd', rd', rs2'
      16'b100_011_???_10_???_01 : d = {       7'b0000000,       rcl, rch, 3'b110,                 rch, 7'b01100_11} ; // c.or        -->  or   rd', rd', rs2'
      16'b100_011_???_11_???_01 : d = {       7'b0000000,       rcl, rch, 3'b111,                 rch, 7'b01100_11} ; // c.and       -->  and  rd', rd', rs2'
      16'b101____???????????_01 : d = {     jalImm[20], jalImm[10:1], jalImm[11], jalImm[19:12],   x0, 7'b11011_11} ; // c.j         -->  jal  x0, offset[11:1]
      16'b110__???_???_?????_01 : d = {bImm[12], bImm[10:5],     x0, rch, 3'b000, bImm[4:1], bImm[11], 7'b11000_11} ; // c.beqz      -->  beq  rs1', x0, offset[8:1]
      16'b111__???_???_?????_01 : d = {bImm[12], bImm[10:5],     x0, rch, 3'b001, bImm[4:1], bImm[11], 7'b11000_11} ; // c.bnez      -->  bne  rs1', x0, offset[8:1]

      16'b000__?_?????_?????_10 : d = {        7'b0000000, shiftImm, rwh, 3'b001,                 rwh, 7'b00100_11} ; // c.slli      -->  slli rd, rd, shamt[5:0]
      16'b010__?_?????_?????_10 : d = {           lwspImm,            x2, 3'b010,                 rwh, 7'b00000_11} ; // c.lwsp      -->  lw   rd, offset[7:2](x2)
      16'b100__0_?????_00000_10 : d = {  12'b000000000000,           rwh, 3'b000,                  x0, 7'b11001_11} ; // c.jr        -->  jalr x0, rs1, 0
      16'b100__0_?????_?????_10 : d = {        7'b0000000,      rwl,  x0, 3'b000,                 rwh, 7'b01100_11} ; // c.mv        -->  add  rd, x0, rs2
   // 16'b100__1_00000_00000_10 : d = {                              25'b00000000_00010000_00000000_0, 7'b11100_11} ; // c.ebreak    -->  ebreak
      16'b100__1_?????_00000_10 : d = {  12'b000000000000,           rwh, 3'b000,                  x1, 7'b11001_11} ; // c.jalr      -->  jalr x1, rs1, 0
      16'b100__1_?????_?????_10 : d = {        7'b0000000,      rwl, rwh, 3'b000,                 rwh, 7'b01100_11} ; // c.add       -->  add  rd, rd, rs2
      16'b110__?_?????_?????_10 : d = {     swspImm[11:5],      rwl,  x2, 3'b010,        swspImm[4:0], 7'b01000_11} ; // c.swsp      -->  sw   rs2, offset[7:2](x2)

      default:                    d =                                                                       unknown ; // Unknown opcode
   endcase
endmodule

/******************************************************************************/
// MappedSPIFlash - SPI Flash memory controller
/******************************************************************************/

`ifdef SPI_FLASH_FAST_READ
module MappedSPIFlash(
    input wire 	       clk,          // system clock
    input wire 	       rstrb,        // read strobe
    input wire [19:0]  word_address, // address of the word to be read

    output wire [31:0] rdata,        // data read
    output wire        rbusy,        // asserted if busy receiving data

		             // SPI flash pins
    output wire        CLK,  // clock
    output reg         CS_N, // chip select negated (active low)
    output wire        MOSI, // master out slave in (data to be sent to flash)
    input  wire        MISO  // master in slave out (data received from flash)
);

   reg [5:0]  snd_bitcount;
   reg [31:0] cmd_addr;
   reg [5:0]  rcv_bitcount;
   reg [31:0] rcv_data;
   wire       sending   = (snd_bitcount != 0);
   wire       receiving = (rcv_bitcount != 0);
   wire       busy = sending | receiving;
   assign     rbusy = !CS_N;

   assign  MOSI  = cmd_addr[31];
   initial CS_N  = 1'b1;
   assign  CLK   = !CS_N && !clk;

   // since least significant bytes are read first, we need to swizzle...
   assign rdata = {rcv_data[7:0],rcv_data[15:8],rcv_data[23:16],rcv_data[31:24]};

   always @(posedge clk) begin
      if(rstrb) begin
	 CS_N <= 1'b0;
	 cmd_addr <= {8'h0b, 2'b00,word_address[19:0], 2'b00};
	 snd_bitcount <= 6'd40; // command (8 bits) + address (24 bits) + dummy clocks (8 bits)
      end else begin
	 if(sending) begin
	    if(snd_bitcount == 1) begin
	       rcv_bitcount <= 6'd32;
	    end
	    snd_bitcount <= snd_bitcount - 6'd1;
	    cmd_addr <= {cmd_addr[30:0],1'b1};
	 end
	 if(receiving) begin
	    rcv_bitcount <= rcv_bitcount - 6'd1;
	    rcv_data <= {rcv_data[30:0],MISO};
	 end
	 if(!busy) begin
	    CS_N <= 1'b1;
	 end
      end
   end
endmodule
`endif

/******************************************************************************/
// buart - Basic UART
/******************************************************************************/

module buart #(
  parameter FREQ_MHZ = 12,
  parameter BAUDS    = 115200
) (
    input clk,
    input resetq,

    output tx,
    input  rx,

    input  wr,
    input  rd,
    input  [7:0] tx_data,
    output [7:0] rx_data,

    output busy,
    output valid
);

   /************** Baud frequency constants ******************/

    parameter divider = FREQ_MHZ * 1000000 / BAUDS;
    parameter divwidth = $clog2(divider);

    parameter baud_init = divider;
    parameter half_baud_init = divider/2+1;

   /************* Receiver ***********************************/

    // Trick from Olof Kindgren: use n+1 bit and decrement instead of
    // incrementing, and test the sign bit.

    reg [divwidth:0] recv_divcnt;
    wire recv_baud_clk = recv_divcnt[divwidth];

    reg recv_state;
    reg [8:0] recv_pattern;
    reg [7:0] recv_buf_data;
    reg recv_buf_valid;

    assign rx_data = recv_buf_data;
    assign valid = recv_buf_valid;


    always @(posedge clk) begin

       if (rd) recv_buf_valid <= 0;

       if (!resetq) recv_buf_valid <= 0;

       case (recv_state)

         0: begin
               if (!rx) begin
                 recv_state <= 1;
	 /* verilator lint_off WIDTH */
                 recv_divcnt <= half_baud_init;
	 /* verilator lint_on WIDTH */
               end
               recv_pattern <= 0;
            end

         1: begin
               if (recv_baud_clk) begin

                 // Inverted start bit shifted through the whole register
	 // The idea is to use the start bit as marker
	 // for "reception complete",
	 // but as initialising registers to 10'b1_11111111_1
	 // is more costly than using zero,
	 // it is done with inverted logic.
                 if (recv_pattern[0]) begin
                   recv_buf_data  <= ~recv_pattern[8:1];
                   recv_buf_valid <= 1;
                   recv_state <= 0;
                 end else begin
                   recv_pattern <= {~rx, recv_pattern[8:1]};
	   /* verilator lint_off WIDTH */
                   recv_divcnt <= baud_init;
	   /* verilator lint_on WIDTH */
                 end
               end else recv_divcnt <= recv_divcnt - 1;
            end

       endcase
    end

   /************* Transmitter ******************************/

    reg [divwidth:0] send_divcnt;
    wire send_baud_clk  = send_divcnt[divwidth];

    reg [9:0] send_pattern = 1;
    assign tx = send_pattern[0];
    assign busy = |send_pattern[9:1];

    // The transmitter shifts until the stop bit is on the wire,
    // and stops shifting then.
    always @(posedge clk) begin
       if (wr) send_pattern <= {1'b1, tx_data[7:0], 1'b0};
       else if (send_baud_clk & busy) send_pattern <= send_pattern >> 1;
       /* verilator lint_off WIDTH */
       if (wr | send_baud_clk) send_divcnt <= baud_init;
                          else send_divcnt <= send_divcnt - 1;
       /* verilator lint_on WIDTH */
    end

endmodule

/******************************************************************************/
// GPIO Module - Two 8-bit ports with configurable direction
/******************************************************************************/

module gpio_controller (
    input  wire        clk,
    input  wire        rst_n,

    // CPU Interface
    input  wire [3:0]  addr,        // Address (byte offset within GPIO region)
    input  wire [31:0] wdata,       // Write data
    input  wire [3:0]  wmask,       // Write mask
    input  wire        sel,         // Peripheral select
    output wire [31:0] rdata,       // Read data

    // GPIO Port A
    input  wire [7:0]  gpio_a_in,   // GPIO A input pins
    output wire [7:0]  gpio_a_out,  // GPIO A output pins
    output wire [7:0]  gpio_a_oeb,  // GPIO A output enable (1=input, 0=output)

    // GPIO Port B
    input  wire [7:0]  gpio_b_in,   // GPIO B input pins
    output wire [7:0]  gpio_b_out,  // GPIO B output pins
    output wire [7:0]  gpio_b_oeb   // GPIO B output enable (1=input, 0=output)
);

    // Registers
    reg [7:0] gpio_a_data;   // GPIO A data register
    reg [7:0] gpio_a_dir;    // GPIO A direction register (0=input, 1=output)
    reg [7:0] gpio_b_data;   // GPIO B data register
    reg [7:0] gpio_b_dir;    // GPIO B direction register (0=input, 1=output)

    // Address decode
    wire sel_gpio_a_data = sel && (addr[3:2] == 2'b00);  // 0x5000
    wire sel_gpio_a_dir  = sel && (addr[3:2] == 2'b01);  // 0x5004
    wire sel_gpio_b_data = sel && (addr[3:2] == 2'b10);  // 0x5008
    wire sel_gpio_b_dir  = sel && (addr[3:2] == 2'b11);  // 0x5 00C

    // Write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_a_data <= 8'h00;
            gpio_a_dir  <= 8'h00;  // All inputs by default
            gpio_b_data <= 8'h00;
            gpio_b_dir  <= 8'h00;  // All inputs by default
        end else begin
            if (sel_gpio_a_data && wmask[0]) gpio_a_data <= wdata[7:0];
            if (sel_gpio_a_dir  && wmask[0]) gpio_a_dir  <= wdata[7:0];
            if (sel_gpio_b_data && wmask[0]) gpio_b_data <= wdata[7:0];
            if (sel_gpio_b_dir  && wmask[0]) gpio_b_dir  <= wdata[7:0];
        end
    end

    // Read logic (read input pins when configured as input, read data register when output)
    wire [7:0] gpio_a_read = gpio_a_dir ? gpio_a_data : gpio_a_in;
    wire [7:0] gpio_b_read = gpio_b_dir ? gpio_b_data : gpio_b_in;

    assign rdata = sel_gpio_a_data ? {24'h0, gpio_a_read} :
                   sel_gpio_a_dir  ? {24'h0, gpio_a_dir}  :
                   sel_gpio_b_data ? {24'h0, gpio_b_read} :
                   sel_gpio_b_dir  ? {24'h0, gpio_b_dir}  :
                   32'h0;

    // Output assignments
    assign gpio_a_out = gpio_a_data;
    assign gpio_a_oeb = ~gpio_a_dir;  // 1=input (disabled), 0=output (enabled)
    assign gpio_b_out = gpio_b_data;
    assign gpio_b_oeb = ~gpio_b_dir;

endmodule

/******************************************************************************/
// Timer Module - 32-bit timer with prescaler, compare, and interrupt
/******************************************************************************/

module timer_controller (
    input  wire        clk,
    input  wire        rst_n,

    // CPU Interface
    input  wire [3:0]  addr,        // Address (byte offset within Timer region)
    input  wire [31:0] wdata,       // Write data
    input  wire [3:0]  wmask,       // Write mask
    input  wire        sel,         // Peripheral select
    output wire [31:0] rdata,       // Read data

    // Interrupt output
    output wire        irq          // Interrupt request
);

    // Registers
    reg [31:0] counter;       // 32-bit counter
    reg [31:0] prescaler;     // Prescaler value
    reg [31:0] compare;       // Compare value
    reg [2:0]  ctrl;          // Control register: [2]=irq_enable, [1]=reset, [0]=enable

    reg [31:0] prescaler_cnt; // Prescaler counter
    reg        irq_flag;      // Interrupt flag

    // Address decode
    wire sel_ctrl      = sel && (addr[3:2] == 2'b00);  // 0x6000
    wire sel_prescaler = sel && (addr[3:2] == 2'b01);  // 0x6004
    wire sel_counter   = sel && (addr[3:2] == 2'b10);  // 0x6008
    wire sel_compare   = sel && (addr[3:2] == 2'b11);  // 0x600C

    wire timer_enable = ctrl[0];
    wire timer_reset  = ctrl[1];
    wire irq_enable   = ctrl[2];

    // Write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl      <= 3'b000;
            prescaler <= 32'h0;
            compare   <= 32'hFFFFFFFF;
        end else begin
            if (sel_ctrl      && wmask[0]) ctrl      <= wdata[2:0];
            if (sel_prescaler && |wmask)   prescaler <= wdata;
            if (sel_compare   && |wmask)   compare   <= wdata;
        end
    end

    // Timer logic
    wire prescaler_tick = (prescaler_cnt >= prescaler);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter       <= 32'h0;
            prescaler_cnt <= 32'h0;
            irq_flag      <= 1'b0;
        end else begin
            if (timer_reset || !timer_enable) begin
                counter       <= 32'h0;
                prescaler_cnt <= 32'h0;
                irq_flag      <= 1'b0;
            end else if (timer_enable) begin
                // Prescaler counter
                if (prescaler_tick) begin
                    prescaler_cnt <= 32'h0;
                    counter <= counter + 1;
                end else begin
                    prescaler_cnt <= prescaler_cnt + 1;
                end

                // Compare and interrupt
                if (counter == compare) begin
                    irq_flag <= 1'b1;
                end

                // Allow CPU to write counter
                if (sel_counter && |wmask) begin
                    counter <= wdata;
                end
            end
        end
    end

    // Read logic
    assign rdata = sel_ctrl      ? {29'h0, ctrl}    :
                   sel_prescaler ? prescaler        :
                   sel_counter   ? counter          :
                   sel_compare   ? compare          :
                   32'h0;

    // Interrupt output
    assign irq = irq_enable & irq_flag;

endmodule

/******************************************************************************/
// PWM Module - 4 channels, 16-bit resolution
/******************************************************************************/

module pwm_controller (
    input  wire        clk,
    input  wire        rst_n,

    // CPU Interface
    input  wire [4:0]  addr,        // Address (byte offset within PWM region)
    input  wire [31:0] wdata,       // Write data
    input  wire [3:0]  wmask,       // Write mask
    input  wire        sel,         // Peripheral select
    output wire [31:0] rdata,       // Read data

    // PWM outputs
    output wire [3:0]  pwm_out      // PWM channel outputs
);

    // Registers - 16-bit duty cycle for each channel (split into LOW and HIGH bytes)
    reg [15:0] pwm0_duty;
    reg [15:0] pwm1_duty;
    reg [15:0] pwm2_duty;
    reg [15:0] pwm3_duty;

    // 16-bit counter for PWM generation
    reg [15:0] pwm_counter;

    // Address decode (each channel uses 2 registers: LOW and HIGH byte)
    wire sel_pwm0_low  = sel && (addr[4:2] == 3'b000);  // 0x7000
    wire sel_pwm0_high = sel && (addr[4:2] == 3'b001);  // 0x7004
    wire sel_pwm1_low  = sel && (addr[4:2] == 3'b010);  // 0x7008
    wire sel_pwm1_high = sel && (addr[4:2] == 3'b011);  // 0x700C
    wire sel_pwm2_low  = sel && (addr[4:2] == 3'b100);  // 0x7010
    wire sel_pwm2_high = sel && (addr[4:2] == 3'b101);  // 0x7014
    wire sel_pwm3_low  = sel && (addr[4:2] == 3'b110);  // 0x7018
    wire sel_pwm3_high = sel && (addr[4:2] == 3'b111);  // 0x701C

    // Write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm0_duty <= 16'h0;
            pwm1_duty <= 16'h0;
            pwm2_duty <= 16'h0;
            pwm3_duty <= 16'h0;
        end else begin
            if (sel_pwm0_low  && wmask[0]) pwm0_duty[7:0]  <= wdata[7:0];
            if (sel_pwm0_high && wmask[0]) pwm0_duty[15:8] <= wdata[7:0];
            if (sel_pwm1_low  && wmask[0]) pwm1_duty[7:0]  <= wdata[7:0];
            if (sel_pwm1_high && wmask[0]) pwm1_duty[15:8] <= wdata[7:0];
            if (sel_pwm2_low  && wmask[0]) pwm2_duty[7:0]  <= wdata[7:0];
            if (sel_pwm2_high && wmask[0]) pwm2_duty[15:8] <= wdata[7:0];
            if (sel_pwm3_low  && wmask[0]) pwm3_duty[7:0]  <= wdata[7:0];
            if (sel_pwm3_high && wmask[0]) pwm3_duty[15:8] <= wdata[7:0];
        end
    end

    // PWM counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_counter <= 16'h0;
        end else begin
            pwm_counter <= pwm_counter + 1;
        end
    end

    // PWM generation (output is high when counter < duty cycle)
    assign pwm_out[0] = (pwm_counter < pwm0_duty);
    assign pwm_out[1] = (pwm_counter < pwm1_duty);
    assign pwm_out[2] = (pwm_counter < pwm2_duty);
    assign pwm_out[3] = (pwm_counter < pwm3_duty);

    // Read logic
    assign rdata = sel_pwm0_low  ? {24'h0, pwm0_duty[7:0]}  :
                   sel_pwm0_high ? {24'h0, pwm0_duty[15:8]} :
                   sel_pwm1_low  ? {24'h0, pwm1_duty[7:0]}  :
                   sel_pwm1_high ? {24'h0, pwm1_duty[15:8]} :
                   sel_pwm2_low  ? {24'h0, pwm2_duty[7:0]}  :
                   sel_pwm2_high ? {24'h0, pwm2_duty[15:8]} :
                   sel_pwm3_low  ? {24'h0, pwm3_duty[7:0]}  :
                   sel_pwm3_high ? {24'h0, pwm3_duty[15:8]} :
                   32'h0;

endmodule

/******************************************************************************/
// Top-level SoC module (frv32_soc)
/******************************************************************************/

module frv32_soc #(
    parameter CLK_FREQ_MHZ = 12,
    parameter UART_BAUDS = 115200
) (
    input  wire clk,
    input  wire rst_n,

    // UART pins
    output wire uart_tx,
    input  wire uart_rx,

    // SPI Flash pins
    output wire flash_clk,
    output wire flash_cs_n,
    output wire flash_mosi,
    input  wire flash_miso,

    // GPIO Port A
    input  wire [7:0] gpio_a_in,
    output wire [7:0] gpio_a_out,
    output wire [7:0] gpio_a_oeb,

    // GPIO Port B
    input  wire [7:0] gpio_b_in,
    output wire [7:0] gpio_b_out,
    output wire [7:0] gpio_b_oeb,

    // PWM outputs
    output wire [3:0] pwm_out
);

    /***************************************************************************/
    // CPU signals
    /***************************************************************************/
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire  [3:0] mem_wmask;
    wire [31:0] mem_rdata;
    wire        mem_rstrb;
    wire        mem_rbusy;
    wire        mem_wbusy;

    /***************************************************************************/
    // Address decoding
    /***************************************************************************/
    wire flash_sel = (mem_addr[15:13] == 3'b000);  // 0x0000-0x1FFF
    wire ram_sel   = (mem_addr[15:12] == 4'h2);    // 0x2000-0x2FFF
    wire uart_sel  = (mem_addr[15:12] == 4'h4);    // 0x4000-0x4FFF
    wire gpio_sel  = (mem_addr[15:12] == 4'h5);    // 0x5000-0x5FFF
    wire timer_sel = (mem_addr[15:12] == 4'h6);    // 0x6000-0x6FFF
    wire pwm_sel   = (mem_addr[15:12] == 4'h7);    // 0x7000-0x7FFF

    wire uart_data_sel   = uart_sel && (mem_addr[2] == 1'b0);  // 0x4000
    wire uart_status_sel = uart_sel && (mem_addr[2] == 1'b1);  // 0x4004

    /***************************************************************************/
    // Interrupt signals
    /***************************************************************************/
    wire timer_irq;
    wire interrupt_request = timer_irq;  // Can be extended with more interrupt sources

    /***************************************************************************/
    // SPI Flash (read-only memory)
    /***************************************************************************/
    wire [31:0] flash_rdata;
    wire        flash_rbusy;

    MappedSPIFlash flash (
        .clk(clk),
        .rstrb(mem_rstrb & flash_sel),
        .word_address(mem_addr[21:2]),  // Word-aligned address
        .rdata(flash_rdata),
        .rbusy(flash_rbusy),
        .CLK(flash_clk),
        .CS_N(flash_cs_n),
        .MOSI(flash_mosi),
        .MISO(flash_miso)
    );

    /***************************************************************************/
    // RAM (128 words x 32 bits)
    /***************************************************************************/
    reg [31:0] ram [0:127];
    reg [31:0] ram_rdata;

    wire ram_wr = ram_sel && (|mem_wmask);

    always @(posedge clk) begin
        if (ram_wr) begin
            if (mem_wmask[0]) ram[mem_addr[8:2]][7:0]   <= mem_wdata[7:0];
            if (mem_wmask[1]) ram[mem_addr[8:2]][15:8]  <= mem_wdata[15:8];
            if (mem_wmask[2]) ram[mem_addr[8:2]][23:16] <= mem_wdata[23:16];
            if (mem_wmask[3]) ram[mem_addr[8:2]][31:24] <= mem_wdata[31:24];
        end
        ram_rdata <= ram[mem_addr[8:2]];
    end

    /***************************************************************************/
    // UART
    /***************************************************************************/
    wire [7:0] uart_rx_data;
    wire       uart_rx_valid;
    wire       uart_tx_busy;

    wire       uart_wr = uart_data_sel && mem_wmask[0] && !mem_rstrb;
    wire       uart_rd = uart_data_sel && mem_rstrb;

    buart #(
        .FREQ_MHZ(CLK_FREQ_MHZ),
        .BAUDS(UART_BAUDS)
    ) uart (
        .clk(clk),
        .resetq(rst_n),
        .tx(uart_tx),
        .rx(uart_rx),
        .wr(uart_wr),
        .rd(uart_rd),
        .tx_data(mem_wdata[7:0]),
        .rx_data(uart_rx_data),
        .busy(uart_tx_busy),
        .valid(uart_rx_valid)
    );

    /***************************************************************************/
    // UART Register mapping
    /***************************************************************************/
    wire [31:0] uart_rdata = uart_data_sel   ? {24'h0, uart_rx_data} :
                             uart_status_sel ? {30'h0, uart_tx_busy, uart_rx_valid} :
                             32'h0;

    /***************************************************************************/
    // GPIO
    /***************************************************************************/
    wire [31:0] gpio_rdata;

    gpio_controller gpio (
        .clk(clk),
        .rst_n(rst_n),
        .addr(mem_addr[3:0]),
        .wdata(mem_wdata),
        .wmask(mem_wmask),
        .sel(gpio_sel),
        .rdata(gpio_rdata),
        .gpio_a_in(gpio_a_in),
        .gpio_a_out(gpio_a_out),
        .gpio_a_oeb(gpio_a_oeb),
        .gpio_b_in(gpio_b_in),
        .gpio_b_out(gpio_b_out),
        .gpio_b_oeb(gpio_b_oeb)
    );

    /***************************************************************************/
    // Timer
    /***************************************************************************/
    wire [31:0] timer_rdata;

    timer_controller timer (
        .clk(clk),
        .rst_n(rst_n),
        .addr(mem_addr[3:0]),
        .wdata(mem_wdata),
        .wmask(mem_wmask),
        .sel(timer_sel),
        .rdata(timer_rdata),
        .irq(timer_irq)
    );

    /***************************************************************************/
    // PWM
    /***************************************************************************/
    wire [31:0] pwm_rdata;

    pwm_controller pwm (
        .clk(clk),
        .rst_n(rst_n),
        .addr(mem_addr[4:0]),
        .wdata(mem_wdata),
        .wmask(mem_wmask),
        .sel(pwm_sel),
        .rdata(pwm_rdata),
        .pwm_out(pwm_out)
    );

    /***************************************************************************/
    // Read data multiplexer
    /***************************************************************************/
    assign mem_rdata = flash_sel ? flash_rdata :
                       ram_sel   ? ram_rdata   :
                       uart_sel  ? uart_rdata  :
                       gpio_sel  ? gpio_rdata  :
                       timer_sel ? timer_rdata :
                       pwm_sel   ? pwm_rdata   :
                       32'h0;

    /***************************************************************************/
    // Memory busy signals
    /***************************************************************************/
    assign mem_rbusy = flash_sel ? flash_rbusy : 1'b0;
    assign mem_wbusy = 1'b0;  // All peripherals complete writes in one cycle

    /***************************************************************************/
    // CPU instantiation
    /***************************************************************************/
    FemtoRV32 #(
        .RESET_ADDR(32'h00000000),  // Start from SPI Flash
        .ADDR_WIDTH(16)             // 16-bit address space (64KB)
    ) cpu (
        .clk(clk),
        .reset(~rst_n),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy),
        .interrupt_request(interrupt_request)
    );

endmodule

/******************************************************************************/
// ASIC Top-level Wrapper (sasic_top)
// Maps the SoC to 40 bidirectional IOs
/******************************************************************************/

module sasic_top (
    input  wire clk,
    input  wire rst_n,

    // 40 Input pins
    input  wire in_0,  input  wire in_1,  input  wire in_2,  input  wire in_3,
    input  wire in_4,  input  wire in_5,  input  wire in_6,  input  wire in_7,
    input  wire in_8,  input  wire in_9,  input  wire in_10, input  wire in_11,
    input  wire in_12, input  wire in_13, input  wire in_14, input  wire in_15,
    input  wire in_16, input  wire in_17, input  wire in_18, input  wire in_19,
    input  wire in_20, input  wire in_21, input  wire in_22, input  wire in_23,
    input  wire in_24, input  wire in_25, input  wire in_26, input  wire in_27,
    input  wire in_28, input  wire in_29, input  wire in_30, input  wire in_31,
    input  wire in_32, input  wire in_33, input  wire in_34, input  wire in_35,
    input  wire in_36, input  wire in_37, input  wire in_38, input  wire in_39,

    // 40 Output enable pins (1=input/tristate, 0=output)
    output wire oeb_0,  output wire oeb_1,  output wire oeb_2,  output wire oeb_3,
    output wire oeb_4,  output wire oeb_5,  output wire oeb_6,  output wire oeb_7,
    output wire oeb_8,  output wire oeb_9,  output wire oeb_10, output wire oeb_11,
    output wire oeb_12, output wire oeb_13, output wire oeb_14, output wire oeb_15,
    output wire oeb_16, output wire oeb_17, output wire oeb_18, output wire oeb_19,
    output wire oeb_20, output wire oeb_21, output wire oeb_22, output wire oeb_23,
    output wire oeb_24, output wire oeb_25, output wire oeb_26, output wire oeb_27,
    output wire oeb_28, output wire oeb_29, output wire oeb_30, output wire oeb_31,
    output wire oeb_32, output wire oeb_33, output wire oeb_34, output wire oeb_35,
    output wire oeb_36, output wire oeb_37, output wire oeb_38, output wire oeb_39,

    // 40 Output pins
    output wire out_0,  output wire out_1,  output wire out_2,  output wire out_3,
    output wire out_4,  output wire out_5,  output wire out_6,  output wire out_7,
    output wire out_8,  output wire out_9,  output wire out_10, output wire out_11,
    output wire out_12, output wire out_13, output wire out_14, output wire out_15,
    output wire out_16, output wire out_17, output wire out_18, output wire out_19,
    output wire out_20, output wire out_21, output wire out_22, output wire out_23,
    output wire out_24, output wire out_25, output wire out_26, output wire out_27,
    output wire out_28, output wire out_29, output wire out_30, output wire out_31,
    output wire out_32, output wire out_33, output wire out_34, output wire out_35,
    output wire out_36, output wire out_37, output wire out_38, output wire out_39
);

    /***************************************************************************/
    // IO Pin Assignment:
    // IO  0: UART TX (output)
    // IO  1: UART RX (input)
    // IO  2: SPI Flash CLK (output)
    // IO  3: SPI Flash CS_N (output)
    // IO  4: SPI Flash MOSI (output)
    // IO  5: SPI Flash MISO (input)
    // IO  6-13: GPIO Port A (configurable)
    // IO 14-21: GPIO Port B (configurable)
    // IO 22-25: PWM Channels 0-3 (outputs)
    // IO 26-39: Unused (inputs, reserved)
    /***************************************************************************/

    // SoC signals
    wire uart_tx, uart_rx;
    wire flash_clk, flash_cs_n, flash_mosi, flash_miso;
    wire [7:0] gpio_a_in, gpio_a_out, gpio_a_oeb;
    wire [7:0] gpio_b_in, gpio_b_out, gpio_b_oeb;
    wire [3:0] pwm_out;

    // Instantiate the SoC
    frv32_soc #(
        .CLK_FREQ_MHZ(12),
        .UART_BAUDS(115200)
    ) soc (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .flash_clk(flash_clk),
        .flash_cs_n(flash_cs_n),
        .flash_mosi(flash_mosi),
        .flash_miso(flash_miso),
        .gpio_a_in(gpio_a_in),
        .gpio_a_out(gpio_a_out),
        .gpio_a_oeb(gpio_a_oeb),
        .gpio_b_in(gpio_b_in),
        .gpio_b_out(gpio_b_out),
        .gpio_b_oeb(gpio_b_oeb),
        .pwm_out(pwm_out)
    );

    /***************************************************************************/
    // IO Connections
    /***************************************************************************/

    // IO 0: UART TX (output)
    assign out_0 = uart_tx;
    assign oeb_0 = 1'b0;  // Output enabled

    // IO 1: UART RX (input)
    assign uart_rx = in_1;
    assign out_1 = 1'b0;
    assign oeb_1 = 1'b1;  // Input (output disabled)

    // IO 2: SPI Flash CLK (output)
    assign out_2 = flash_clk;
    assign oeb_2 = 1'b0;

    // IO 3: SPI Flash CS_N (output)
    assign out_3 = flash_cs_n;
    assign oeb_3 = 1'b0;

    // IO 4: SPI Flash MOSI (output)
    assign out_4 = flash_mosi;
    assign oeb_4 = 1'b0;

    // IO 5: SPI Flash MISO (input)
    assign flash_miso = in_5;
    assign out_5 = 1'b0;
    assign oeb_5 = 1'b1;

    // IO 6-13: GPIO Port A (configurable direction)
    assign gpio_a_in = {in_13, in_12, in_11, in_10, in_9, in_8, in_7, in_6};
    assign {out_13, out_12, out_11, out_10, out_9, out_8, out_7, out_6} = gpio_a_out;
    assign {oeb_13, oeb_12, oeb_11, oeb_10, oeb_9, oeb_8, oeb_7, oeb_6} = gpio_a_oeb;

    // IO 14-21: GPIO Port B (configurable direction)
    assign gpio_b_in = {in_21, in_20, in_19, in_18, in_17, in_16, in_15, in_14};
    assign {out_21, out_20, out_19, out_18, out_17, out_16, out_15, out_14} = gpio_b_out;
    assign {oeb_21, oeb_20, oeb_19, oeb_18, oeb_17, oeb_16, oeb_15, oeb_14} = gpio_b_oeb;

    // IO 22-25: PWM outputs
    assign {out_25, out_24, out_23, out_22} = pwm_out;
    assign {oeb_25, oeb_24, oeb_23, oeb_22} = 4'b0000;  // All outputs

    // IO 26-39: Unused (set as inputs)
    assign {out_39, out_38, out_37, out_36, out_35, out_34, out_33, out_32,
            out_31, out_30, out_29, out_28, out_27, out_26} = 14'h0;
    assign {oeb_39, oeb_38, oeb_37, oeb_36, oeb_35, oeb_34, oeb_33, oeb_32,
            oeb_31, oeb_30, oeb_29, oeb_28, oeb_27, oeb_26} = 14'h3FFF;  // All inputs

endmodule
