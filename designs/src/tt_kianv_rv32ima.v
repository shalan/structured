// tt_kianv_rv32ima.v — Single-file TT design: KianV RV32IMA uLinux SoC
// Source: https://github.com/splinedrive/KianV_rv32ia_uLinux_SoC
`default_nettype none
// --- riscv_defines.vh ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2022 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`ifndef RISCV_DEFINES_VH
`define RISCV_DEFINES_VH

`define SYSTEM_OPCODE 7'b1110011
`define NOP_INSTR 32'h0000_0013

// mux SRCA
`define SRCA_WIDTH $clog2(`SRCA_LAST)
`define SRCA_PC 0
`define SRCA_OLD_PC 1
`define SRCA_RD1_BUF 2
`define SRCA_AMO_TEMP_DATA 3
`define SRCA_CONST_0 4
`define SRCA_LAST 5

// mux SRCB
`define SRCB_WIDTH $clog2(`SRCB_LAST)
`define SRCB_RD2_BUF 0
`define SRCB_IMM_EXT 1
`define SRCB_CONST_4 2
`define SRCB_CONST_0 3
`define SRCB_LAST 4

// mux4 in data_unit RESULT
`define RESULT_WIDTH $clog2(`RESULT_LAST)
`define RESULT_ALUOUT 0
`define RESULT_DATA 1
`define RESULT_ALURESULT 2
`define RESULT_MULOUT 3
`define RESULT_CSROUT 4
`define RESULT_AMO_TEMP_ADDR 5
`define RESULT_LAST 6

`define ADDR_PC 0
`define ADDR_RESULT 1

`define IMMSRC_RTYPE 3'b xxx
`define IMMSRC_ITYPE 3'b 000
`define IMMSRC_STYPE 3'b 001
`define IMMSRC_BTYPE 3'b 010
`define IMMSRC_UTYPE 3'b 100
`define IMMSRC_JTYPE 3'b 011
//
// alu operation
`define ALU_OP_WIDTH $clog2(`ALU_OP_LAST)
`define ALU_OP_ADD 0
`define ALU_OP_SUB 1
`define ALU_OP_ARITH_LOGIC 2
`define ALU_OP_LUI 3
`define ALU_OP_AUIPC 4
`define ALU_OP_BRANCH 5
`define ALU_OP_AMO 6
`define ALU_OP_LAST 7
//
// amo operation
`define AMO_OP_WIDTH $clog2(`AMO_OP_LAST)
`define AMO_OP_ADD_W 0
`define AMO_OP_SWAP_W 1
`define AMO_OP_LR_W 2
`define AMO_OP_SC_W 3
`define AMO_OP_XOR_W 4
`define AMO_OP_AND_W 5
`define AMO_OP_OR_W 6
`define AMO_OP_MIN_W 7
`define AMO_OP_MAX_W 8
`define AMO_OP_MINU_W 9
`define AMO_OP_MAXU_W 10
`define AMO_OP_LAST 11

// multiplier operation
`define MUL_OP_WIDTH $clog2(`MUL_OP_LAST)
`define MUL_OP_MUL 0
`define MUL_OP_MULH 1
`define MUL_OP_MULSU 2
`define MUL_OP_MULU 3
`define MUL_OP_LAST 4

// divider operation
`define DIV_OP_WIDTH $clog2(`DIV_OP_LAST)
`define DIV_OP_DIV 0
`define DIV_OP_DIVU 1
`define DIV_OP_REM 2
`define DIV_OP_REMU 3
`define DIV_OP_LAST 4

// store operation
`define STORE_OP_WIDTH $clog2(`STORE_OP_LAST)
`define STORE_OP_SB 0
`define STORE_OP_SH 1
`define STORE_OP_SW 2
`define STORE_OP_LAST 3

// load operation
`define LOAD_OP_WIDTH $clog2(`LOAD_OP_LAST)
`define LOAD_OP_LB 0
`define LOAD_OP_LBU 1
`define LOAD_OP_LH 2
`define LOAD_OP_LHU 3
`define LOAD_OP_LW 4
`define LOAD_OP_LAST 5

// ALU
`define ALU_CTRL_WIDTH $clog2(`ALU_CTRL_LAST)
// ADD bit0 should be 0 for alu add/sub
`define ALU_CTRL_ADD_ADDI 0
`define ALU_CTRL_SUB 1

`define ALU_CTRL_XOR_XORI 2
`define ALU_CTRL_OR_ORI 3
`define ALU_CTRL_AND_ANDI 4
`define ALU_CTRL_SLL_SLLI 5
`define ALU_CTRL_SRL_SRLI 6
`define ALU_CTRL_SRA_SRAI 7
`define ALU_CTRL_SLT_SLTI 8
`define ALU_CTRL_AUIPC 9
`define ALU_CTRL_LUI 10
`define ALU_CTRL_SLTU_SLTIU 11
`define ALU_CTRL_BEQ 12
`define ALU_CTRL_BNE 13
`define ALU_CTRL_BLT 14
`define ALU_CTRL_BGE 15
`define ALU_CTRL_BLTU 16
`define ALU_CTRL_BGEU 17
`define ALU_CTRL_MIN 18
`define ALU_CTRL_MAX 19
`define ALU_CTRL_MINU 20
`define ALU_CTRL_MAXU 21
`define ALU_CTRL_LAST 22

// csr operation
`define CSR_OP_WIDTH $clog2(`CSR_OP_LAST)
`define CSR_OP_CSRRW 0
`define CSR_OP_CSRRS 1
`define CSR_OP_CSRRC 2
`define CSR_OP_CSRRWI 3
`define CSR_OP_CSRRSI 4
`define CSR_OP_CSRRCI 5
`define CSR_OP_NA 6
`define CSR_OP_LAST 7


`endif  // RISCV_DEFINES_VH

// --- csr_utilities.vh ---
/*
 *  kianv.v - RISC-V rv32ima
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`ifndef CSR_UTILITIES_VH
`define CSR_UTILITIES_VH

// Unprivileged Counter/Timers
`define CSR_REG_CYCLE 12'h C00
`define CSR_REG_CYCLEH 12'h C80
`define CSR_REG_INSTRET 12'h C02
`define CSR_REG_INSTRETH 12'h C82
`define CSR_REG_TIME 12'h C01
`define CSR_REG_TIMEH 12'h C81

// Machine Trap Setup
`define CSR_REG_MSTATUS 12'h 300
`define CSR_REG_MISA 12'h 301
`define CSR_REG_MIE 12'h 304
`define CSR_REG_MTVEC 12'h 305

// Machine Trap Handling
`define CSR_REG_MSCRATCH 12'h 340
`define CSR_REG_MEPC 12'h 341
`define CSR_REG_MCAUSE 12'h 342
`define CSR_REG_MTVAL 12'h 343
`define CSR_REG_MIP 12'h 344

`define CSR_REG_MCOUNTEREN 12'h 306

`define CSR_REG_MHARTID 12'h f14
`define CSR_REG_MVENDORID 12'h f11
`define CSR_REG_MARCHID 12'h f12

// Machine-Level CSRs
// custrom read-only
`define CSR_PRIVILEGE_MODE 12'h fc0 // machine privilege mode


// RISC-V CSR instruction opcodes (7-bit) and funct3 (3-bit)
`define CSR_OPCODE `SYSTEM_OPCODE
`define CSR_FUNCT3_RW 3'b001
`define CSR_FUNCT3_RS 3'b010
`define CSR_FUNCT3_RC 3'b011
`define CSR_FUNCT3_RWI 3'b101
`define CSR_FUNCT3_RSI 3'b110
`define CSR_FUNCT3_RCI 3'b111

`endif

// --- defines_soc.vh ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`ifndef KIANV_SOC
`define KIANV_SOC

`define BAUDRATE 2000000

`define REBOOT_ADDR 32'h 11_100_000
`define REBOOT_DATA 16'h 7777
`define HALT_DATA 16'h 5555

`define UART_TX_ADDR 32'h 10_000_000
`define UART_RX_ADDR 32'h 10_000_000
`define UART_LSR_ADDR 32'h 10_000_005
`define DIV_ADDR 32'h 10_000_010


//`define FAKE_MULTIPLIER

`define QUAD_SPI_FLASH_MODE 1'b1

`define SDRAM_MEM_ADDR_START 32'h 80_000_000
`define SDRAM_SIZE (1024*1024*8)
`define SDRAM_MEM_ADDR_END ((`SDRAM_MEM_ADDR_START) + (`SDRAM_SIZE))

`define SPI_NOR_MEM_ADDR_START 32'h 20_000_000

`define SPI_MEMORY_OFFSET (1024*1024)
`define SPI_NOR_MEM_ADDR_END ((`SPI_NOR_MEM_ADDR_START) + (16*1024*1024))

`define RESET_ADDR (`SPI_NOR_MEM_ADDR_START + `SPI_MEMORY_OFFSET)
//`define RESET_ADDR        0
`define FIRMWARE_BRAM ""
`define BRAM_WORDS (1024*2)

`endif

// --- mcause.vh ---
/*
 *  kianv.v - RISC-V rv32ima
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`ifndef MCAUSE_VH
`define MCAUSE_VH
// Exception codes
`define EXC_INSTR_ADDR_MISALIGNED 32'h00000000
`define EXC_INSTR_ACCESS_FAULT 32'h00000001
`define EXC_ILLEGAL_INSTRUCTION 32'h00000002
`define EXC_BREAKPOINT 32'h00000003
`define EXC_LOAD_AMO_ADDR_MISALIGNED 32'h00000004
`define EXC_LOAD_AMO_ACCESS_FAULT 32'h00000005
`define EXC_STORE_AMO_ADDR_MISALIGNED 32'h00000006
`define EXC_STORE_AMO_ACCESS_FAULT 32'h00000007
`define EXC_ECALL_FROM_UMODE 32'h00000008
`define EXC_ECALL_FROM_SMODE 32'h00000009
`define EXC_ECALL_FROM_MMODE 32'h0000000B
`define EXC_INSTR_PAGE_FAULT 32'h0000000C
`define EXC_LOAD_PAGE_FAULT 32'h0000000D
`define EXC_STORE_AMO_PAGE_FAULT 32'h0000000F

// Interrupt codes
`define INTERRUPT_USER_SOFTWARE 32'h80000000
`define INTERRUPT_SUPERVISOR_SOFTWARE 32'h80000001
`define INTERRUPT_MACHINE_SOFTWARE 32'h80000003
`define INTERRUPT_USER_TIMER 32'h80000004
`define INTERRUPT_SUPERVISOR_TIMER 32'h80000005
`define INTERRUPT_MACHINE_TIMER 32'h80000007
`define INTERRUPT_USER_EXTERNAL 32'h80000008
`define INTERRUPT_SUPERVISOR_EXTERNAL 32'h80000009
`define INTERRUPT_MACHINE_EXTERNAL 32'h8000000B
`endif

// --- misa.vh ---
/*
 *  kianv.v - RISC-V rv32ima
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`ifndef MISA_VH
`define MISA_VH

`define MISA_MXL_RV32 2'b01
`define MISA_EXTENSION_A 5'd0
`define MISA_EXTENSION_B 5'd1
`define MISA_EXTENSION_C 5'd2
`define MISA_EXTENSION_D 5'd3
`define MISA_EXTENSION_E 5'd4
`define MISA_EXTENSION_F 5'd5
`define MISA_EXTENSION_G 5'd6
`define MISA_EXTENSION_H 5'd7
`define MISA_EXTENSION_I 5'd8
`define MISA_EXTENSION_J 5'd9
`define MISA_EXTENSION_K 5'd10
`define MISA_EXTENSION_L 5'd11
`define MISA_EXTENSION_M 5'd12
`define MISA_EXTENSION_N 5'd13
`define MISA_EXTENSION_O 5'd14
`define MISA_EXTENSION_P 5'd15
`define MISA_EXTENSION_Q 5'd16
`define MISA_EXTENSION_R 5'd17
`define MISA_EXTENSION_S 5'd18
`define MISA_EXTENSION_T 5'd19
`define MISA_EXTENSION_U 5'd20
`define MISA_EXTENSION_V 5'd21
`define MISA_EXTENSION_W 5'd22
`define MISA_EXTENSION_X 5'd23
`define MISA_EXTENSION_Y 5'd24
`define MISA_EXTENSION_Z 5'd25

`define IS_EXTENSION_SUPPORTED(MXL, Extensions, Ext_To_Check) \
  ((MXL) == `MISA_MXL_RV32) && (((Extensions) >> (Ext_To_Check)) & 1'b1)
`define SET_MISA_VALUE(MXL) (MXL << 30)
`define MISA_EXTENSION_BIT(extension) (1 << extension)

`endif

// --- riscv_priv_csr_status.vh ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 */
/* verilog_format: off */
`ifndef RISCV_PRIV_CSR_STATUS_VH
`define RISCV_PRIV_CSR_STATUS_VH
// RISC-V privilege levels
// M       -> Simple embedded systems
// M, U    -> Secure embedded systems
// M, S, U -> System running Unix-like operating systems
// RISC-V privilege levels
`define PRIVILEGE_MODE_USER 0
`define PRIVILEGE_MODE_SUPERVISOR 1
`define PRIVILEGE_MODE_RESERVED 2
`define PRIVILEGE_MODE_MACHINE 3
`define IS_USER(privilege) (privilege == `PRIVILEGE_MODE_USER)
`define IS_SUPERVISOR(privilege) (privilege == `PRIVILEGE_MODE_SUPERVISOR)
`define IS_MACHINE(privilege) (privilege == `PRIVILEGE_MODE_MACHINE)

`define MIP_MTIP_BIT       7
`define MIE_MTIP_BIT       7

`define MIP_MTIP_MASK      (1<< `MIP_MTIP_BIT)
`define MIE_MTIP_MASK      (1<< `MIE_MTIP_BIT)

`define MIP_MSIP_BIT       3
`define MIE_MSIP_BIT       3

`define MIP_MSIP_MASK      (1<< `MIP_MSIP_BIT)
`define MIE_MSIP_MASK      (1<< `MIE_MSIP_BIT)

`define MSTATUS_MPP_BIT 11
`define MSTATUS_MPP_WIDTH 2
`define MSTATUS_MPIE_BIT 7
`define MSTATUS_MIE_BIT 3
`define MSTATUS_MPRV_BIT 17

`define MSTATUS_MIE_MASK (1 << `MSTATUS_MIE_BIT)
`define MSTATUS_MPIE_MASK (1 << `MSTATUS_MPIE_BIT)
`define MSTATUS_MPP_MASK (((1 << `MSTATUS_MPP_WIDTH) - 1) << `MSTATUS_MPP_BIT)
`define MSTATUS_MPRV_MASK (1 << `MSTATUS_MPRV_BIT)

`define GET_MIE_MTIP(mie) ((mie >> `MIE_MTIP_BIT) & 1)
`define GET_MIE_MSIP(mie) ((mie >> `MIE_MSIP_BIT) & 1)

`define GET_MIP_MTIP(mip)  ((mip) >> `MIP_MTIP_BIT) & 1'b1
`define GET_MIP_MSIP(mip)  ((mip) >> `MIP_MSIP_BIT) & 1'b1
`define SET_MIP_MSIP(mip, value)  ((mip) & ~(1 << `MIP_MSIP_BIT)) | ((value) << `MIP_MSIP_BIT)
`define SET_MIP_MTIP(mip, value)  ((mip) & ~(1 << `MIP_MTIP_BIT)) | ((value) << `MIP_MTIP_BIT)
`define SET_MIP_MEIP(mip, value)  ((mip) & ~(1 << `MIP_MEIP_BIT)) | ((value) << `MIP_MEIP_BIT)


`define SET_MSTATUS_MPP(mstatus, new_privilege_mode) ((mstatus) & ~`MSTATUS_MPP_MASK) | (((new_privilege_mode) & 2'b11) << `MSTATUS_MPP_BIT)
`define GET_MSTATUS_MPP(mstatus) ((mstatus) >> `MSTATUS_MPP_BIT) & 2'b11

`define SET_MSTATUS_MPIE(mstatus, mpi_value) ((mstatus) & ~`MSTATUS_MPIE_MASK) | (((mpi_value) & 1'b1) << `MSTATUS_MPIE_BIT)
`define GET_MSTATUS_MPIE(mstatus) ((mstatus) >> `MSTATUS_MPIE_BIT) & 1'b1

`define SET_MSTATUS_MIE(mstatus, value) ((mstatus) & ~`MSTATUS_MIE_MASK) | (((value) & 1'b1) << `MSTATUS_MIE_BIT)
`define GET_MSTATUS_MIE(mstatus) ((mstatus) >> `MSTATUS_MIE_BIT) & 1'b1

`define SET_MSTATUS_MPRV(mstatus, mprv_value) ((mstatus) & ~`MSTATUS_MPRV_MASK) | (((mprv_value) & 1'b1) << `MSTATUS_MPRV_BIT)
`define GET_MSTATUS_MPRV(mstatus) ((mstatus) >> `MSTATUS_MPRV_BIT) & 1'b1

`define IS_EBREAK(opcode, funct3, funct7, rs1, rs2, rd) ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h00100073)
`define IS_ECALL(opcode, funct3, funct7, rs1, rs2, rd) ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h00000073)
`define IS_MRET(opcode, funct3, funct7, rs1, rs2, rd) ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h30200073)
`define IS_WFI(opcode, funct3, funct7, rs1, rs2, rd) ({funct7, rs2, rs1, funct3, rd, opcode} == 32'h10500073)

`define IRQ_M_TIMER 7

`endif
/* verilog_format: on */

// --- rv32_amo_opcodes.vh ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 */
`define RV32_AMO_OPCODE 7'h2F
`define RV32_AMO_FUNCT3 3'h2
`define RV32_AMOADD_W 5'h00
`define RV32_AMOSWAP_W 5'h01
`define RV32_LR_W 5'h02
`define RV32_SC_W 5'h03
`define RV32_AMOXOR_W 5'h04
`define RV32_AMOAND_W 5'h0C
`define RV32_AMOOR_W 5'h08
`define RV32_AMOMIN_W 5'h10
`define RV32_AMOMAX_W 5'h14
`define RV32_AMOMINU_W 5'h18
`define RV32_AMOMAXU_W 5'h1c
`define RV32_FENCE_OPCODE 7'b0001111

/* verilog_format: off */
`define RV32_IS_AMO_INSTRUCTION(opcode, funct3) (opcode == `RV32_AMO_OPCODE && funct3 == `RV32_AMO_FUNCT3)
`define RV32_IS_AMOADD_W(funct5) (funct5 == `RV32_AMOADD_W)
`define RV32_IS_AMOSWAP_W(funct5) (funct5 == `RV32_AMOSWAP_W)
`define RV32_IS_LR_W(funct5) (funct5 == `RV32_LR_W)
`define RV32_IS_SC_W(funct5) (funct5 == `RV32_SC_W)
`define RV32_IS_AMOXOR_W(funct5) ( funct5 == `RV32_AMOXOR_W)
`define RV32_IS_AMOAND_W(funct5) ( funct5 == `RV32_AMOAND_W)
`define RV32_IS_AMOOR_W(funct5) ( funct5 == `RV32_AMOOR_W)
`define RV32_IS_AMOMIN_W(funct5) ( funct5 == `RV32_AMOMIN_W)
`define RV32_IS_AMOMAX_W(funct5) ( funct5 == `RV32_AMOMAX_W)
`define RV32_IS_AMOMINU_W(funct5) ( funct5 == `RV32_AMOMINU_W)
`define RV32_IS_AMOMAXU_W(funct5) ( funct5 == `RV32_AMOMAXU_W)
`define RV32_IS_FENCE(opcode) ( opcode == `RV32_FENCE_OPCODE)
/* verilog_format: on */

// --- cells.v ---
/*
This file provides the mapping from the Wokwi modules to Verilog HDL

It's only needed for Wokwi designs

*/
`define default_netname none

module buffer_cell (
    input  wire in,
    output wire out
);
  assign out = in;
endmodule

module and_cell (
    input  wire a,
    input  wire b,
    output wire out
);

  assign out = a & b;
endmodule

module or_cell (
    input  wire a,
    input  wire b,
    output wire out
);

  assign out = a | b;
endmodule

module xor_cell (
    input  wire a,
    input  wire b,
    output wire out
);

  assign out = a ^ b;
endmodule

module nand_cell (
    input  wire a,
    input  wire b,
    output wire out
);

  assign out = !(a & b);
endmodule

module not_cell (
    input  wire in,
    output wire out
);

  assign out = !in;
endmodule

module mux_cell (
    input  wire a,
    input  wire b,
    input  wire sel,
    output wire out
);

  assign out = sel ? b : a;
endmodule

module dff_cell (
    input  wire clk,
    input  wire d,
    output reg  q,
    output wire notq
);

  assign notq = !q;
  always @(posedge clk) q <= d;

endmodule

module dffsr_cell (
    input  wire clk,
    input  wire d,
    input  wire s,
    input  wire r,
    output reg  q,
    output wire notq
);

  assign notq = !q;

  always @(posedge clk or posedge s or posedge r) begin
    if (r) q <= 0;
    else if (s) q <= 1;
    else q <= d;
  end
endmodule

// --- design_elements.v ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2022/23 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none
/* verilator lint_off MULTITOP */

module mux2 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH -1:0] d0,
    d1,
    input  wire              s,
    output wire [WIDTH -1:0] y
);

  assign y = s ? d1 : d0;
endmodule

module mux3 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH -1:0] d0,
    d1,
    d2,
    input  wire [       1:0] s,
    output wire [WIDTH -1:0] y
);

  assign y = s[1] ? d2 : (s[0] ? d1 : d0);
endmodule

module mux4 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH -1:0] d0,
    d1,
    d2,
    d3,
    input  wire [       1:0] s,
    output wire [WIDTH -1:0] y
);

  wire [WIDTH -1:0] low, high;

  mux2 lowmux (
      d0,
      d1,
      s[0],
      low
  );
  mux2 highmux (
      d2,
      d3,
      s[0],
      high
  );
  mux2 finalmux (
      low,
      high,
      s[1],
      y
  );
endmodule

module mux5 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH -1:0] d0,
    d1,
    d2,
    d3,
    d4,
    input  wire [       2:0] s,
    output wire [WIDTH -1:0] y

);

  assign y = (s == 0) ? d0 : (s == 1) ? d1 : (s == 2) ? d2 : (s == 3) ? d3 : d4;

endmodule

module mux6 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH -1:0] d0,
    d1,
    d2,
    d3,
    d4,
    d5,
    input  wire [       2:0] s,
    output wire [WIDTH -1:0] y

);

  assign y = (s == 0) ? d0 : (s == 1) ? d1 : (s == 2) ? d2 : (s == 3) ? d3 : (s == 4) ? d4 : d5;

endmodule

module dlatch #(
    parameter WIDTH = 32
) (
    input wire clk,
    input wire [WIDTH -1:0] d,
    output reg [WIDTH -1:0] q
);
  always @(posedge clk) q <= d;
endmodule

module dff #(
    parameter WIDTH  = 32,
    parameter PRESET = 0
) (
    input wire resetn,
    input wire clk,
    input wire en,
    input wire [WIDTH -1:0] d,
    output reg [WIDTH -1:0] q
);
  always @(posedge clk)
    if (!resetn) q <= PRESET;
    else if (en) q <= d;

endmodule
module counter #(
    parameter WIDTH = 32
) (
    input wire resetn,
    input wire clk,
    input wire inc,
    output reg [WIDTH -1:0] q
);
  always @(posedge clk)
    if (!resetn) q <= 0;
    else if (inc) q <= q + 1;

endmodule
/* verilator lint_on MULTITOP */

// --- alu.v ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2022 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none

module alu (
    input  wire [                31:0] a,
    input  wire [                31:0] b,
    input  wire [`ALU_CTRL_WIDTH -1:0] alucontrol,
    output reg  [                31:0] result,
    output wire                        zero
);


  wire is_beq = alucontrol == `ALU_CTRL_BEQ;
  wire is_bne = alucontrol == `ALU_CTRL_BNE;
  wire is_blt = alucontrol == `ALU_CTRL_BLT;
  wire is_bge = alucontrol == `ALU_CTRL_BGE;
  wire is_bltu = alucontrol == `ALU_CTRL_BLTU;
  wire is_bgeu = alucontrol == `ALU_CTRL_BGEU;
  wire is_slt_slti = alucontrol == `ALU_CTRL_SLT_SLTI;
  wire is_sltu_sltiu = alucontrol == `ALU_CTRL_SLTU_SLTIU;
  wire is_sub_ctrl = alucontrol == `ALU_CTRL_SUB;
  wire is_amo_min_max = alucontrol == `ALU_CTRL_MIN || alucontrol == `ALU_CTRL_MAX ||
         alucontrol == `ALU_CTRL_MINU || alucontrol == `ALU_CTRL_MAXU;

  wire is_sub = is_sub_ctrl || is_beq || is_bne || is_blt || is_bge ||
         is_bltu || is_bgeu || is_slt_slti || is_amo_min_max || is_sltu_sltiu;


  wire [31:0] condinv = is_sub ? ~b : b;

  // seen 33 Bit sum from Bruno's Levy
  // with that approach I could map all branch to LT, LTU
  wire [32:0] sum = {1'b1, condinv} + {1'b0, a} + {32'b0, is_sub};
  wire LT = (a[31] ^ b[31]) ? a[31] : sum[32];
  wire LTU = sum[32];

  wire [31:0] sltx_sltux_rslt = {31'b0, is_slt_slti ? LT : LTU};
  wire [63:0] sext_rs1 = {{32{a[31]}}, a};
  wire [63:0] sra_srai_rslt = sext_rs1 >> b[4:0];

  wire is_sum_zero = sum[31:0] == 32'b0;

  always @* begin
    case (alucontrol)
      `ALU_CTRL_ADD_ADDI:   result = sum[31:0];
      `ALU_CTRL_SUB:        result = sum[31:0];
      `ALU_CTRL_XOR_XORI:   result = a ^ b;
      `ALU_CTRL_OR_ORI:     result = a | b;
      `ALU_CTRL_AND_ANDI:   result = a & b;
      `ALU_CTRL_SLL_SLLI:   result = a << b[4:0];
      `ALU_CTRL_SRL_SRLI:   result = a >> b[4:0];
      `ALU_CTRL_SRA_SRAI:   result = sra_srai_rslt[31:0];
      `ALU_CTRL_SLT_SLTI:   result = (a[31] == b[31]) ? sltx_sltux_rslt : {31'b0, a[31]};
      `ALU_CTRL_SLTU_SLTIU: result = sltx_sltux_rslt;
      `ALU_CTRL_MIN:        result = LT ? a : b;
      `ALU_CTRL_MAX:        result = !LT ? a : b;
      `ALU_CTRL_MINU:       result = LTU ? a : b;
      `ALU_CTRL_MAXU:       result = !LTU ? a : b;
      `ALU_CTRL_LUI:        result = b;
      `ALU_CTRL_AUIPC:      result = sum[31:0];
      default: begin
        case (1'b1)
          is_beq:  result = {31'b0, is_sum_zero};
          is_bne:  result = {31'b0, !is_sum_zero};
          is_blt:  result = {31'b0, LT};
          is_bge:  result = {31'b0, !LT};
          is_bltu: result = {31'b0, LTU};
          is_bgeu: result = {31'b0, !LTU};
          default: result = 32'b0;
        endcase
      end
    endcase
  end

  assign zero = result == 32'b0;
endmodule

// --- alu_decoder.v ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2022 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none



module alu_decoder
    (
        input  wire                          imm_bit10,
        input  wire                          op_bit5,
        input  wire [ 2:                  0] funct3,
        input  wire                          funct7b5,
        input  wire [ `ALU_OP_WIDTH   -1: 0] ALUOp,
        input  wire [ `AMO_OP_WIDTH   -1: 0] AMOop,
        output reg  [ `ALU_CTRL_WIDTH -1: 0] ALUControl
    );

    wire is_rtype_sub    =  op_bit5 & funct7b5;
    wire is_srl_srli     = (op_bit5 && !funct7b5) || (!op_bit5 && !imm_bit10);

    always @(*) begin
        case (ALUOp)
            `ALU_OP_ADD    :   ALUControl = `ALU_CTRL_ADD_ADDI;
            `ALU_OP_SUB    :   ALUControl = `ALU_CTRL_SUB;
            `ALU_OP_AUIPC  :   ALUControl = `ALU_CTRL_AUIPC;
            `ALU_OP_LUI    :   ALUControl = `ALU_CTRL_LUI;
            `ALU_OP_BRANCH : begin
                case (funct3)
                    3'b 000: ALUControl = `ALU_CTRL_BEQ;
                    3'b 001: ALUControl = `ALU_CTRL_BNE;
                    3'b 100: ALUControl = `ALU_CTRL_BLT;
                    3'b 101: ALUControl = `ALU_CTRL_BGE;
                    3'b 110: ALUControl = `ALU_CTRL_BLTU;
                    3'b 111: ALUControl = `ALU_CTRL_BGEU;
                    default:
                        /* verilator lint_off WIDTH */
                        ALUControl = 'hx;
                    /* verilator lint_on WIDTH */
                endcase
            end
            `ALU_OP_AMO: begin
                case (AMOop)
                    `AMO_OP_ADD_W     : ALUControl = `ALU_CTRL_ADD_ADDI;
                    `AMO_OP_SWAP_W    : ALUControl = `ALU_CTRL_ADD_ADDI; // fixme
                    `AMO_OP_LR_W      : ALUControl = `ALU_CTRL_ADD_ADDI;
                    `AMO_OP_SC_W      : ALUControl = `ALU_CTRL_ADD_ADDI; // fixme
                    `AMO_OP_XOR_W     : ALUControl = `ALU_CTRL_XOR_XORI;
                    `AMO_OP_AND_W     : ALUControl = `ALU_CTRL_AND_ANDI;
                    `AMO_OP_OR_W      : ALUControl = `ALU_CTRL_OR_ORI;
                    `AMO_OP_MIN_W     : ALUControl = `ALU_CTRL_MIN;
                    `AMO_OP_MAX_W     : ALUControl = `ALU_CTRL_MAX; // fixme: !min
                    `AMO_OP_MINU_W    : ALUControl = `ALU_CTRL_MINU;
                    `AMO_OP_MAXU_W    : ALUControl = `ALU_CTRL_MAXU; // fixme: !min

                    default:
                        /* verilator lint_off WIDTH */
                        ALUControl = 'hx;
                    /* verilator lint_on WIDTH */
                endcase
            end
            `ALU_OP_ARITH_LOGIC: begin
                case (funct3)
                    3'b 000: ALUControl = is_rtype_sub ? `ALU_CTRL_SUB : `ALU_CTRL_ADD_ADDI;
                    3'b 100: ALUControl = `ALU_CTRL_XOR_XORI;
                    3'b 110: ALUControl = `ALU_CTRL_OR_ORI;
                    3'b 111: ALUControl = `ALU_CTRL_AND_ANDI;
                    3'b 010: ALUControl = `ALU_CTRL_SLT_SLTI;
                    3'b 001: ALUControl = `ALU_CTRL_SLL_SLLI;
                    3'b 011: ALUControl = `ALU_CTRL_SLTU_SLTIU;
                    3'b 101: ALUControl = is_srl_srli ? `ALU_CTRL_SRL_SRLI : `ALU_CTRL_SRA_SRAI;
                    default:
                        /* verilator lint_off WIDTH */
                        ALUControl = 'hx;
                    /* verilator lint_on WIDTH */
                endcase
            end
            default:
                /* verilator lint_off WIDTH */
                ALUControl = 'hx;
            /* verilator lint_on WIDTH */
        endcase
    end

endmodule

// --- extend.v ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2022 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none
module extend (
    input  wire [31:7] instr,
    input  wire [ 2:0] immsrc,
    output reg  [31:0] immext
);

  always @(*) begin
    case (immsrc)
      `IMMSRC_ITYPE: immext = {{20{instr[31]}}, instr[31:20]};
      `IMMSRC_STYPE: immext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
      `IMMSRC_BTYPE: immext = {{20{instr[31]}}, instr[7:7], instr[30:25], instr[11:8], 1'b0};
      `IMMSRC_JTYPE: immext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
      `IMMSRC_UTYPE: immext = {instr[31:12], 12'b0};
      default:       immext = 32'b0;
    endcase
  end
endmodule

// --- load_alignment.v ---
/*
 *  kianv harris multicycle RISC-V rv32ima
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none
module load_alignment (
    input  wire [                 1:0] addr,
    input  wire [`LOAD_OP_WIDTH  -1:0] LOADop,
    input  wire [                31:0] data,
    output reg  [                31:0] result,
    output reg                         unaligned_access
);

  wire is_lb = `LOAD_OP_LB == LOADop;
  wire is_lbu = `LOAD_OP_LBU == LOADop;

  wire is_lh = `LOAD_OP_LH == LOADop;
  wire is_lhu = `LOAD_OP_LHU == LOADop;

  wire is_lw = `LOAD_OP_LW == LOADop;

  always @* begin
    result = 'hx;
    unaligned_access = 1'b0;
    if (is_lb | is_lbu) begin
      result[7:0] =
                  addr[1:0] == 2'b00 ? data[7  :0] :
                  addr[1:0] == 2'b01 ? data[15 :8] :
                  addr[1:0] == 2'b10 ? data[23:16] :
                  addr[1:0] == 2'b11 ? data[31:24] : 8'hx;
      result = {is_lbu ? 24'b0 : {24{result[7]}}, result[7:0]};
      unaligned_access = 1'b0;
    end

    if (is_lh | is_lhu) begin
      result[15:0] = ~addr[1] ? data[15 : 0] : addr[1] ? data[31 : 16] : 16'hx;
      result = {is_lhu ? 16'b0 : {16{result[15]}}, result[15:0]};
      unaligned_access = addr[0];
    end

    if (is_lw) begin
      result = data;
      unaligned_access = addr[1:0] != 2'b00;
    end
  end

endmodule

// --- load_decoder.v ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2022 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none

module load_decoder
    (
        input  wire [ 2: 0] funct3,
        input wire amo_data_load,
        output reg  [`LOAD_OP_WIDTH -1: 0] LOADop
    );
    wire is_lb      = funct3 == 3'b 000;
    wire is_lh      = funct3 == 3'b 001;
    wire is_lw      = funct3 == 3'b 010;
    wire is_lbu     = funct3 == 3'b 100;
    wire is_lhu     = funct3 == 3'b 101;

    always @(*) begin
        if (!amo_data_load) begin
            case (1'b1)
                is_lb  : LOADop = `LOAD_OP_LB;
                is_lh  : LOADop = `LOAD_OP_LH;
                is_lw  : LOADop = `LOAD_OP_LW;
                is_lbu : LOADop = `LOAD_OP_LBU;
                is_lhu : LOADop = `LOAD_OP_LHU;
                default:
                    /* verilator lint_off WIDTH */
                    LOADop = 'hxx;
                /* verilator lint_on WIDTH */
            endcase
        end else begin
            LOADop = `LOAD_OP_LW;
        end
    end

endmodule

// --- store_alignment.v ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2022 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none


module store_alignment (
    input  wire [                 1:0] addr,
    input  wire [`STORE_OP_WIDTH -1:0] STOREop,
    input  wire [                31:0] data,
    output reg  [                31:0] result,
    output reg  [                 3:0] wmask,
    output reg                         unaligned_access
);

  always @* begin
    unaligned_access = 1'b0;
    wmask = 0;
    result = 'hx;

    case (STOREop)
      (`STORE_OP_SB): begin
        result[7:0] = addr[1:0] == 2'b00 ? data[7:0] : 8'hx;
        result[15:8] = addr[1:0] == 2'b01 ? data[7:0] : 8'hx;
        result[23:16] = addr[1:0] == 2'b10 ? data[7:0] : 8'hx;
        result[31:24] = addr[1:0] == 2'b11 ? data[7:0] : 8'hx;
        wmask          = addr[1:0] == 2'b00 ? 4'b 0001 :
                    addr[1:0] == 2'b01 ? 4'b 0010 :
                        addr[1:0] == 2'b10 ? 4'b 0100 : 4'b 1000;
        unaligned_access = 1'b0;
      end
      (`STORE_OP_SH): begin
        result[15:0]     = ~addr[1] ? data[15:0] : 16'hx;
        result[31:16]    = addr[1] ? data[15:0] : 16'hx;
        wmask            = addr[1] ? 4'b1100 : 4'b0011;
        unaligned_access = addr[0];
      end
      (`STORE_OP_SW): begin
        result = data;
        wmask = 4'b1111;
        unaligned_access = addr[1:0] != 2'b00;
      end
      default: begin
        result = 'hx;
        wmask = 4'b0000;
        unaligned_access = 1'b0;
      end
    endcase

  end
endmodule

// --- store_decoder.v ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2022 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none

module store_decoder
    (
        input  wire [ 2: 0] funct3,
        input wire amo_operation_store,
        output reg  [`STORE_OP_WIDTH -1: 0] STOREop
    );
    wire is_sb      = funct3[1:0] == 2'b 00;
    wire is_sh      = funct3[1:0] == 2'b 01;
    wire is_sw      = funct3[1:0] == 2'b 10;

    always @(*) begin
        if (!amo_operation_store) begin
            case (1'b1)
                is_sb : STOREop = `STORE_OP_SB;
                is_sh : STOREop = `STORE_OP_SH;
                is_sw : STOREop = `STORE_OP_SW;
                default:
                    /* verilator lint_off WIDTH */
                    STOREop = 'hxx;
                /* verilator lint_on WIDTH */
            endcase
        end else begin
            STOREop = `STORE_OP_SW;
        end
    end
endmodule

// --- register_file.v ---
/*
 *  kianv harris multicycle RISC-V rv32ima
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none

/* verilator lint_off UNUSEDSIGNAL */
module register_file #(
    parameter REGISTER_DEPTH = 32  // rv32e = 16; rv32i = 32
) (
    input  wire        clk,
    input  wire        we,
    input  wire [ 4:0] A1,
    input  wire [ 4:0] A2,
    input  wire [ 4:0] A3,
    input  wire [31:0] wd,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);
  reg [31:0] bank0[0:REGISTER_DEPTH -1];

  always @(posedge clk) begin

    if (we && A3 != 0) begin
      bank0[A3] <= wd;
    end
  end

  assign rd1 = A1 != 0 ? bank0[A1] : 32'b0;
  assign rd2 = A2 != 0 ? bank0[A2] : 32'b0;

endmodule
/* verilator lint_off UNUSEDSIGNAL */

// --- multiplier.v ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2022 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none

module multiplier (
    input  wire                        clk,
    input  wire                        resetn,
    input  wire [              31 : 0] factor1,
    input  wire [              31 : 0] factor2,
    input  wire [`MUL_OP_WIDTH -1 : 0] MULop,
    output wire [              31 : 0] product,
    input  wire                        valid,
    output reg                         ready
);

  wire is_mulh = MULop == `MUL_OP_MULH;
  wire is_mulsu = MULop == `MUL_OP_MULSU;
  wire is_mulu = MULop == `MUL_OP_MULU;

  wire factor1_is_signed = is_mulh | is_mulsu;
  wire factor2_is_signed = is_mulh;

  // multiplication
  reg [63:0] rslt;
  reg [31:0] factor1_abs;
  reg [31:0] factor2_abs;
  reg [4:0] bit_idx;

  localparam IDLE_BIT = 0;
  localparam CALC_BIT = 1;
  localparam READY_BIT = 2;

  localparam IDLE = 1 << IDLE_BIT;
  localparam CALC = 1 << CALC_BIT;
  localparam READY = 1 << READY_BIT;

  localparam NR_STATES = 3;

  (* onehot *)
  reg [NR_STATES-1:0] state;

  wire [31:0] rslt_upper_low = (is_mulh | is_mulu | is_mulsu) ? rslt[63:32] : rslt[31:0];
  always @(posedge clk) begin
    if (!resetn) begin
      state   <= IDLE;
      ready   <= 1'b0;
      bit_idx <= 0;
    end else begin

      (* parallel_case, full_case *)
      case (1'b1)

        state[IDLE_BIT]: begin
          ready <= 1'b0;
          if (!ready && valid) begin
            factor1_abs <= (factor1_is_signed & factor1[31]) ? ~factor1 + 1 : factor1;
            factor2_abs <= (factor2_is_signed & factor2[31]) ? ~factor2 + 1 : factor2;
            bit_idx <= 0;
            rslt <= 0;
            state <= CALC;
          end
        end

        state[CALC_BIT]: begin
`ifndef FAKE_MULTIPLIER
          /* verilator lint_off WIDTH */
          rslt <= rslt + ((factor1_abs & {32{factor2_abs[bit_idx]}}) << bit_idx);
          /* verilator lint_on WIDTH */
          bit_idx <= bit_idx + 1'b1;
          if (&bit_idx) begin
            state <= READY;
          end
`else
          rslt  <= factor1_abs * factor2_abs;
          state <= READY;
`endif
        end

        state[READY_BIT]: begin
          /* verilator lint_off WIDTH */
          rslt <= ((factor1[31] & factor1_is_signed ^ factor2[31] & factor2_is_signed)) ? ~rslt + 1 : rslt;
          /* verilator lint_on WIDTH */

          ready <= 1'b1;
          state <= IDLE;
        end

      endcase

    end

  end

  assign product = rslt_upper_low;

endmodule

// --- multiplier_decoder.v ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2022 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none
module multiplier_decoder (
    input  wire [               2:0] funct3,
    output reg  [`MUL_OP_WIDTH -1:0] MULop,
    input  wire                      mul_ext_valid,
    output wire                      mul_valid
);

  wire is_mul = funct3 == 3'b000;
  wire is_mulh = funct3 == 3'b001;
  wire is_mulsu = funct3 == 3'b010;
  wire is_mulu = funct3 == 3'b011;
  reg                               valid;

  assign mul_valid = valid & mul_ext_valid;
  always @(*) begin
    valid = 1'b1;
    case (1'b1)
      is_mul:   MULop = `MUL_OP_MUL;
      is_mulh:  MULop = `MUL_OP_MULH;
      is_mulsu: MULop = `MUL_OP_MULSU;
      is_mulu:  MULop = `MUL_OP_MULU;
      default: begin
        /* verilator lint_off WIDTH */
        MULop = 'hxx;
        /* verilator lint_on WIDTH */
        valid = 1'b0;
      end
    endcase
  end

endmodule

// --- multiplier_extension_decoder.v ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2022 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none
module multiplier_extension_decoder (
    input  wire [               2:0] funct3,
    output wire [`MUL_OP_WIDTH -1:0] MULop,
    output wire [`DIV_OP_WIDTH -1:0] DIVop,
    input  wire                      mul_ext_valid,
    output wire                      mul_valid,
    output wire                      div_valid
);

  multiplier_decoder multiplier_I (
      funct3,
      MULop,
      mul_ext_valid,
      mul_valid
  );
  divider_decoder divider_decoder_I (
      funct3,
      DIVop,
      mul_ext_valid,
      div_valid
  );

endmodule

// --- divider.v ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2022 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none

/* verilator lint_off UNUSEDSIGNAL */
module divider (
    input wire clk,
    input wire resetn,

    input  wire [              31 : 0] divident,
    input  wire [              31 : 0] divisor,
    input  wire [`DIV_OP_WIDTH -1 : 0] DIVop,
    output wire [                31:0] divOrRemRslt,
    input  wire                        valid,
    output reg                         ready,
    output wire                        div_by_zero_err
);
  // division radix-2 restoring
  localparam IDLE_BIT = 0;
  localparam CALC_BIT = 1;
  localparam READY_BIT = 2;

  localparam IDLE = 1 << IDLE_BIT;
  localparam CALC = 1 << CALC_BIT;
  localparam READY = 1 << READY_BIT;

  localparam NR_STATES = 3;

  (* onehot *)
  reg [NR_STATES-1:0] div_state;

  reg [31:0] rem_rslt;
  reg [4:0] bit_idx;

  wire is_div = DIVop == `DIV_OP_DIV;
  wire is_divu = DIVop == `DIV_OP_DIVU;
  wire is_rem = DIVop == `DIV_OP_REM;
  wire is_remu = DIVop == `DIV_OP_REMU;

  wire is_signed = is_div | is_rem;

  wire [31:0] divident_abs = (is_signed & divident[31]) ? ~divident + 1 : divident;  // divident
  wire [31:0] divisor_abs = (is_signed & divisor[31]) ? ~divisor + 1 : divisor;  // divisor
  assign div_by_zero_err = divisor_abs == 32'b0;

  reg [31:0] div_rslt;
  wire [31:0] div_rslt_next = div_rslt << 1;
  /* verilator lint_off WIDTH */
  wire [31:0] rem_rslt_next = (rem_rslt << 1) | div_rslt[31];
  /* verilator lint_on WIDTH */
  wire [32:0] rem_rslt_sub_divident = rem_rslt_next - divisor_abs;

  always @(posedge clk) begin
    if (!resetn) begin
      div_rslt  <= 0;
      rem_rslt  <= 0;
      div_state <= IDLE;
      ready     <= 1'b0;
      bit_idx   <= 0;
    end else begin

      (* parallel_case, full_case *)
      case (1'b1)

        div_state[IDLE_BIT]: begin
          ready <= 1'b0;
          if (!ready && valid) begin
            div_rslt  <= divident_abs;
            rem_rslt  <= 0;

            bit_idx   <= 0;
            div_state <= CALC;
          end
        end

        div_state[CALC_BIT]: begin
          bit_idx <= bit_idx + 1'b1;
          if (rem_rslt_sub_divident[32]) begin
            rem_rslt <= rem_rslt_next;
            /* verilator lint_off WIDTH */
            div_rslt <= div_rslt_next | 1'b0;
            /* verilator lint_on WIDTH */
          end else begin
            rem_rslt <= rem_rslt_sub_divident[31:0];
            /* verilator lint_off WIDTH */
            div_rslt <= div_rslt_next | 1'b1;
            /* verilator lint_on WIDTH */
          end

          if (&bit_idx) begin
            div_state <= READY;
          end
        end

        div_state[READY_BIT]: begin
          div_rslt  <= (is_signed & (divident[31] ^ divisor[31]) & |divisor) ? ~div_rslt + 1 : div_rslt;
          rem_rslt <= (is_signed & divident[31]) ? ~rem_rslt + 1 : rem_rslt;
          ready <= 1'b1;
          div_state <= IDLE;
        end

      endcase

    end
  end

  assign divOrRemRslt = (is_div | is_divu) ? div_rslt : rem_rslt;
endmodule
/* verilator lint_on UNUSEDSIGNAL */

// --- divider_decoder.v ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2022 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none
module divider_decoder (
    input  wire [               2:0] funct3,
    output reg  [`DIV_OP_WIDTH -1:0] DIVop,
    input  wire                      mul_ext_valid,
    output wire                      div_valid
);

  wire is_div = funct3 == 3'b100;
  wire is_divu = funct3 == 3'b101;
  wire is_rem = funct3 == 3'b110;
  wire is_remu = funct3 == 3'b111;
  reg                              valid;

  assign div_valid = valid & mul_ext_valid;

  always @(*) begin
    valid = 1'b1;
    case (1'b1)
      is_div:  DIVop = `DIV_OP_DIV;
      is_divu: DIVop = `DIV_OP_DIVU;
      is_rem:  DIVop = `DIV_OP_REM;
      is_remu: DIVop = `DIV_OP_REMU;
      default: begin
        /* verilator lint_off WIDTH */
        DIVop = 'hxx;
        /* verilator lint_on WIDTH */
        valid = 1'b0;
      end
    endcase
  end

endmodule

// --- csr_decoder.v ---
/*
 *  kianv harris multicycle RISC-V rv32im
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none
module csr_decoder (
    input wire [2:0] funct3,
    input wire [4:0] Rs1Uimm,
    input wire [4:0] Rd,
    input wire valid,
    output wire CSRwe,
    output wire CSRre,
    output reg [`CSR_OP_WIDTH -1:0] CSRop
);

  wire is_csrrw = funct3 == 3'b001;
  wire is_csrrs = funct3 == 3'b010;
  wire is_csrrc = funct3 == 3'b011;

  wire is_csrrwi = funct3 == 3'b101;
  wire is_csrrsi = funct3 == 3'b110;
  wire is_csrrci = funct3 == 3'b111;

  reg we;
  reg re;

  assign CSRwe = we && valid;
  assign CSRre = re && valid;

  always @(*) begin
    we = 1'b0;
    re = 1'b0;
    case (1'b1)
      // Instruction rd rs1 read CSR? write CSR?
      // CSRRW       x0  -       no      yes
      // CSRRW      !x0  -       yes     yes
      is_csrrw: begin
        we = 1'b1;
        //      re = |Rs1Uimm; // rd todo
        re = |Rd;
        CSRop = `CSR_OP_CSRRW;
      end
      // Instruction rd rs1 read CSR? write CSR?
      // CSRRS/C      -  x0      yes     no
      // CSRRS/C      - !x0      yes     yes
      is_csrrs: begin
        we = |Rs1Uimm;
        re = 1'b1;
        CSRop = `CSR_OP_CSRRS;
      end
      // Instruction rd rs1 read CSR? write CSR?
      // CSRRS/C      -  x0      yes     no
      // CSRRS/C      - !x0      yes     yes
      is_csrrc: begin
        we = |Rs1Uimm;
        re = 1'b1;
        CSRop = `CSR_OP_CSRRC;
      end

      // Instruction rd uimm read CSR? write CSR?
      // CSRRWI      x0   -      no       yes
      // CSRRWI     !x0   -      yes      yes
      is_csrrwi: begin
        we = 1'b1;
        //re = |Rs1Uimm;
        re = |Rd;
        CSRop = `CSR_OP_CSRRWI;
      end
      // Instruction rd uimm read CSR? write CSR?
      // CSRRS/CI     -   0      yes      no
      // CSRRS/CI     -  !0      yes      yes
      is_csrrsi: begin
        we = |Rs1Uimm;
        re = 1'b1;
        CSRop = `CSR_OP_CSRRSI;
      end
      // Instruction rd uimm read CSR? write CSR?
      // CSRRS/CI     -   0      yes      no
      // CSRRS/CI     -  !0      yes      yes
      is_csrrci: begin
        we = |Rs1Uimm;
        re = 1'b1;
        CSRop = `CSR_OP_CSRRCI;
      end

      default: begin
        we = 1'b0;
        re = 1'b0;
        CSRop = `CSR_OP_NA;
      end
    endcase
  end

endmodule
//  imm[11:0] rs1 funct3 rd opcode analog to I-type
//  RV32/RV64 Zicsr Standard Extension
//  csr rs1 001 rd 1110011 CSRRW
//  csr rs1 010 rd 1110011 CSRRS
//  csr rs1 011 rd 1110011 CSRRC
//  csr uimm 101 rd 1110011 CSRRWI
//  csr uimm 110 rd 1110011 CSRRSI
//  csr uimm 111 rd 1110011 CSRRCI

//  31 20 19 15 14 12 11 7 6 0
//  csr rs1 funct3 rd opcode
//      12         5     3    5     7
//  source/dest source CSRRW dest SYSTEM
//  source/dest source CSRRS dest SYSTEM
//  source/dest source CSRRC dest SYSTEM
//  source/dest uimm[4:0] CSRRWI dest SYSTEM
//  source/dest uimm[4:0] CSRRSI dest SYSTEM
//  source/dest uimm[4:0] CSRRCI dest SYSTEM

//   Register operand
// Instruction rd rs1 read CSR? write CSR?
// CSRRW       x0  -       no      yes
// CSRRW      !x0  -       yes     yes
// CSRRS/C      -  x0      yes     no
// CSRRS/C      - !x0      yes     yes
// Immediate operand
// Instruction rd uimm read CSR? write CSR?
// CSRRWI      x0   -      no       yes
// CSRRWI     !x0   -      yes      yes
// CSRRS/CI     -   0      yes      no
// CSRRS/CI     -  !0      yes      yes


// --- csr_exception_handler.v ---
/*
 *  kianv harris multicycle RISC-V rv32ima
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none

/* verilator lint_off UNUSEDSIGNAL */
module csr_exception_handler #(
        parameter MTVEC_INIT = 32'h0000_0000
    ) (
        input  wire                      clk,
        input  wire                      resetn,
        input  wire                      incr_inst_retired,
        input  wire [              11:0] CSRAddr,
        input  wire [`CSR_OP_WIDTH -1:0] CSRop,
        input  wire                      we,
        input  wire                      re,
        input  wire [              31:0] Rd1,
        input  wire [               4:0] uimm,
        input  wire exception_event,
        input  wire mret,
        input  wire wfi_event,
        input wire [31:0] cause,
        input wire [31:0] pc,
        input wire [31:0] badaddr,
        output reg  [              31:0] rdata,
        output reg [31:0] exception_next_pc,
        output reg exception_select,
        output reg [1:0] privilege_mode,
        output wire csr_access_fault,
        output reg [31:0] mstatus,
        output reg [31:0] mie,
        output reg [31:0] mip,
        input wire IRQ3,
        input wire IRQ7
    );
    wire is_reg_operand;
    assign is_reg_operand = CSRop == `CSR_OP_CSRRW || CSRop == `CSR_OP_CSRRS || CSRop == `CSR_OP_CSRRC;

    // Extract privilege level from CSR address (bits [9:8])
    // Check if the CSR is read-only by examining bits [11:10] of CSR address
    wire [1:0] csr_privilege_level = CSRAddr[9:8];
    wire  csr_read_only = (CSRAddr[11:10] == 2'b11);
    assign csr_access_fault = (privilege_mode < csr_privilege_level) || (we & csr_read_only);

    wire [31:0] extended_uimm;
    assign extended_uimm = {{27{1'b0}}, uimm};
    wire [31:0] wdata;
    assign wdata = is_reg_operand ? Rd1 : extended_uimm;


    // CSR
    // csr rdcycle[H], rdtime[H], rdinstret[H]
    wire [63:0] cycle_counter;
    wire [63:0] instr_counter;

    wire increase_instruction = incr_inst_retired;
    counter #(64) instr_cnt_I (
                resetn,
                clk,
                incr_inst_retired,
                instr_counter
            );
    counter #(64) cycle_cnt_I (
                resetn,
                clk,
                1'b1,
                cycle_counter
            );

    reg [1:0] privilege_mode_nxt;

    reg [31:0] misa;
    reg [31:0] mscratch;
    reg [31:0] mtvec;
    reg [31:0] mepc;
    reg [31:0] mcause;
    reg [31:0] mtval;
    //    reg [31:0] mcounteren;

    reg [31:0] mstatus_nxt;
    reg [31:0] mscratch_nxt;
    reg [31:0] mie_nxt;
    reg [31:0] mtvec_nxt;
    reg [31:0] mepc_nxt;
    reg [31:0] mcause_nxt;
    reg [31:0] mtval_nxt;
    reg [31:0] mip_nxt;
    //    reg [31:0] mcounteren_nxt;

    reg [31:0] exception_next_pc_nxt;
    reg exception_select_nxt;


    wire is_csrrw = CSRop == `CSR_OP_CSRRW;
    wire is_csrrs = CSRop == `CSR_OP_CSRRS;
    wire is_csrrc = CSRop == `CSR_OP_CSRRC;

    wire is_csrrwi = CSRop == `CSR_OP_CSRRWI;
    wire is_csrrsi = CSRop == `CSR_OP_CSRRSI;
    wire is_csrrci = CSRop == `CSR_OP_CSRRCI;

    wire is_csr_set;
    assign is_csr_set = is_csrrs || is_csrrsi;

    wire is_csr_clear;
    assign is_csr_clear = is_csrrc || is_csrrci;

    always @(posedge clk) begin
        if (!resetn) begin
            privilege_mode <= `PRIVILEGE_MODE_MACHINE;
            /* verilator lint_off WIDTHEXPAND */
            mstatus <= `SET_MSTATUS_MPP(0, `PRIVILEGE_MODE_MACHINE);
            /* verilator lint_on WIDTHEXPAND */
            mscratch <= 0;
            mie <= 0;
            mtvec <= MTVEC_INIT;
            mepc <= 0;
            mcause <= 0;
            mtval <= 0;
            mip <= 0;
            //            mcounteren <= 0;
            /* verilator lint_off WIDTHEXPAND */
            misa <= `SET_MISA_VALUE(`MISA_MXL_RV32) |
                 `MISA_EXTENSION_BIT(`MISA_EXTENSION_A) |
                 `MISA_EXTENSION_BIT(`MISA_EXTENSION_I) |
                 `MISA_EXTENSION_BIT(`MISA_EXTENSION_M) |
                 /* `MISA_EXTENSION_BIT(`MISA_EXTENSION_S) | */
                 `MISA_EXTENSION_BIT(`MISA_EXTENSION_U);
            /* verilator lint_on WIDTHEXPAND */
            exception_next_pc <= 0;
            exception_select <= 0;
        end else begin
            privilege_mode <= privilege_mode_nxt;
            mscratch <= mscratch_nxt;
            mie <= mie_nxt;
            mip <= mip_nxt;
            mtvec <= mtvec_nxt;
            mepc <= mepc_nxt;
            mcause <= mcause_nxt;
            mtval <= mtval_nxt;
            //           mcounteren <= mcounteren_nxt;

            exception_next_pc <= exception_next_pc_nxt;
            exception_select <= exception_select_nxt;

            mstatus <= mstatus_nxt;// | ({31'b0, wfi_event} << 3);
        end
    end

    always @(*) begin
        if (re) begin
            case (CSRAddr)
                `CSR_REG_INSTRET:   rdata = instr_counter[31:0];
                `CSR_REG_INSTRETH:  rdata = instr_counter[63:32];
                `CSR_REG_CYCLE:     rdata = cycle_counter[31:0];
                `CSR_REG_CYCLEH:    rdata = cycle_counter[63:32];
                `CSR_REG_TIME:      rdata = cycle_counter[31:0];
                `CSR_REG_TIMEH:     rdata = cycle_counter[63:32];

                `CSR_REG_MSTATUS:   rdata = mstatus;
                `CSR_REG_MSCRATCH:  rdata = mscratch;
                `CSR_REG_MISA:      rdata = misa;
                `CSR_REG_MIE:       rdata = mie;
                `CSR_REG_MTVEC:     rdata = mtvec;
                `CSR_REG_MEPC:      rdata = mepc;
                `CSR_REG_MCAUSE:    rdata = mcause;
                `CSR_REG_MTVAL:     rdata = mtval;
                `CSR_REG_MIP:       rdata = mip;
                //              'CSR_REG_MCOUNTEREN: rdata = mcounteren;
                `CSR_REG_MHARTID:   rdata = 32'b0;
                `CSR_REG_MVENDORID: rdata = 32'h0;
                `CSR_REG_MARCHID:   rdata = 32'h2b;
                default:            rdata = 32'b0;
                // fixme exception
            endcase
        end else begin
            rdata = 32'b0;
        end
    end

    function [31:0] calculate_exception_pc;
        input [1:0] mode;
        input [31:0] base_addr;
        input [31:0] cause_;

        begin
            case (mode)
                2'b00: // Direct mode
                    calculate_exception_pc = base_addr;
                2'b01: // Reserved mode (treated as direct mode in this example)
                    calculate_exception_pc = base_addr;
                2'b10: // Vectored mode
                    calculate_exception_pc = base_addr + (cause_ << 2); // fixme alu
                default: // Invalid mode value, handle the exception
                    // exception_controller(MCAUSE_ILLEGAL_INSTRUCTION, PC, csr_stvec);
                    calculate_exception_pc = base_addr;
            endcase
        end

    endfunction


    reg [31:0] wdata_nxt;
    reg [31:0] temp_mstatus;
    reg [31:0] temp_mip;

    /* verilator lint_off WIDTHEXPAND */
    /* verilator lint_off WIDTHTRUNC */
    wire [`MSTATUS_MPP_WIDTH -1:0] y = `GET_MSTATUS_MPP(mstatus);
    always @(*) begin
        mstatus_nxt = mstatus;
        mscratch_nxt = mscratch;
        mie_nxt = mie;
        mtvec_nxt = mtvec;
        mepc_nxt = mepc;
        mcause_nxt = mcause;
        mtval_nxt = mtval;
        mip_nxt = mip;
        exception_next_pc_nxt = exception_next_pc;
        exception_select_nxt = 1'b0;
        privilege_mode_nxt = privilege_mode;
        temp_mstatus = 0;

        // fixme if (we & !rdonly)
        wdata_nxt = is_csr_clear ? rdata & ~wdata : is_csr_set ? rdata | wdata : wdata;

        if (we && !mret && !exception_event && !csr_access_fault ) begin
            case (CSRAddr)
                `CSR_REG_MSTATUS:  mstatus_nxt = wdata_nxt;
                `CSR_REG_MSCRATCH: mscratch_nxt = wdata_nxt;
                `CSR_REG_MIE:      mie_nxt = wdata_nxt;
                `CSR_REG_MTVEC:    mtvec_nxt = wdata_nxt;
                `CSR_REG_MEPC:     mepc_nxt = wdata_nxt;
                //`CSR_REG_MCOUNTEREN: mcounteren_nxt = wdata_nxt;
                `CSR_REG_MCAUSE:   mcause_nxt = wdata_nxt;
                `CSR_REG_MTVAL:    mtval_nxt = wdata_nxt;
                `CSR_REG_MIP:      mip_nxt = wdata_nxt;
                default:           ;
                // fixme exception
            endcase
        end

        if (exception_event) begin

            temp_mstatus = (mstatus & ~(`MSTATUS_MIE_MASK | `MSTATUS_MPIE_MASK | `MSTATUS_MPP_MASK));

            mstatus_nxt = (temp_mstatus
                           | `SET_MSTATUS_MPIE(temp_mstatus, `GET_MSTATUS_MIE(mstatus))
                           | `SET_MSTATUS_MIE(temp_mstatus, 1'b0)
                           | `SET_MSTATUS_MPP(temp_mstatus, privilege_mode));

            privilege_mode_nxt = `PRIVILEGE_MODE_MACHINE;
            mepc_nxt = pc;
            mcause_nxt = cause;// == `EXC_ECALL_FROM_UMODE ? {cause[31:2], privilege_mode} : cause;
            exception_next_pc_nxt = calculate_exception_pc(mtvec[1:0], {mtvec[31:2], 2'b0}, cause);
            mtval_nxt = &badaddr ? pc : badaddr; // if ~0 then pc
            exception_select_nxt = 1'b1;

        end

        if (mret) begin
            //         if (`IS_USER(privilege_mode)) begin
            // fixme exception
            //           $display("cpu_I.control_unit_I.main_fsm_I.state:%d", cpu_I.control_unit_I.main_fsm_I.state);
            //             $display("mret violation:%d", privilege_mode);
            //              $finish();
            //        end else begin


            temp_mstatus = (mstatus & ~(`MSTATUS_MIE_MASK | `MSTATUS_MPIE_MASK | `MSTATUS_MPP_MASK | (!`IS_MACHINE(y) << `MSTATUS_MPRV_BIT)));

            mstatus_nxt = (temp_mstatus
                           | `SET_MSTATUS_MIE(temp_mstatus, `GET_MSTATUS_MPIE(mstatus))
                           | `SET_MSTATUS_MPIE(temp_mstatus, 1'b1)
                           | `SET_MSTATUS_MPP(temp_mstatus, `PRIVILEGE_MODE_USER));
            //  | (!`IS_MACHINE(y) << `MSTATUS_MPRV_BIT));

            privilege_mode_nxt = y;

            exception_next_pc_nxt = mepc;
            exception_select_nxt = 1'b1;
        end

        temp_mip = mip & ~(`MIP_MSIP_MASK | `MIP_MTIP_MASK);
        mip_nxt = `SET_MIP_MSIP(temp_mip, IRQ3) | `SET_MIP_MTIP(temp_mip, IRQ7);

        /* verilator lint_on WIDTHEXPAND */
        /* verilator lint_on WIDTHTRUNC */

    end

endmodule
/* verilator lint_on UNUSEDSIGNAL */

// --- main_fsm.v ---
/*
 *  kianv harris multicycle RISC-V rv32ima
 *
 *  copyright (c) 2022/2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none

module main_fsm (
        input  wire                        clk,
        input  wire                        resetn,
        input  wire [                 6:0] op,
        input  wire [                 6:0] funct7,
        input  wire [                 2:0] funct3,
        input  wire [                 4:0] Rs1,
        input  wire [                 4:0] Rs2,
        input  wire [                 4:0] Rd,
        input  wire                        Zero,
        output reg                         AdrSrc,
        output reg                         fetched_instr,
        output reg                         incr_inst_retired,
        output reg  [`SRCA_WIDTH     -1:0] ALUSrcA,
        output reg  [`SRCB_WIDTH     -1:0] ALUSrcB,
        output reg  [`ALU_OP_WIDTH   -1:0] ALUOp,
        output reg  [`AMO_OP_WIDTH   -1:0] AMOop,
        output reg  [`RESULT_WIDTH   -1:0] ResultSrc,
        output reg  [                 2:0] ImmSrc,
        output reg                         CSRvalid,
        output reg                         PCUpdate,
        output reg                         Branch,
        output reg                         RegWrite,
        output reg                         MemWrite,
        input wire                         unaligned_access_load,
        input wire                         unaligned_access_store,
        input wire                         access_fault,
        output wire                        ALUOutWrite,
        output reg                         mem_valid,
        output reg                         amo_temp_write_operation,
        // AMO
        output reg                         amo_data_load,
        output reg                         amo_operation_store,
        output reg                         muxed_Aluout_or_amo_rd_wr,
        output reg                         amo_set_reserved_state_load,
        output reg                         amo_buffered_data,
        output reg                         amo_buffered_address,
        output reg                         select_ALUResult,
        output reg                         select_amo_temp,
        input  wire                        amo_reserved_state_load,

        // Exception Handler
        output reg exception_event,
        output reg [31:0] cause,
        output reg [31:0] badaddr,
        output reg mret,
        output reg wfi_event,
        input wire [1:0] privilege_mode,
        input wire csr_access_fault,
        input wire [31:0] mie,
        input wire [31:0] mip,
        input wire [31:0] mstatus,

        output reg  mul_ext_valid,
        input  wire mul_ext_ready,

        input wire mem_ready
    );
    // S0  --> Fetch
    // S1  --> Decode
    // S2  --> MemAddr
    // S3  --> MemRead
    // S4  --> MemWb
    // S5  --> MemWrite
    // S6  --> ExecuteR
    // S7  --> AluWB
    // S8  --> ExecuteI
    // S9  --> J-TYPE
    // S10 --> B-TYPE
    // S11 --> JALR
    // S12 --> LUI
    // S13 --> AUPIC
    // S14 --> ExecuteMul
    // S15 --> MulWB
    // S16 --> ExecuteSystem
    // S17 --> SystemWB
    //
    // amo stuff
    // amo memaddr
    // amoLoadLR
    // -> S18 (mem addr)
    // -> S19 (load)
    // -> S20 (LoadLR wb)
    // amoStoreSC
    // -> S18 (mem addr) if r; S21; e; S23
    // -> S21 (store) -> S22 -> S0
    // -> S23 -> S0 -> S0

    // amo op: S0 (is amo)
    // amo
    // tmp = mem[rs1d]
    // mem[rs1d] = tmp & rs2d;
    // rd = tmp
    // -> S18 (mem addr)
    // -> S24 (amo load)
    // -> S25 (wb)
    // -> S26 (alu exec amo)
    // -> S27 (mem addr)
    // -> S28 (mem write)
    // -> s29 -> s0
    wire funct7b0 = funct7[0];  // r-type
    wire [4:0] funct5 = funct7[6:2];

    localparam    S0 = 0, S1 = 1, S2 = 2, S3 = 3, S4 = 4, S5 = 5,
                  S6 = 6, S7 = 7, S8 = 8, S9 = 9, S10 = 10, S11 = 11,
                  S12 = 12, S13 = 13, S14 = 14, S15 = 15, S16 = 16, S17 = 17,
                  S18 = 18, S19 = 19, S20 = 20, S21 = 21, S22 = 22, S23 = 23,
                  S24 = 24, S25 = 25, S26 = 26, S27 = 27, S28 = 28, S29 = 29,
                  S30 = 30, S31 = 31, S32 = 32, S33 = 33, S34 = 34, S35 = 35, S36 = 36,
                  S37 = 37, S38 = 38, S39 = 39, S40 = 40, S41 = 41, S42 = 42, S43 = 43,
                  S44 = 44, S45 = 45, S46 = 46, S47 = 47, S48 = 48, S49 = 49, S_LAST = 50; // fixme

    reg [$clog2(S_LAST) -1:0] state, next_state;

    localparam      load    = 7'b 000_0011,
                    store   = 7'b 010_0011,
                    rtype   = 7'b 011_0011,
                    itype   = 7'b 001_0011,
                    jal     = 7'b 110_1111,  // j-type
                    jalr = 7'b110_0111,  // implicit i-type
                    branch = 7'b110_0011,
                    lui = 7'b011_0111,  // u-type
                    aupic = 7'b001_0111;  // u-type

    // Determine if the instruction is a CSR type using assign statement
    wire is_csr = (op == `CSR_OPCODE) && (funct3 == `CSR_FUNCT3_RW    ||
                                          funct3 == `CSR_FUNCT3_RS || funct3 == `CSR_FUNCT3_RC   ||
                                          funct3 == `CSR_FUNCT3_RWI || funct3 == `CSR_FUNCT3_RSI ||
                                          funct3 == `CSR_FUNCT3_RCI /* && funct7 == 0 */);

    wire is_load = op == load;
    wire is_store = op == store;
    wire is_rtype = op == rtype;
    wire is_itype = op == itype;
    wire is_jal = op == jal;
    wire is_jalr = op == jalr;
    wire is_branch = op == branch;
    wire is_lui = op == lui;
    wire is_aupic = op == aupic;
    wire is_amo = `RV32_IS_AMO_INSTRUCTION(op, funct3);
    wire is_amoadd_w = `RV32_IS_AMOADD_W(funct5);
    wire is_amoswap_w = `RV32_IS_AMOSWAP_W(funct5);
    wire is_amo_lr_w = `RV32_IS_LR_W(funct5);
    wire is_amo_sc_w = `RV32_IS_SC_W(funct5);
    wire is_amoxor_w = `RV32_IS_AMOXOR_W(funct5);
    wire is_amoand_w = `RV32_IS_AMOAND_W(funct5);
    wire is_amoor_w = `RV32_IS_AMOOR_W(funct5);
    wire is_amomin_w = `RV32_IS_AMOMIN_W(funct5);
    wire is_amomax_w = `RV32_IS_AMOMAX_W(funct5);
    wire is_amominu_w = `RV32_IS_AMOMINU_W(funct5);
    wire is_amomaxu_w = `RV32_IS_AMOMAXU_W(funct5);
    wire is_fence = `RV32_IS_FENCE(op);
    wire is_ebreak = `IS_EBREAK(op, funct3, funct7, Rs1, Rs2, Rd);
    wire is_ecall = `IS_ECALL(op, funct3, funct7, Rs1, Rs2, Rd);
    wire is_mret = `IS_MRET(op, funct3, funct7, Rs1, Rs2, Rd);
    wire is_wfi = `IS_WFI(op, funct3, funct7, Rs1, Rs2, Rd);

    // ===========================================================================

    // amo
    always @* begin
        amo_data_load = is_amo & is_amo_lr_w;
        amo_operation_store = is_amo & is_amo_sc_w;
    end

    always @* begin
        case (1'b1)
            is_amoadd_w  :AMOop = `AMO_OP_ADD_W;
            is_amoswap_w :AMOop = `AMO_OP_SWAP_W;
            is_amo_lr_w  :AMOop = `AMO_OP_LR_W;
            is_amo_sc_w  :AMOop = `AMO_OP_SC_W;
            is_amoxor_w  :AMOop = `AMO_OP_XOR_W;
            is_amoand_w  :AMOop = `AMO_OP_AND_W;
            is_amoor_w   :AMOop = `AMO_OP_OR_W;
            is_amomin_w  :AMOop = `AMO_OP_MIN_W;
            is_amomax_w  :AMOop = `AMO_OP_MAX_W;
            is_amominu_w :AMOop = `AMO_OP_MINU_W;
            is_amomaxu_w :AMOop = `AMO_OP_MAXU_W;
            default:
                /* verilator lint_off WIDTH */
                AMOop = 'hx;
            /* verilator lint_on WIDTH */
        endcase
    end


    assign ALUOutWrite             = !mem_valid;

    always @(*) begin
        case (1'b1)
            is_rtype:                              ImmSrc = `IMMSRC_RTYPE;
            is_itype | is_jalr | is_load | is_csr: ImmSrc = `IMMSRC_ITYPE;
            is_store:                              ImmSrc = `IMMSRC_STYPE;
            is_branch:                             ImmSrc = `IMMSRC_BTYPE;
            is_lui | is_aupic:                     ImmSrc = `IMMSRC_UTYPE;
            is_jal:                                ImmSrc = `IMMSRC_JTYPE;
            default:                               ImmSrc = 3'bxxx;
        endcase
    end

    always @(posedge clk) state <= !resetn ? S0 : next_state;

    /* verilator lint_off WIDTHEXPAND */
    /* verilator lint_off WIDTHTRUNC */
    wire mtip_raised = `GET_MSTATUS_MIE(mstatus) & `GET_MIP_MTIP(mip) & `GET_MIE_MTIP(mie);
    wire msip_raised = `GET_MSTATUS_MIE(mstatus) & `GET_MIP_MSIP(mip) & `GET_MIE_MSIP(mie);
    /* verilator lint_on WIDTHTRUNC */
    /* verilator lint_on WIDTHEXPAND */

    always @(*) begin
        next_state = S0;
        case (state)
            S0:  next_state = mem_ready ? S1 : S0;  // fetch
            S1:  // decode
            begin
                if (mtip_raised || msip_raised) next_state = S36; //interrupt
                else if (is_load || is_store) next_state = S2;
                else if (is_rtype && !funct7b0) next_state = S6;  // reg op reg in common alu
                else if (is_rtype && funct7b0) next_state = S14;  // reg op reg in mul/div
                else if (is_itype) next_state = S8;
                else if (is_jal) next_state = S9;
                else if (is_jalr) next_state = S11;
                else if (is_branch) next_state = S10;
                else if (is_lui) next_state = S12;
                else if (is_aupic) next_state = S13;
                else if (is_csr) next_state = S16;
                else if (is_amo) next_state = S18;
                else if (is_fence) next_state = S0;  // fixme
                else if (is_wfi) next_state = S0;//S38; // fixme
                else if (is_mret) next_state = S30; /* fixme exception != machine mode */
                else if (is_ecall) next_state = S34;
                else if (is_ebreak) next_state = S39; // fixme;
                else next_state = S40; // illegal;
            end
            S2:  // memaddr
            begin
                if (is_load) next_state  = access_fault ? S46 : (unaligned_access_load  ? S42 : S3);
                if (is_store) next_state = access_fault  ? S48 : (unaligned_access_store ? S44 : S5);
            end
            S3:  next_state = mem_ready ? S4 : S3;  // memread
            S4:  next_state = S0;  // mem wb
            S5:  next_state = mem_ready ? S0 : S5;  // mem write
            S6:  next_state = S7;  // exec rtype
            S7:  next_state = S0;  // alu wb
            S8:  next_state = S7;  // exec itype
            S9:  next_state = S7;  // jal
            S10: next_state = S0;  // branch
            S11: next_state = S9;  // jalr
            S12: next_state = S7;  // lui
            S13: next_state = S7;  // auipc
            S14: next_state = mul_ext_ready ? S15 : S14;  // exec multplier
            S15: next_state = S0;  // multiplier wb
            S16: next_state = csr_access_fault ? S32 : S17;  // exec system/itype
            S17: next_state = S0;  // system wb

            S18: begin
                if (is_amo_lr_w) begin
                    next_state = access_fault ? S46 : (unaligned_access_load ? S42 : S19);  // amoloadlr
                end
                if (is_amo_sc_w) begin
                    next_state = access_fault ? S48 : (unaligned_access_store ? S44 : (amo_reserved_state_load ? S21 : S23));
                end
                if (is_amoadd_w | is_amoswap_w | is_amoxor_w | is_amoand_w
                        | | is_amoor_w | is_amomin_w | is_amomax_w | is_amominu_w | is_amomaxu_w) begin
                    next_state = access_fault ? S46 : (unaligned_access_load ? S42 : S24);  // load memaddr
                end
            end

            S19:  // lr.w
                next_state = mem_ready ? S20 : S19;
            S20:  // lr.w wb
                next_state = S0;
            S21: next_state = mem_ready ? S22 : S21;  // sc.w mem wr
            S22:  // wb rdw = 1'b0
                next_state = S0;  // !res
            S23:  // wb rd = 1'b1
                next_state = S0;

            S24:  // amo load
                next_state = mem_ready ? S25 : S24;
            S25:  // alu wb
                next_state = S26;
            S26:  // alu amo exec
                next_state = S27;
            S27: next_state = unaligned_access_store ? S42 : S28;  // alu addr amo
            S28:  // mem write
                next_state = mem_ready ? S0 : S28;
            S29:  // wb
                next_state = S0;
            S30: // mret
                next_state = S31;
            S31: // mret
                next_state = S0;
            S32: // csr_access_fault
                next_state = S33;
            S33: // csr_access_fault
                next_state = S0;
            S34: // ecall0
                next_state = S35;
            S35: // ecall1
                next_state = S0;
            S36: // irq_0
                next_state = S37;
            S37: // irq_1
                next_state = S0;
            S38: // wfi
                next_state = S0;
            S39: // ebreak
                next_state = S39;
            S40: // illegal0
                next_state = S41;
            S41: // illegal1
                next_state = S0;
            S42: // unaligned_access_load0
                next_state = S43;
            S43: // unaligned_access_load1
                next_state = S0;
            S44: // unaligned_access_store0
                next_state = S45;
            S45: // unaligned_access_store1
                next_state = S0;
            S46: // load acces fault0
                next_state = S47;
            S47: // load acces fault1
                next_state = S0;
            S48: // store acces fault0
                next_state = S49;
            S49: // store acces fault1
                next_state = S0;

            default: next_state = S0;
        endcase
    end

    always @(*) begin
        incr_inst_retired          = 1'b0;
        AdrSrc                      = `ADDR_PC;
        fetched_instr               =  1'b0;
        ALUSrcA                     = `SRCA_PC;
        ALUSrcB                     = `SRCB_RD2_BUF;
        ALUOp                       = `ALU_OP_ADD;
        ResultSrc                   = `RESULT_ALUOUT;
        PCUpdate                    = 1'b0;
        Branch                      = 1'b0;
        RegWrite                    = 1'b0;
        MemWrite                    = 1'b0;
        CSRvalid                    = 1'b0;
        select_ALUResult                    = 1'b0;

        amo_temp_write_operation               = 1'b0;
        amo_set_reserved_state_load = 1'b0;
        amo_buffered_data       = 1'b0;
        amo_buffered_address       = 1'b0;
        select_amo_temp                  = 1'b0;
        muxed_Aluout_or_amo_rd_wr     = 1'b0;

        mem_valid                   = 1'b0;
        mul_ext_valid               = 1'b0;

        exception_event = 1'b0;
        cause = 32'b0;
        badaddr = 32'b0;
        mret = 1'b0;

        wfi_event = 1'b0;

        case (state)
            S0: begin
                // fetch
                // Instr <- MEM[PC], PC <- PC + 4, OldPC <- PC
                mem_valid  = 1'b1;

                AdrSrc     = `ADDR_PC;
                fetched_instr  = mem_ready; // fixme for interrupt we haven't to count
                ALUSrcA    = `SRCA_PC;
                ALUSrcB    = `SRCB_CONST_4;
                ALUOp      = `ALU_OP_ADD;
                ResultSrc  = `RESULT_ALURESULT;
                PCUpdate   = mem_ready;
            end
            S1: begin
                // decode
                // ALUOut <- PCTarget (oldPC + imm)
                ALUSrcA = `SRCA_OLD_PC;
                ALUSrcB = `SRCB_IMM_EXT;
                ALUOp   = `ALU_OP_ADD;
            end
            S2: begin
                // mem addr
                // ALUOut <- rs1 + imm
                ALUSrcA = `SRCA_RD1_BUF;
                ALUSrcB = `SRCB_IMM_EXT;
                ALUOp   = `ALU_OP_ADD;
            end
            S3: begin
                // mem read
                // Data <- Mem[ALUOUt]
                mem_valid = 1'b 1;
                ResultSrc = `RESULT_ALUOUT;
                AdrSrc    = `ADDR_RESULT;
            end
            S4: begin
                // mem wb
                // rd <- Data
                mem_valid = 1'b1;
                ResultSrc = `RESULT_DATA;
                RegWrite  = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S5: begin
                // mem write
                // Mem[ALUOUt] <- rd
                mem_valid = 1'b 1;
                ResultSrc = `RESULT_ALUOUT;
                AdrSrc    = `ADDR_RESULT;
                MemWrite  = 1'b1;
                incr_inst_retired = mem_ready;
            end
            S6: begin
                // execute rtype
                // ALUOut <- rs1 op rs2
                ALUSrcA = `SRCA_RD1_BUF;
                ALUSrcB = `SRCB_RD2_BUF;
                ALUOp   = `ALU_OP_ARITH_LOGIC;
            end
            S7: begin
                // alu wb
                // rd <- ALUOut
                mem_valid = 1'b1;
                ResultSrc = `RESULT_ALUOUT;
                RegWrite  = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S8: begin
                // execute itype
                // ALUOut <- rs1 op imm
                ALUSrcA = `SRCA_RD1_BUF;
                ALUSrcB = `SRCB_IMM_EXT;
                ALUOp   = `ALU_OP_ARITH_LOGIC;
            end
            S9: begin
                // jal
                // PC <- ALUOut , rd<- OldPC + 4;
                ALUSrcA   = `SRCA_OLD_PC;
                ALUSrcB   = `SRCB_CONST_4;
                ALUOp     = `ALU_OP_ADD;
                ResultSrc = `RESULT_ALUOUT;
                PCUpdate  = 1'b1;
            end
            S10: begin
                // branch
                // rd <- rs1 - rs2,
                // if zero, PC <- ALUOut, else PC <- PC
                ALUSrcA   = `SRCA_RD1_BUF;
                ALUSrcB   = `SRCB_RD2_BUF;
                ALUOp     = `ALU_OP_BRANCH;
                ResultSrc = `RESULT_ALUOUT;
                Branch    = 1'b1;
                mem_valid = Zero;
                incr_inst_retired = 1'b1;
            end
            S11: begin
                // jalr itype
                // ALUOut <- rs1 + imm
                ALUSrcA = `SRCA_RD1_BUF;
                ALUSrcB = `SRCB_IMM_EXT;
                ALUOp   = `ALU_OP_ADD;
            end
            S12: begin
                // lui utype
                // ALUOut <- 0 + imm<<12
                // ignore PC in ALU
                // not used: ALUSrcA   =
                ALUSrcB = `SRCB_IMM_EXT;
                ALUOp   = `ALU_OP_LUI;  // 0 + imm<<12
            end
            S13: begin
                // aupic utype
                // ALUOut <- PC + imm<<12
                ALUSrcA = `SRCA_OLD_PC;
                ALUSrcB = `SRCB_IMM_EXT;
                ALUOp   = `ALU_OP_AUIPC;  // pc + imm<<12
            end
            S14: begin
                // execute rtype
                // MULOut <- rs1 op rs2
                ALUSrcA       = `SRCA_RD1_BUF;
                ALUSrcB       = `SRCB_RD2_BUF;
                mul_ext_valid = 1'b1;  // todo ALU_OP
            end
            S15: begin
                // multiplier wb
                // rd <- MULOut
                mem_valid = 1'b1;
                ResultSrc = `RESULT_MULOUT;
                RegWrite  = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S16: begin
                // execute itype
                // CSRData
                ALUSrcA  = `SRCA_RD1_BUF;
                ALUSrcB  = `SRCB_IMM_EXT;
                CSRvalid = 1'b1;
            end
            S17: begin
                // system wb
                // rd <- RESULT_CSR
                mem_valid = 1'b1;
                ResultSrc = `RESULT_CSROUT;
                RegWrite  = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S18: begin
                // -> S18 (mem addr)
                // ALUOut <- rs1d + 0
                // fixme: alu reserved
                ALUSrcA = `SRCA_RD1_BUF;
                ALUSrcB = `SRCB_CONST_0;
                ALUOp   = `ALU_OP_ADD;
                amo_buffered_address = 1'b1;
            end
            S19: begin
                // -> S19 (load)
                // amo mem read LR.w
                // Data <= Mem[ALUOUt]
                amo_set_reserved_state_load = 1'b1;  // fixme mem exception revert
                amo_buffered_data = 1'b1;  // set amo_reserved
                mem_valid = 1'b1;
                ResultSrc = `RESULT_ALUOUT;
                AdrSrc = `ADDR_RESULT;
            end
            S20: begin
                // alu wb
                // rd <- ALUOut
                mem_valid = 1'b1;
                ResultSrc = `RESULT_DATA;
                RegWrite  = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S21: begin
                // sc.w amo store sucesseded0
                // mem write
                // Mem[ALUOUt] <- rd2->A2
                amo_set_reserved_state_load = 1'b1; // fixme mem exception revert
                amo_buffered_data = 1'b0; // clr amo_reserved

                mem_valid = 1'b1;
                ResultSrc = `RESULT_AMO_TEMP_ADDR;
                AdrSrc    = `ADDR_RESULT;
                MemWrite  = 1'b1;
            end
            S22: begin
                // sc.w rdw = 1'b0 sucesseded1
                amo_buffered_data = 1'b0;  // clr amo_reserved
                muxed_Aluout_or_amo_rd_wr = 1'b1;
                ResultSrc = `RESULT_ALUOUT;
                RegWrite = 1'b1;
                mem_valid = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S23: begin
                // sc.w rdw = 1'b1 failed
                amo_buffered_data = 1'b1;  // clr amo_reserved
                muxed_Aluout_or_amo_rd_wr = 1'b1;
                ResultSrc = `RESULT_ALUOUT;
                RegWrite = 1'b1;
                mem_valid = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S24: begin
                // (amo load)
                mem_valid = 1'b1;
                AdrSrc = `ADDR_RESULT;
                ResultSrc = `RESULT_ALUOUT;
                amo_temp_write_operation = 1'b1;
            end
            S25: begin
                // amo wb
                ALUOp = `ALU_OP_ADD;
                ALUSrcA = `SRCA_AMO_TEMP_DATA;
                ALUSrcB = `SRCB_CONST_0;
                ResultSrc = `RESULT_DATA;
                RegWrite = 1'b1;
            end
            S26: begin
                // alu exec amo
                ALUOp = `ALU_OP_AMO;
                ALUSrcA = is_amoswap_w ? `SRCA_CONST_0 : `SRCA_AMO_TEMP_DATA;
                ALUSrcB = `SRCB_RD2_BUF;
                ResultSrc = `RESULT_ALURESULT;
                select_ALUResult = 1'b1;
                amo_temp_write_operation = 1'b1;
            end
            S27: begin
                // mem addr
                ALUSrcA = `SRCA_RD1_BUF;
                ALUSrcB = `SRCB_CONST_0;
                ALUOp   = `ALU_OP_ADD;
            end
            S28: begin
                // mem write
                MemWrite = 1'b1;
                select_amo_temp = 1'b1;
                ResultSrc = `RESULT_AMO_TEMP_ADDR;
                AdrSrc    = `ADDR_RESULT;
                mem_valid = 1'b1;
                incr_inst_retired = mem_ready;
            end
            S29: begin
                mem_valid = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S30: begin // mret0
                mret = 1'b1;
            end
            S31: begin // mret1
                PCUpdate = 1'b1;
                // mret = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S32: begin // csr_access_fault0
                cause = `EXC_ILLEGAL_INSTRUCTION; // fixme: newer csr.S needs EXC_ECALL_FROM_UMODE
                badaddr = {25'b0, op};
                exception_event = 1'b1;
            end
            S33: begin // csr_access_fault1
                PCUpdate = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S34: begin // ecall0
                cause = `EXC_ECALL_FROM_UMODE; // + priv in handler
                cause = {cause[31:2], privilege_mode};
                badaddr = 0;
                exception_event = 1'b1;
            end
            S35: begin // ecall1
                PCUpdate = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S36: begin // irq_0
                cause = mtip_raised ? `INTERRUPT_MACHINE_TIMER : `INTERRUPT_MACHINE_SOFTWARE; // + priv in handler
                badaddr = 0;
                exception_event = 1'b1;
                //      PCUpdate = 1'b1;
            end
            S37: begin // irq_1
                PCUpdate = 1'b1;
            end
            S38: begin // irq_1
                wfi_event = 1'b1;
                incr_inst_retired = 1'b1;
            end
            S39: begin // ebreak
            end
            S40: begin // illegal
                cause = `EXC_ILLEGAL_INSTRUCTION; // + priv in handler
                badaddr = ~0; // pc
                exception_event = 1'b1;
            end
            S41: begin // illegal
                PCUpdate = 1'b1;
                incr_inst_retired = 1'b1;
            end

            S42: begin // unaligned_access_load0
                cause = `EXC_LOAD_AMO_ADDR_MISALIGNED;
                badaddr = ~0; // pc
                exception_event = 1'b1;
            end
            S43: begin // unaligned_access_load1
                PCUpdate = 1'b1;
                incr_inst_retired = 1'b1;
            end

            S44: begin // unaligned_access_store0
                cause = `EXC_STORE_AMO_ADDR_MISALIGNED;
                badaddr = ~0; // pc
                exception_event = 1'b1;
            end
            S45: begin // unaligned_access_store1
                PCUpdate = 1'b1;
                incr_inst_retired = 1'b1;
            end

            S46: begin // load access_fault0
                cause = `EXC_LOAD_AMO_ACCESS_FAULT;
                badaddr = ~0; // pc
                exception_event = 1'b1;
            end
            S47: begin // load access_fault1
                PCUpdate = 1'b1;
                incr_inst_retired = 1'b1;
            end

            S48: begin // store access_fault0
                cause = `EXC_STORE_AMO_ACCESS_FAULT;
                badaddr = ~0; // pc
                exception_event = 1'b1;
            end
            S49: begin // store access_fault1
                PCUpdate = 1'b1;
                incr_inst_retired = 1'b1;
            end

            default: begin
                /* verilator lint_off WIDTH */
                AdrSrc     = 'b0;
                ALUSrcA    = 'b0;
                ALUSrcB    = 'b0;
                ALUOp      = 'b0;
                PCUpdate   = 'b0;
                Branch     = 'b0;
                ResultSrc  = `RESULT_ALUOUT;
                RegWrite   = 'b0;
                MemWrite   = 'b0;
                /* verilator lint_on WIDTH */
            end
        endcase
    end
endmodule

// --- control_unit.v ---
/*
 *  kianv harris multicycle RISC-V rv32ima
 *
 *  copyright (c) 2022/23 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none

module control_unit (
    input  wire                        clk,
    input  wire                        resetn,
    input  wire [                 6:0] op,
    input  wire [                 2:0] funct3,
    input  wire [                 6:0] funct7,
    input  wire [                 0:0] immb10,
    input  wire                        Zero,
    input  wire [                 4:0] Rs1,
    input  wire [                 4:0] Rs2,
    input  wire [                 4:0] Rd,
    output wire [`RESULT_WIDTH   -1:0] ResultSrc,
    output wire [`ALU_CTRL_WIDTH -1:0] ALUControl,
    output wire [`SRCA_WIDTH     -1:0] ALUSrcA,
    output wire [`SRCB_WIDTH     -1:0] ALUSrcB,
    output wire [                 2:0] ImmSrc,
    output wire [`STORE_OP_WIDTH -1:0] STOREop,
    output wire [`LOAD_OP_WIDTH  -1:0] LOADop,
    output wire [`MUL_OP_WIDTH   -1:0] MULop,
    output wire [`DIV_OP_WIDTH   -1:0] DIVop,
    output wire [`CSR_OP_WIDTH   -1:0] CSRop,
    output wire                        CSRwe,
    output wire                        CSRre,
    output wire                        RegWrite,
    output wire                        PCWrite,
    output wire                        AdrSrc,
    output wire                        MemWrite,
    input  wire                        unaligned_access_load,
    input  wire                        unaligned_access_store,
    input  wire                        access_fault,
    output wire                        fetched_instr,
    output wire                        incr_inst_retired,
    output wire                        ALUOutWrite,
    output wire                        amo_temp_write_operation,
    output wire                        muxed_Aluout_or_amo_rd_wr,
    output wire                        amo_set_reserved_state_load,
    output wire                        amo_buffered_data,
    output wire                        amo_buffered_address,
    input  wire                        amo_reserved_state_load,
    output wire                        select_ALUResult,
    output wire                        select_amo_temp,

    // Exception Handler
    output wire exception_event,
    output wire [31:0] cause,
    output wire [31:0] badaddr,
    output wire mret,
    output wire wfi_event,
    input wire [1:0] privilege_mode,
    input wire csr_access_fault,
    input wire [31:0] mie,
    input wire [31:0] mip,
    input wire [31:0] mstatus,

    output wire mem_valid,
    input  wire mem_ready,

    output wire mul_valid,
    input  wire mul_ready,

    output wire div_valid,
    input  wire div_ready
);

  wire [`ALU_OP_WIDTH   -1:0] ALUOp;
  wire [`AMO_OP_WIDTH   -1:0] AMOop;
  wire PCUpdate;
  wire Branch;
  wire mul_ext_ready;
  wire mul_ext_valid;

  wire taken_branch = !Zero;
  assign PCWrite = Branch & taken_branch | PCUpdate;

  assign mul_ext_ready = mul_ready | div_ready;

  wire amo_data_load;
  wire amo_operation_store;

  wire CSRvalid;
  main_fsm main_fsm_I (
      .clk              (clk),
      .resetn           (resetn),
      .op               (op),
      .funct7           (funct7),
      .funct3           (funct3),
      .Rs1              (Rs1),
      .Rs2              (Rs2),
      .Rd               (Rd),
      .Zero             (Zero),
      .AdrSrc           (AdrSrc),
      .fetched_instr    (fetched_instr),
      .incr_inst_retired(incr_inst_retired),
      .ALUSrcA          (ALUSrcA),
      .ALUSrcB          (ALUSrcB),
      .ALUOp            (ALUOp),
      .AMOop            (AMOop),
      .ResultSrc        (ResultSrc),
      .ImmSrc           (ImmSrc),
      .CSRvalid         (CSRvalid),
      .PCUpdate         (PCUpdate),
      .Branch           (Branch),
      .RegWrite         (RegWrite),
      .ALUOutWrite      (ALUOutWrite),

      .amo_temp_write_operation   (amo_temp_write_operation),
      .amo_data_load              (amo_data_load),
      .amo_operation_store        (amo_operation_store),
      .muxed_Aluout_or_amo_rd_wr  (muxed_Aluout_or_amo_rd_wr),
      .amo_set_reserved_state_load(amo_set_reserved_state_load),
      .amo_buffered_data          (amo_buffered_data),
      .amo_buffered_address       (amo_buffered_address),
      .amo_reserved_state_load    (amo_reserved_state_load),
      .select_ALUResult           (select_ALUResult),
      .select_amo_temp            (select_amo_temp),
      .MemWrite                   (MemWrite),
      .unaligned_access_load      (unaligned_access_load),
      .unaligned_access_store     (unaligned_access_store),
      .access_fault               (access_fault),

      .exception_event (exception_event),
      .cause           (cause),
      .badaddr         (badaddr),
      .mret            (mret),
      .wfi_event       (wfi_event),
      .privilege_mode  (privilege_mode),
      .csr_access_fault(csr_access_fault),
      .mstatus         (mstatus),
      .mie             (mie),
      .mip             (mip),

      .mem_valid(mem_valid),
      .mem_ready(mem_ready),

      .mul_ext_valid(mul_ext_valid),
      .mul_ext_ready(mul_ext_ready)
  );

  load_decoder load_decoder_I (
      funct3,
      amo_data_load,
      LOADop
  );
  store_decoder store_decoder_I (
      funct3,
      amo_operation_store,
      STOREop
  );

  csr_decoder csr_decoder_I (
      .funct3(funct3),
      .Rs1Uimm(Rs1),
      .Rd(Rd),
      .valid(CSRvalid),
      .CSRwe(CSRwe),
      .CSRre(CSRre),
      .CSRop(CSRop)
  );

  alu_decoder alu_decoder_I (
      .imm_bit10 (immb10),
      .op_bit5   (op[5]),
      .funct3    (funct3),
      .funct7b5  (funct7[5]),
      .ALUOp     (ALUOp),
      .AMOop     (AMOop),
      .ALUControl(ALUControl)
  );

  multiplier_extension_decoder mul_ext_de_I (
      funct3,
      MULop,
      DIVop,
      mul_ext_valid,
      mul_valid,
      div_valid
  );

endmodule

// --- datapath_unit.v ---
/*
 *  kianv harris multicycle RISC-V rv32imo
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none

module datapath_unit #(
    parameter RV32E             = 0,
    parameter RESET_ADDR        = 0,
    parameter STACKADDR         = 32'hffff_ffff
) (
    input wire clk,
    input wire resetn,

    input  wire [`RESULT_WIDTH   -1:0] ResultSrc,
    input  wire [`ALU_CTRL_WIDTH -1:0] ALUControl,
    input  wire [`SRCA_WIDTH     -1:0] ALUSrcA,
    input  wire [`SRCB_WIDTH     -1:0] ALUSrcB,
    input  wire [                 2:0] ImmSrc,
    input  wire [`STORE_OP_WIDTH -1:0] STOREop,
    input  wire [`LOAD_OP_WIDTH  -1:0] LOADop,
    input  wire [`MUL_OP_WIDTH   -1:0] MULop,
    input  wire [`DIV_OP_WIDTH   -1:0] DIVop,
    input  wire [`CSR_OP_WIDTH   -1:0] CSRop,
    input  wire                        CSRwe,
    input  wire                        CSRre,
    output wire                        Zero,
    output wire                        immb10,

    input wire RegWrite,
    input wire PCWrite,
    input wire AdrSrc,
    input wire MemWrite,
    input wire incr_inst_retired,
    input wire fetched_instr,
    input wire ALUOutWrite,

    // AMO
    input  wire amo_temp_write_operation,
    input  wire amo_set_reserved_state_load,
    input  wire amo_buffered_data,
    input  wire amo_buffered_address,
    output wire amo_reserved_state_load,
    input  wire muxed_Aluout_or_amo_rd_wr,
    input  wire select_ALUResult,
    input  wire select_amo_temp,


    // 32-bit instruction input
    output wire [31:0] Instr,

    output wire [ 3:0] mem_wstrb,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,
    input  wire        mul_valid,
    output wire        mul_ready,
    input  wire        div_valid,
    output wire        div_ready,
    output wire [31:0] ProgCounter,
    output wire        unaligned_access_load,
    output wire        unaligned_access_store,

    // Exception Handler
    input wire exception_event,
    input wire [31:0] cause,
    input wire [31:0] badaddr,
    input wire mret,
    input wire wfi_event,
    output wire csr_access_fault,
    output wire [1:0] privilege_mode,
    output wire [31:0] mie,
    output wire [31:0] mip,
    output wire [31:0] mstatus,
    input wire IRQ3,
    input wire IRQ7
);


  wire [31:0] Rd1;
  wire [31:0] Rd2;

  wire [4:0] Rs1 = Instr[19:15];
  wire [4:0] Rs2 = Instr[24:20];
  wire [4:0] Rd = Instr[11:7];

  wire [31:0] WD3;

  register_file #(
      .REGISTER_DEPTH(RV32E ? 16 : 32)
  ) register_file_I (
      .clk(clk),
      .we (RegWrite),
      .A1 (Rs1),
      .A2 (Rs2),
      .A3 (Rd),
      .rd1(Rd1),
      .rd2(Rd2),
      .wd (WD3)
  );

  wire [31:0] ImmExt;
  wire [31:0] PC, OldPC;
  wire [31:0] PCNext;
  wire [31:0] A1, A2;
  wire [31:0] SrcA, SrcB;
  wire [31:0] ALUResult;
  wire [31:0] MULResult;
  wire [31:0] DIVResult;
  wire [31:0] MULExtResult;
  wire [31:0] MULExtResultOut;
  wire [31:0] ALUOut;
  wire [31:0] Result;
  wire [ 3:0] wmask;
  wire [31:0] Data;
  wire [31:0] DataLatched;
  wire [31:0] CSRData;
  wire [ 1:0] mem_addr_align_latch;
  wire [31:0] CSRDataOut;
/* verilator lint_off UNUSEDSIGNAL */
  wire        div_by_zero_err;
/* verilator lint_on UNUSEDSIGNAL */

  assign immb10      = ImmExt[10];
  assign ProgCounter = PC;
  assign mem_wstrb   = wmask & {4{MemWrite}};

  assign WD3         = Result;
  assign PCNext      = Result;

  // AMO
  wire [31:0] amo_temporary_data;
  wire [31:0] alu_out_or_amo_scw;
  wire [31:0] DataLatched_or_AMOtempData;
  wire [31:0] muxed_A2_data;
  wire [31:0] muxed_Data_ALUResult;

  // CSR exception handler
  wire [11:0] CSRAddr;
  assign CSRAddr = ImmExt[11:0];

  wire [31:0] exception_next_pc;


  mux2 #(32) Addr_I (
      PC,
      Result,
      AdrSrc,
      mem_addr
  );

  mux2 #(32) DataLatched_or_AMOtempData_i (
      DataLatched,
      amo_temporary_data,
      select_amo_temp,
      DataLatched_or_AMOtempData
  );

  wire [31:0] amo_buffer_addr_value;
  mux6 #(32) Result_I (
      alu_out_or_amo_scw,
      DataLatched_or_AMOtempData,
      ALUResult,
      MULExtResultOut,
      CSRDataOut,
      amo_buffer_addr_value,
      ResultSrc,
      Result
  );

  wire [31:0] pc_or_exception_next;
  wire exception_select;
  mux2 #(32) pc_next_or_exception_mux_I (
      PCNext,
      exception_next_pc,
      exception_select,
      pc_or_exception_next
  );

  dff #(32, RESET_ADDR) PC_I (
      resetn,
      clk,
      PCWrite,
      pc_or_exception_next,
      PC
  );

  dff #(32, `NOP_INSTR) Instr_I (
      resetn,
      clk,
      fetched_instr,
      mem_rdata,
      Instr
  );

  dff #(32) amo_buffered_addr_I (
      .resetn(resetn),
      .clk(clk),
      .d(ALUResult),
      .en(amo_buffered_address),
      .q(amo_buffer_addr_value)
  );

  dff #(1) amo_reserved_state_load_I (
      .resetn(resetn),
      .clk(clk),
      .d(amo_buffered_data),
      .en(amo_set_reserved_state_load),
      .q(amo_reserved_state_load)
  );

  dff #(32, RESET_ADDR) OldPC_I (
      resetn,
      clk,
      fetched_instr,
      PC,
      OldPC
  );

  dff #(32) ALUOut_I (
      resetn,
      clk,
      ALUOutWrite,
      ALUResult,
      ALUOut
  );

  mux2 #(32) Aluout_or_atomic_scw_I (
      ALUOut,
      {{31{1'b0}}, amo_buffered_data},
      muxed_Aluout_or_amo_rd_wr,
      alu_out_or_amo_scw
  );

  dlatch #(2) ADDR_I (
      clk,
      mem_addr[1:0],
      mem_addr_align_latch
  );

  dlatch #(32) A1_I (
      clk,
      Rd1,
      A1
  );

  dlatch #(32) A2_I (
      clk,
      Rd2,
      A2
  );

  // todo: data, csrdata, mulex could be stored in one dlatch
  dlatch #(32) Data_I (
      clk,
      Data,
      DataLatched
  );

  dlatch #(32) CSROut_I (
      clk,
      CSRData,
      CSRDataOut
  );

  dlatch #(32) MULExtResultOut_I (
      clk,
      MULExtResult,
      MULExtResultOut
  );

  extend extend_I (
      Instr[31:7],
      ImmSrc,
      ImmExt
  );

  mux2 #(32) muxed_A2_data_I (
      A2,
      amo_temporary_data,
      select_amo_temp,
      muxed_A2_data
  );

  store_alignment store_alignment_I (
      mem_addr[1:0],
      STOREop,
      muxed_A2_data,
      mem_wdata,
      wmask,
      unaligned_access_store
  );

  load_alignment load_alignment_I (
      mem_addr_align_latch,
      LOADop,
      mem_rdata,
      Data,
      unaligned_access_load
  );

  mux2 #(32) muxed_Data_ALUResult_I (
      Data,
      ALUResult,
      select_ALUResult,
      muxed_Data_ALUResult
  );

  dff #(32) AMOTmpData_I (
      resetn,
      clk,
      amo_temp_write_operation,
      muxed_Data_ALUResult,
      amo_temporary_data
  );

  mux5 #(32) SrcA_I (
      PC,
      OldPC,
      A1  /* Rd1 */,
      amo_temporary_data,
      32'd0,
      ALUSrcA,
      SrcA
  );

  mux4 #(32) SrcB_I (
      A2  /* Rd2 */,
      ImmExt,
      32'd4,
      32'd0,
      ALUSrcB,
      SrcB
  );

  alu alu_I (
      SrcA,
      SrcB,
      ALUControl,
      ALUResult,
      Zero
  );

  mux2 #(32) mul_ext_I (
      MULResult,
      DIVResult,
      !mul_valid,
      MULExtResult
  );

  multiplier mul_I (
      clk,
      resetn,
      SrcA,
      SrcB,
      MULop,
      MULResult,
      mul_valid,
      mul_ready
  );

  divider div_I (
      clk,
      resetn,
      SrcA,
      SrcB,
      DIVop,
      DIVResult,
      div_valid,
      div_ready,
      div_by_zero_err  /* todo: */
  );

  csr_exception_handler csr_exception_handler_I (
      .clk              (clk),
      .resetn           (resetn),
      .incr_inst_retired(incr_inst_retired),
      .CSRAddr          (CSRAddr),
      .CSRop            (CSRop),
      .Rd1              (SrcA),
      .uimm             (Rs1),
      .we               (CSRwe),
      .re               (CSRre),
      .exception_event  (exception_event),
      .mret             (mret),
      .wfi_event        (wfi_event),
      .cause            (cause),
      .pc               (OldPC),
      .badaddr          (badaddr),

      .privilege_mode   (privilege_mode),
      .rdata            (CSRData),
      .exception_next_pc(exception_next_pc),
      .exception_select (exception_select),
      .csr_access_fault (csr_access_fault),
      .mie              (mie),
      .mip              (mip),
      .mstatus          (mstatus),
      .IRQ3             (IRQ3),
      .IRQ7             (IRQ7)
  );

endmodule

// --- kianv_harris_mc_edition.v ---
/*
 *  kianv harris multicycle RISC-V rv32ima
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none

module kianv_harris_mc_edition #(
    parameter RESET_ADDR = 0,
    parameter STACKADDR  = 0,
    parameter RV32E      = 0
) (
    input  wire        clk,
    input  wire        resetn,
    output wire        mem_valid,
    input  wire        mem_ready,
    output wire [ 3:0] mem_wstrb,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,
    output wire [31:0] PC,
    input  wire        access_fault,
    input  wire        IRQ3,
    input  wire        IRQ7
);

  wire [                 31:0] Instr;
  wire [                  6:0] op;
  wire [                  2:0] funct3;
  wire [                  6:0] funct7;
  wire [                  0:0] immb10;

  wire                         Zero;

  wire [`RESULT_WIDTH    -1:0] ResultSrc;
  wire [`ALU_CTRL_WIDTH  -1:0] ALUControl;
  wire [`SRCA_WIDTH      -1:0] ALUSrcA;
  wire [`SRCB_WIDTH      -1:0] ALUSrcB;
  wire [                  2:0] ImmSrc;
  wire [`STORE_OP_WIDTH  -1:0] STOREop;
  wire [`LOAD_OP_WIDTH   -1:0] LOADop;
  wire [`MUL_OP_WIDTH    -1:0] MULop;
  wire [`DIV_OP_WIDTH    -1:0] DIVop;
  wire [`CSR_OP_WIDTH    -1:0] CSRop;
  wire                         CSRwe;
  wire                         CSRre;
  wire [                  4:0] Rs1;
  wire [                  4:0] Rs2;
  wire [                  4:0] Rd;

  wire                         RegWrite;
  wire                         PCWrite;
  wire                         AdrSrc;
  wire                         MemWrite;
  wire                         unaligned_access_load;
  wire                         unaligned_access_store;
  wire                         fetched_instr;
  wire                         incr_inst_retired;
  wire                         ALUOutWrite;

  wire                         mul_valid;
  wire                         mul_ready;
  wire                         div_valid;
  wire                         div_ready;

  assign op     = Instr[6:0];
  assign funct3 = Instr[14:12];
  assign funct7 = Instr[31:25];
  assign Rs1    = Instr[19:15];
  assign Rs2    = Instr[24:20];
  assign Rd     = Instr[11:7];

  wire amo_temp_write_operation;
  wire amo_set_reserved_state_load;
  wire amo_buffered_data;
  wire amo_buffered_address;
  wire amo_reserved_state_load;
  wire muxed_Aluout_or_amo_rd_wr;
  wire select_ALUResult;
  wire select_amo_temp;

  // Exception Handler
  wire exception_event;
  wire [31:0] cause;
  wire [31:0] badaddr;
  wire mret;
  wire wfi_event;
  wire [1:0] privilege_mode;
  wire csr_access_fault;
  wire [31:0] mstatus;
  wire [31:0] mie;
  wire [31:0] mip;

  control_unit control_unit_I (
      .clk                   (clk),
      .resetn                (resetn),
      .op                    (op),
      .funct3                (funct3),
      .funct7                (funct7),
      .immb10                (immb10),
      .Zero                  (Zero),
      .Rs1                   (Rs1),
      .Rs2                   (Rs2),
      .Rd                    (Rd),
      .ResultSrc             (ResultSrc),
      .ALUControl            (ALUControl),
      .ALUSrcA               (ALUSrcA),
      .ALUSrcB               (ALUSrcB),
      .ImmSrc                (ImmSrc),
      .STOREop               (STOREop),
      .LOADop                (LOADop),
      .CSRop                 (CSRop),
      .CSRwe                 (CSRwe),
      .CSRre                 (CSRre),
      .RegWrite              (RegWrite),
      .PCWrite               (PCWrite),
      .AdrSrc                (AdrSrc),
      .MemWrite              (MemWrite),
      .fetched_instr         (fetched_instr),
      .incr_inst_retired     (incr_inst_retired),
      .ALUOutWrite           (ALUOutWrite),
      .mem_valid             (mem_valid),
      .mem_ready             (mem_ready),
      .MULop                 (MULop),
      .unaligned_access_load (unaligned_access_load),
      .unaligned_access_store(unaligned_access_store),
      .access_fault          (access_fault),

      .mul_valid                  (mul_valid),
      .mul_ready                  (mul_ready),
      .DIVop                      (DIVop),
      .div_valid                  (div_valid),
      .div_ready                  (div_ready),
      // AMO
      .amo_temp_write_operation   (amo_temp_write_operation),
      .amo_set_reserved_state_load(amo_set_reserved_state_load),
      .amo_buffered_data          (amo_buffered_data),
      .amo_buffered_address       (amo_buffered_address),
      .amo_reserved_state_load    (amo_reserved_state_load),
      .muxed_Aluout_or_amo_rd_wr  (muxed_Aluout_or_amo_rd_wr),
      .select_ALUResult           (select_ALUResult),
      .select_amo_temp            (select_amo_temp),

      .exception_event (exception_event),
      .cause           (cause),
      .badaddr         (badaddr),
      .mret            (mret),
      .wfi_event       (wfi_event),
      .privilege_mode  (privilege_mode),
      .csr_access_fault(csr_access_fault),
      .mstatus         (mstatus),
      .mie             (mie),
      .mip             (mip)
  );

  datapath_unit #(
      .RESET_ADDR(RESET_ADDR),
      .STACKADDR (STACKADDR),
      .RV32E     (RV32E)
  ) datapath_unit_I (
      .clk   (clk),
      .resetn(resetn),

      .ResultSrc (ResultSrc),
      .ALUControl(ALUControl),
      .ALUSrcA   (ALUSrcA),
      .ALUSrcB   (ALUSrcB),
      .ImmSrc    (ImmSrc),
      .STOREop   (STOREop),
      .LOADop    (LOADop),
      .CSRop     (CSRop),
      .CSRwe     (CSRwe),
      .CSRre     (CSRre),
      .Zero      (Zero),
      .immb10    (immb10),

      .RegWrite         (RegWrite),
      .PCWrite          (PCWrite),
      .AdrSrc           (AdrSrc),
      .MemWrite         (MemWrite),
      .incr_inst_retired(incr_inst_retired),
      .fetched_instr    (fetched_instr),
      .ALUOutWrite      (ALUOutWrite),
      .Instr            (Instr),

      .mem_wstrb(mem_wstrb),
      .mem_addr(mem_addr),
      .mem_wdata(mem_wdata),
      .mem_rdata(mem_rdata),
      .unaligned_access_load(unaligned_access_load),
      .unaligned_access_store(unaligned_access_store),

      .MULop      (MULop),
      .mul_valid  (mul_valid),
      .mul_ready  (mul_ready),
      .DIVop      (DIVop),
      .div_valid  (div_valid),
      .div_ready  (div_ready),
      .ProgCounter(PC),

      // AMO
      .amo_temp_write_operation   (amo_temp_write_operation),
      .amo_set_reserved_state_load(amo_set_reserved_state_load),
      .amo_buffered_data          (amo_buffered_data),
      .amo_buffered_address       (amo_buffered_address),
      .amo_reserved_state_load    (amo_reserved_state_load),
      .muxed_Aluout_or_amo_rd_wr  (muxed_Aluout_or_amo_rd_wr),
      .select_ALUResult           (select_ALUResult),
      .select_amo_temp            (select_amo_temp),

      // Exception
      .exception_event (exception_event),
      .cause           (cause),
      .badaddr         (badaddr),
      .mret            (mret),
      .wfi_event       (wfi_event),
      .privilege_mode  (privilege_mode),
      .csr_access_fault(csr_access_fault),
      .mie             (mie),
      .mip             (mip),
      .mstatus         (mstatus),
      .IRQ3            (IRQ3),
      .IRQ7            (IRQ7)
  );
endmodule

// --- rx_uart.v ---
/*
 *  my_rx_uart - a simple rx uart
 *
 *  copyright (c) 2021  hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none
module rx_uart (
    input wire clk,
    input wire resetn,
    input wire rx_in,
    input wire data_rd,
    input wire [15:0] div,
    output reg error,
    output wire [31:0] data
);

  reg [2:0] state;
  reg [2:0] return_state;
  reg [2:0] bit_idx;
  reg [7:0] rx_data;
  reg ready;

  reg [16:0] wait_states;

  reg [2:0] rx_in_sync;
  always @(posedge clk) begin
    if (!resetn) begin
      rx_in_sync <= 0;
    end else begin
      rx_in_sync <= {rx_in_sync[1:0], rx_in};
    end
  end

  wire start_bit_detected;

  wire fifo_full;
  wire fifo_empty;
  wire [7:0] fifo_out;

  fifo #(
      .DATA_WIDTH(8),
      .DEPTH     (16)
  ) fifo_i (
      .clk   (clk),
      .resetn(resetn),
      .din   (rx_data[7:0]),
      .dout  (fifo_out),
      .push  (ready & ~fifo_full),
      .pop   (data_rd & ~fifo_empty),
      .full  (fifo_full),
      .empty (fifo_empty)
  );

  assign data = fifo_empty ? ~0 : {24'd0, fifo_out};


  always @(posedge clk) begin
    /*
            if (ready) begin
              $write("%c", rcvd_buf);
              $fflush;
            end
            */

    if (!resetn) begin
      state <= 0;
      ready <= 1'b0;
      error <= 1'b0;
      wait_states <= 1;

      bit_idx <= 0;
      rx_data <= 0;
    end else begin

      case (state)

        0: begin  /* idle */
          ready <= 1'b0;
          error <= 1'b0;
          if (rx_in_sync[2:1] == 2'b10) begin  // high to low
            wait_states <= {1'b0, div >> 1};
            return_state <= 1;
            state <= 4;
          end
        end

        1: begin
          if (~rx_in_sync[2]) begin  // still low?
            wait_states <= {1'b0, div};
            return_state <= 2;
            state <= 4;
          end else begin
            state <= 0;  // idle
          end
        end

        2: begin
          rx_data[bit_idx] <= rx_in_sync[2];  /* lsb first */
          bit_idx <= bit_idx + 1;

          wait_states <= {1'b0, div};
          return_state <= &bit_idx ? 3 : 2;
          state <= 4;
        end

        3: begin
          if (~rx_in_sync[2]) begin  // stop bit must high
            error <= 1'b1;
            state <= 0;
          end else begin
            wait_states <= {1'b0, div};
            return_state <= 0;
            state <= 4;
          end
        end

        4: begin  /* wait states */
          if (wait_states == 1) begin
            if (return_state == 0) begin
              ready <= 1'b1;
            end
            state <= return_state;
          end
          wait_states <= wait_states - 1;
        end

        default: begin
          state <= 0;
        end

      endcase

    end
  end  /* !reset */

endmodule

// --- tx_uart.v ---
/*
 *  tx_uart - a simple tx uart
 *
 *  copyright (c) 2021  hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none
module tx_uart (
    input wire clk,
    input wire resetn,
    input wire valid,
    input wire [7:0] tx_data,
    input wire [15:0] div,  /* SYSTEM_CYCLES/BAUDRATE */
    output reg tx_out,
    output wire ready,
    output wire busy
);


  reg [2:0] state;
  reg [2:0] return_state;
  reg [2:0] bit_idx;
  reg [7:0] tx_data_reg;
  reg       txfer_done;

  assign ready = txfer_done;
  assign busy  = |state;

  reg  [15:0] wait_states;
  wire [15:0] CYCLES_PER_SYMBOL;
  assign CYCLES_PER_SYMBOL = div;

  always @(posedge clk) begin

    if (resetn == 1'b0) begin
      tx_out      <= 1'b1;
      state       <= 0;
      txfer_done  <= 1'b0;
      bit_idx     <= 0;
      tx_data_reg <= 0;
      txfer_done  <= 0;
    end else begin

      case (state)

        0: begin  /* idle */
          txfer_done <= 1'b0;
          if (valid & !txfer_done) begin
            tx_out <= 1'b0;  /* start bit */
            tx_data_reg <= tx_data;

            wait_states <= CYCLES_PER_SYMBOL - 1;
            return_state <= 1;
            state <= 3;

          end else begin
            tx_out <= 1'b1;
          end
        end

        1: begin
          tx_out <= tx_data_reg[bit_idx];  /* lsb first */
          bit_idx <= bit_idx + 1;

          wait_states <= CYCLES_PER_SYMBOL - 1;
          return_state <= &bit_idx ? 2 : 1;
          state <= 3;
        end

        2: begin
          tx_out <= 1'b1;  /* stop bit */

          wait_states <= (CYCLES_PER_SYMBOL << 1) - 1;
          return_state <= 0;
          state <= 3;
        end

        3: begin  /* wait states */
          wait_states <= wait_states - 1;
          if (wait_states == 1) begin
            if (~(|return_state)) txfer_done <= 1'b1;
            state <= return_state;
          end
        end

        default: begin
          state <= 0;
        end

      endcase

    end
  end  /* !reset */

endmodule

// --- fifo.v ---
/*
 *  fifo.v
 *
 *  copyright (c) 2021  hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */

`default_nettype none
module fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 4
) (
    input wire clk,
    input wire resetn,
    input wire [DATA_WIDTH-1:0] din,
    output wire [DATA_WIDTH-1:0] dout,
    input wire push,
    input wire pop,
    output wire full,
    output wire empty
);

  reg [DATA_WIDTH-1:0] ram[0:DEPTH-1];

  reg [$clog2(DEPTH):0] cnt;
  reg [$clog2(DEPTH)-1:0] rd_ptr;
  reg [$clog2(DEPTH)-1:0] wr_ptr;

  reg [$clog2(DEPTH):0] cnt_next;
  reg [$clog2(DEPTH)-1:0] rd_ptr_next;
  reg [$clog2(DEPTH)-1:0] wr_ptr_next;

  assign empty = cnt == 0;
  assign full  = cnt == DEPTH;

  always @(posedge clk) begin
    if (~resetn) begin
      rd_ptr <= 0;
      wr_ptr <= 0;
      cnt <= 0;
    end else begin
      rd_ptr <= rd_ptr_next;
      wr_ptr <= wr_ptr_next;
      cnt <= cnt_next;
    end
  end

  always @(*) begin
    rd_ptr_next = rd_ptr;
    wr_ptr_next = wr_ptr;
    cnt_next = cnt;

    if (push) begin
      wr_ptr_next = wr_ptr + 1;
      cnt_next = (!pop || empty) ? cnt + 1 : cnt_next;
    end

    if (pop) begin
      rd_ptr_next = rd_ptr + 1;
      cnt_next = (!push || full) ? cnt - 1 : cnt_next;
    end

  end

  always @(posedge clk) begin
    if (push) ram[wr_ptr] <= din;
  end

  assign dout = ram[rd_ptr];

endmodule

// --- clint.v ---
/*
 *  kianv.v - a simple RISC-V rv32ima
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none
module clint (
    input wire clk,
    input wire resetn,
    input wire valid,
    input wire [31:0] addr,
    input wire [3:0] wmask,
    input wire [31:0] wdata,
    input wire [15:0] div,
    output reg [31:0] rdata,
    output wire is_valid,
    output reg ready,
    output wire IRQ3,
    output wire IRQ7
);

  wire is_msip = (addr == 32'h1100_0000);
  wire is_mtimecmpl = (addr == 32'h1100_4000);
  wire is_mtimecmph = (addr == 32'h1100_4004);
  wire is_mtimeh = (addr == 32'h1100_bffc);
  wire is_mtimel = (addr == 32'h1100_bff8);

  assign is_valid = valid && (is_msip || is_mtimecmpl || is_mtimecmph || is_mtimel || is_mtimeh);
  always @(posedge clk) ready <= !resetn ? 1'b0 : is_valid;

  reg [63:0] mtime;
  always @(posedge clk) mtime <= !resetn ? 0 : (tick) ? mtime + 1 : mtime;

  wire is_we = |wmask;

  reg [63:0] mtimecmp;
  reg msip;

  always @(posedge clk)
    if (!resetn) begin
      mtimecmp <= 0;
      msip <= 0;
    end else if (is_mtimecmpl && is_valid) begin
      if (wmask[0]) mtimecmp[7:0] <= wdata[7:0];
      if (wmask[1]) mtimecmp[15:8] <= wdata[15:8];
      if (wmask[2]) mtimecmp[23:16] <= wdata[23:16];
      if (wmask[3]) mtimecmp[31:24] <= wdata[31:24];
    end else if (is_mtimecmph && is_valid) begin
      if (wmask[0]) mtimecmp[39:32] <= wdata[7:0];
      if (wmask[1]) mtimecmp[47:40] <= wdata[15:8];
      if (wmask[2]) mtimecmp[55:48] <= wdata[23:16];
      if (wmask[3]) mtimecmp[63:56] <= wdata[31:24];
    end else if (is_msip && is_valid) begin
      if (wmask[0]) msip <= wdata[0];
    end

  always @(*) begin
    case (1'b1)
      is_mtimecmpl: rdata = mtimecmp[31:0];
      is_mtimecmph: rdata = mtimecmp[63:32];
      is_mtimel:    rdata = mtime[31:0];
      is_mtimeh:    rdata = mtime[63:32];
      is_msip:      rdata = {31'b0, msip};
      default:      rdata = 0;
    endcase
  end


  reg [17:0] tick_cnt;
  wire tick = tick_cnt == ({2'b0, div} - 1);
  always @(posedge clk) begin
    if (!resetn) begin
      tick_cnt <= 0;
    end else begin
      if (tick) begin
        tick_cnt <= 0;
      end else begin
        tick_cnt <= tick_cnt + 1;
      end
    end
  end

  assign IRQ3 = msip;
  assign IRQ7 = (mtime >= mtimecmp);

endmodule


// --- qqspi.v ---
/*
 *  kianv harris RISCV project
 *
 *  copyright (c) 2022 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
/*
  re-implementation and extension of from https://github.com/machdyne/qqspi/blob/main/rtl/qqspi.v
  Copyright (c) 2021 Lone Dynamics Corporation. All rights reserved.
*/
// added wmask, sync-comb fsm, spi flash support, cen polarity, faster during
// write operations: sb, sh behaves likes 8Mx32 memory
`default_nettype none
module qqspi #(parameter CHIP_SELECTS = 3)
(
    input wire [22:0] addr,  // 8Mx32
    output reg [31:0] rdata,
    input wire [31:0] wdata,
    input wire [3:0] wstrb,
    output reg ready,
    input wire valid,
    input wire clk,
    input wire resetn,
    input wire PSRAM_SPIFLASH,
    input wire QUAD_MODE,

    output reg  sclk,
    input  wire sio0_si_mosi_i,
    input  wire sio1_so_miso_i,
    input  wire sio2_i,
    input  wire sio3_i,

    output wire sio0_si_mosi_o,
    output wire sio1_so_miso_o,
    output wire sio2_o,
    output wire sio3_o,

    output reg [3:0] sio_oe,
    input wire [CHIP_SELECTS -1:0] ce_ctrl,
    output reg [CHIP_SELECTS -1:0] ce
);
  localparam [7:0] CMD_QUAD_WRITE = 8'h38;
  localparam [7:0] CMD_FAST_READ_QUAD = 8'hEB;
  localparam [7:0] CMD_WRITE = 8'h02;
  localparam [7:0] CMD_READ = 8'h03;

  //reg  [3:0] sio_oe;
  reg  [3:0] sio_out;
  wire [3:0] sio_in;

  wire write;
  assign write = |wstrb;
  wire read;
  assign read = ~write;

  assign {sio3_o, sio2_o, sio1_so_miso_o, sio0_si_mosi_o} = sio_out;
  assign sio_in = {sio3_i, sio2_i, sio1_so_miso_i, sio0_si_mosi_i};

  localparam [2:0] S0_IDLE = 3'd0;
  localparam [2:0] S1_SELECT_DEVICE = 3'd1;
  localparam [2:0] S2_CMD = 3'd2;
  localparam [2:0] S4_ADDR = 3'd3;
  localparam [2:0] S5_WAIT = 3'd4;
  localparam [2:0] S6_XFER = 3'd5;
  localparam [2:0] S7_WAIT_FOR_XFER_DONE = 3'd6;

  reg [2:0] state, next_state;
  reg [31:0] spi_buf;
  reg [5:0] xfer_cycles;
  reg is_quad;

  reg [31:0] rdata_next;

  reg sclk_next;
  reg [3:0] sio_oe_next;
  reg [3:0] sio_out_next;
  reg [31:0] spi_buf_next;
  reg is_quad_next;
  reg [5:0] xfer_cycles_next;
  reg ready_next;
  reg [CHIP_SELECTS -1:0] ce_next;

  wire [1:0] byte_offset;
  wire [5:0] wr_cycles;
  wire [31:0] wr_buffer;

  align_wdata align_wdata_i (
      .wstrb      (wstrb),
      .wdata      (wdata),
      .byte_offset(byte_offset),
      .wr_cycles  (wr_cycles),
      .wr_buffer  (wr_buffer)
  );

  always @(posedge clk) begin
    if (!resetn) begin
      ce <= ~0;
      sclk <= 1'b1;
      sio_oe <= 4'b0000;
      sio_out <= 4'b0000;
      spi_buf <= 0;
      is_quad <= 0;
      xfer_cycles <= 0;
      ready <= 0;
      state <= S0_IDLE;
    end else begin
      state <= next_state;
      ce <= ce_next;
      sclk <= sclk_next;
      sio_oe <= sio_oe_next;
      sio_out <= sio_out_next;
      spi_buf <= spi_buf_next;
      is_quad <= is_quad_next;
      xfer_cycles <= xfer_cycles_next;
      rdata <= rdata_next;
      ready <= ready_next;
    end
  end

  always @(*) begin
    next_state = state;
    ce_next = ce;
    sclk_next = sclk;
    sio_oe_next = sio_oe;
    sio_out_next = sio_out;
    spi_buf_next = spi_buf;
    is_quad_next = is_quad;
    xfer_cycles_next = xfer_cycles;
    ready_next = ready;
    rdata_next = rdata;
    xfer_cycles_next = xfer_cycles;

    if (|xfer_cycles) begin

      sio_out_next[3:0] = is_quad ? spi_buf[31:28] : {3'b0, spi_buf[31]};

      if (sclk) begin
        sclk_next = 1'b0;
      end else begin
        sclk_next = 1'b1;
        spi_buf_next = is_quad ? {spi_buf[27:0], sio_in[3:0]} : {spi_buf[30:0], sio_in[1]};
        xfer_cycles_next = is_quad ? xfer_cycles - 4 : xfer_cycles - 1;
      end

    end else begin
      case (state)
        S0_IDLE: begin
          sio_oe_next  = 4'b0001;
          is_quad_next = 0;
          if (valid && !ready) begin
            next_state = S1_SELECT_DEVICE;
            xfer_cycles_next = 0;
          end else if (!valid && ready) begin
            ready_next = 1'b0;
            ce_next = ~0;
          end else begin
            ce_next = ~0;
          end
        end

        S1_SELECT_DEVICE: begin
          ce_next = ~ce_ctrl;
          next_state = S2_CMD;
        end

        S2_CMD: begin
          if (QUAD_MODE) begin
            spi_buf_next[31:24] = write ? CMD_QUAD_WRITE : CMD_FAST_READ_QUAD;
          end else begin
            spi_buf_next[31:24] = write ? CMD_WRITE : CMD_READ;
          end

          xfer_cycles_next = 8;
          next_state = S4_ADDR;
        end

        S4_ADDR: begin
          if (PSRAM_SPIFLASH) begin
            spi_buf_next[31:8] = {1'b0, {addr[20:0], write ? byte_offset : 2'b00}};
          end else begin
            spi_buf_next[31:8] = {{addr[21:0], write ? byte_offset : 2'b00}};
          end

          sio_oe_next = QUAD_MODE ? 4'b1111 : 4'b0001;
          xfer_cycles_next = 24;

          is_quad_next = QUAD_MODE;
          next_state = QUAD_MODE && read ? S5_WAIT : S6_XFER;
        end

        S5_WAIT: begin
          sio_oe_next = 4'b0000;
          xfer_cycles_next = 6;
          is_quad_next = 0;
          next_state = S6_XFER;
        end

        S6_XFER: begin
          is_quad_next = QUAD_MODE;

          if (write) begin
            sio_oe_next  = QUAD_MODE ? 4'b1111 : 4'b0001;
            spi_buf_next = wr_buffer;
          end else begin
            sio_oe_next = QUAD_MODE ? 4'b0000 : 4'b0001;
          end

          xfer_cycles_next = write ? wr_cycles : 32;
          next_state = S7_WAIT_FOR_XFER_DONE;
        end

        S7_WAIT_FOR_XFER_DONE: begin
          if (PSRAM_SPIFLASH) begin
            rdata_next = spi_buf;
          end else begin
            // transform from little to big endian
            rdata_next = {spi_buf[7:0], spi_buf[15:8], spi_buf[23:16], spi_buf[31:24]};
          end
          ready_next = 1'b1;
          next_state = S0_IDLE;
        end

        default: next_state = S0_IDLE;
      endcase

    end

  end

endmodule

module align_wdata (
    input  wire [ 3:0] wstrb,
    input  wire [31:0] wdata,
    output reg  [ 1:0] byte_offset,
    output reg  [ 5:0] wr_cycles,
    output reg  [31:0] wr_buffer
);
  always @(*) begin
    wr_buffer = wdata;
    case (wstrb)
      4'b0001: begin
        byte_offset = 3;
        wr_buffer[31:24] = wdata[7:0];
        wr_cycles = 8;
      end
      4'b0010: begin
        byte_offset = 2;
        wr_buffer[31:24] = wdata[15:8];
        wr_cycles = 8;
      end
      4'b0100: begin
        byte_offset = 1;
        wr_buffer[31:24] = wdata[23:16];
        wr_cycles = 8;
      end
      4'b1000: begin
        byte_offset = 0;
        wr_buffer[31:24] = wdata[31:24];
        wr_cycles = 8;
      end
      4'b0011: begin
        byte_offset = 2;
        wr_buffer[31:16] = wdata[15:0];
        wr_cycles = 16;
      end
      4'b1100: begin
        byte_offset = 0;
        wr_buffer[31:16] = wdata[31:16];
        wr_cycles = 16;
      end
      4'b1111: begin
        byte_offset = 0;
        wr_buffer[31:0] = wdata[31:0];
        wr_cycles = 32;
      end
      default: begin
        byte_offset = 0;
        wr_buffer   = wdata;
        wr_cycles   = 32;
      end
    endcase
  end
endmodule

// --- soc.v ---
/*
 *  kianv.v - RISC-V rv32ima
 *
 *  copyright (c) 2023 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none
/* verilator lint_off PINCONNECTEMPTY */
/* verilator lint_off UNUSEDSIGNAL */
module soc (
    input  wire       clk_osc,
    output wire       uart_tx,
    input  wire       uart_rx,
    output wire [6:0] led,
    output wire [2:0] ce,
    output wire       sclk,

    input wire sio0_si_mosi_i,
    input wire sio1_so_miso_i,
    input wire sio2_i,
    input wire sio3_i,

    output wire sio0_si_mosi_o,
    output wire sio1_so_miso_o,
    output wire sio2_o,
    output wire sio3_o,

    output wire [3:0] sio_oe,

    input wire rst_n
);

  wire clk;

  wire [31:0] PC;



  assign led  = PC[16+:7];

  assign clk  = clk_osc;

  localparam BYTE_ADDRESS_LEN = 32;
  localparam BYTES_PER_BLOCK = 4;
  localparam DATA_LEN = 32;
  localparam BLOCK_ADDRESS_LEN = BYTE_ADDRESS_LEN - $clog2(BYTES_PER_BLOCK);

  localparam BRAM_ADDR_WIDTH = $clog2(`BRAM_WORDS);

  //////////////////////////////////////////////////////////////////////////////
  /* SYSCON */

  wire is_valid_reboot_addr = (cpu_mem_addr == `REBOOT_ADDR);
  wire is_valid_reboot_data = (cpu_mem_wdata[15:0] == `REBOOT_DATA);

  wire is_reboot_valid = cpu_mem_valid && is_valid_reboot_addr && is_valid_reboot_data && wr;

  // reset
  reg [3:0] rst_cnt;
  wire resetn = rst_cnt[3];

  always @(posedge clk) begin
    if (!rst_n || is_reboot_valid) rst_cnt <= 0;
    else rst_cnt <= rst_cnt + {3'b0, !resetn};
  end

  // cpu
  wire                      [31:0]                                           pc;
  wire                      [ 5:0]                                           ctrl_state;

  wire                                                                       cpu_mem_ready;
  wire                                                                       cpu_mem_valid;

  wire                      [ 3:0]                                           cpu_mem_wstrb;
  wire                      [31:0]                                           cpu_mem_addr;
  wire                      [31:0]                                           cpu_mem_wdata;
  wire                      [31:0]                                           cpu_mem_rdata;

  wire                      [31:0]                                           bram_rdata;
  reg                                                                        bram_ready;
  wire                                                                       bram_valid;

  // uart
  wire                                                                       uart_tx_valid;
  reg                                                                        uart_tx_ready;
  // uart
  wire                                                                       uart_rx_valid;
  reg                                                                        uart_rx_ready;

  // spi flash memory
  wire                      [31:0]                                           spi_nor_mem_data;
  wire                                                                       spi_nor_mem_valid;

  // divider
  wire                                                                       div_valid;
  reg                                                                        div_ready;

  // RISC-V is byte-addressable, alignment memory devices word organized
  // memory interface
  wire wr = |cpu_mem_wstrb;
  wire rd = ~wr;

  wire                      [29:0] word_aligned_addr = {cpu_mem_addr[31:2]};

  // cpu_freq
  reg                       [31:0]                                           div_reg;
  assign div_valid = !div_ready && cpu_mem_valid && (cpu_mem_addr == `DIV_ADDR);  // && !wr;
  always @(posedge clk) div_ready <= !resetn ? 1'b0 : div_valid;
  always @(posedge clk) begin
    if (!resetn) begin
      div_reg <= 0;
    end else begin
      if (div_valid && wr) div_reg <= cpu_mem_wdata;
    end
  end
  /////////////////////////////////////////////////////////////////////////////

  // SPI nor flash
  assign spi_nor_mem_valid = !qqspi_mem_ready && cpu_mem_valid &&
           (cpu_mem_addr >= `SPI_NOR_MEM_ADDR_START && cpu_mem_addr < `SPI_NOR_MEM_ADDR_END) && !wr;

  // PSRAM
  wire mem_sdram_valid;

  wire is_sdram = (cpu_mem_addr >= `SDRAM_MEM_ADDR_START && cpu_mem_addr < `SDRAM_MEM_ADDR_END);
  assign mem_sdram_valid = !qqspi_mem_ready && cpu_mem_valid && is_sdram;

  /////////////////////////////////////////////////////////////////////////////

  wire [31:0] qqspi_mem_rdata;
  wire qqspi_mem_ready;

  qqspi #(.CHIP_SELECTS(3)) qqspi_I (
      .addr({1'b0, word_aligned_addr[21:0]}),
      .wdata(cpu_mem_wdata),
      .rdata(qqspi_mem_rdata),
      .wstrb(cpu_mem_wstrb),
      .ready(qqspi_mem_ready),
      .valid(spi_nor_mem_valid | mem_sdram_valid),
      .QUAD_MODE(1'b1),
      .PSRAM_SPIFLASH(mem_sdram_valid),

      .sclk(sclk),

      .sio0_si_mosi_i(sio0_si_mosi_i),
      .sio1_so_miso_i(sio1_so_miso_i),
      .sio2_i        (sio2_i),
      .sio3_i        (sio3_i),

      .sio0_si_mosi_o(sio0_si_mosi_o),
      .sio1_so_miso_o(sio1_so_miso_o),
      .sio2_o        (sio2_o),
      .sio3_o        (sio3_o),
      .sio_oe        (sio_oe),

      .ce_ctrl({1'b0, mem_sdram_valid, spi_nor_mem_valid}),
      .ce(ce),

      .clk   (clk),
      .resetn(resetn)
  );

  /////////////////////////////////////////////////////////////////////////////

  wire uart_tx_valid_wr;

  // I have changed to blocked tx
  assign uart_tx_valid = ~uart_tx_ready && cpu_mem_valid && cpu_mem_addr == `UART_TX_ADDR;
  //assign uart_tx_valid = ~uart_tx_rdy && cpu_mem_valid && cpu_mem_addr == `UART_TX_ADDR; // blocking
  assign uart_tx_valid_wr = wr && uart_tx_valid;
  always @(posedge clk) uart_tx_ready <= !resetn ? 1'b0 : uart_tx_valid_wr;

  wire uart_tx_busy;
  wire uart_tx_rdy;

  tx_uart tx_uart_i (
      .clk    (clk),
      .resetn (resetn),
      .valid  (uart_tx_valid_wr),
      .tx_data(cpu_mem_wdata[7:0]),
      .div    (div_reg[15:0]),
      .tx_out (uart_tx),
      .ready  (uart_tx_rdy),
      .busy   (uart_tx_busy)
  );

  /////////////////////////////////////////////////////////////////////////////
  wire uart_lsr_valid_rd = ~uart_lsr_rdy && rd && cpu_mem_valid && cpu_mem_addr == `UART_LSR_ADDR;
  reg uart_lsr_rdy;
  always @(posedge clk) uart_lsr_rdy <= !resetn ? 1'b0 : uart_lsr_valid_rd;

  /////////////////////////////////////////////////////////////////////////////

  wire uart_rx_valid_rd;
  wire [31:0] rx_uart_data;

  assign uart_rx_valid = ~uart_rx_ready && cpu_mem_valid && cpu_mem_addr == `UART_RX_ADDR;
  assign uart_rx_valid_rd = rd && uart_rx_valid;

  always @(posedge clk) begin
    uart_rx_ready <= !resetn ? 1'b0 : uart_rx_valid_rd;
  end

  wire rx_uart_rdy = uart_rx_ready;
  rx_uart rx_uart_i (
      .clk    (clk),
      .resetn (resetn),
      .rx_in  (uart_rx),
      .div    (div_reg[15:0]),
      .error  (),
      .data_rd(rx_uart_rdy),    // pop
      .data   (rx_uart_data)
  );

  /////////////////////////////////////////////////////////////////////////////

  wire IRQ3;
  wire IRQ7;
  wire clint_valid;
  wire clint_ready;
  wire [31:0] clint_rdata;

  clint clint_I (
      .clk     (clk),
      .resetn  (resetn),
      .valid   (cpu_mem_valid),
      .addr    (cpu_mem_addr),
      .wmask   (cpu_mem_wstrb),
      .wdata   (cpu_mem_wdata),
      .rdata   (clint_rdata),
      .div     (div_reg[31:16]),
      .IRQ3    (IRQ3),
      .IRQ7    (IRQ7),
      .is_valid(clint_valid),
      .ready   (clint_ready)
  );

  /////////////////////////////////////////////////////////////////////////////
  kianv_harris_mc_edition #(
      .RESET_ADDR(`RESET_ADDR)
  ) kianv_I (
      .clk         (clk),
      .resetn      (resetn),
      .mem_ready   (cpu_mem_ready),
      .mem_valid   (cpu_mem_valid),
      .mem_wstrb   (cpu_mem_wstrb),
      .mem_addr    (cpu_mem_addr),
      .mem_wdata   (cpu_mem_wdata),
      .mem_rdata   (cpu_mem_rdata),
      .access_fault(access_fault),
      .IRQ3        (IRQ3),
      .IRQ7        (IRQ7),
      .PC          (PC)
  );

  /////////////////////////////////////////////////////////////////////////////
  wire is_io = (cpu_mem_addr >= 32'h10_000_000 && cpu_mem_addr <= 32'h12_000_000);
  wire unmatched_io = !(uart_lsr_valid_rd || uart_tx_valid || uart_rx_valid || clint_valid || div_valid);

  wire access_fault = cpu_mem_valid & (!is_io || !is_sdram);

  reg io_ready;
  reg [31:0] io_rdata;
  reg [7:0] byteswaiting;

  always @(*) begin
    io_rdata = 0;
    io_ready = 1'b0;
    byteswaiting = 0;
    if (is_io) begin
      if (uart_lsr_rdy) begin
        byteswaiting = {1'b0, !uart_tx_busy, !uart_tx_busy, 1'b0, 3'b0, !(&rx_uart_data)};
        io_rdata = {16'b0, byteswaiting, 8'b0};
        io_ready = 1'b1;
      end else if (uart_rx_ready) begin
        io_rdata = rx_uart_data;
        io_ready = 1'b1;
      end else if (uart_tx_ready) begin
        io_rdata = 0;
        io_ready = 1'b1;
        //io_ready = uart_tx_rdy; // blocking
      end else if (clint_ready) begin
        io_rdata = clint_rdata;
        io_ready = 1'b1;
      end else if (div_ready) begin
        io_rdata = div_reg;
        io_ready = 1'b1;
      end else if (unmatched_io) begin
        io_rdata = 0;
        io_ready = 1'b1;
      end
    end
  end

  /////////////////////////////////////////////////////////////////////////////
  assign cpu_mem_ready = qqspi_mem_ready || io_ready;

  assign cpu_mem_rdata = qqspi_mem_ready ? qqspi_mem_rdata : io_ready ? io_rdata : 32'h0000_0000;

endmodule
/* verilator lint_on PINCONNECTEMPTY */
/* verilator lint_on UNUSEDSIGNAL */

// --- tt_um_kianV_rv32ima_uLinux_SoC.v ---
`default_nettype none
/* verilator lint_off UNUSEDSIGNAL */
module tt_um_kianV_rv32ima_uLinux_SoC (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire sio0_si_mosi_i;
  wire sio1_so_miso_i;
  wire sio2_i;
  wire sio3_i;

  wire sio0_si_mosi_o;
  wire sio1_so_miso_o;
  wire sio2_o;
  wire sio3_o;

  wire [3:0] sio_oe;

  wire uart_tx;
  wire uart_rx;
  wire [6:0] led;
  wire [2:0] ce;
  wire sclk;

  wire clk_osc = clk;

  assign uo_out[0] = led[0];
  assign uo_out[2:1] = led[2:1];
  assign uo_out[3] = led[3];
  assign uo_out[4] = uart_tx;
  assign uo_out[5] = led[4];
  assign uo_out[6] = led[5];
  assign uo_out[7] = led[6];

  assign uart_rx = ui_in[3];

  /*
  assign {sio3_i, sio2_i, sio1_so_miso_i, sio0_si_mosi_i} = {
    uio_in[5], uio_in[4], uio_in[2], uio_in[1]
  };
  */
  assign sio3_i = uio_in[5];
  assign sio2_i = uio_in[4];
  assign sio1_so_miso_i = uio_in[2];
  assign sio0_si_mosi_i = uio_in[1];

  assign uio_oe = {2'b11, sio_oe[3:2], 1'b1, sio_oe[1:0], 1'b1};
  assign uio_out = {
    ce[2], ce[1], sio3_o, sio2_o, sclk, sio1_so_miso_o, sio0_si_mosi_o, ce[0]
  };

  soc soc_I (
      .clk_osc(clk_osc),
      .uart_tx(uart_tx),
      .uart_rx(uart_rx),
      .led    (led),
      .sclk   (sclk),
      .ce     (ce),

      .sio0_si_mosi_i(sio0_si_mosi_i),
      .sio1_so_miso_i(sio1_so_miso_i),
      .sio2_i        (sio2_i),
      .sio3_i        (sio3_i),

      .sio0_si_mosi_o(sio0_si_mosi_o),
      .sio1_so_miso_o(sio1_so_miso_o),
      .sio2_o        (sio2_o),
      .sio3_o        (sio3_o),

      .sio_oe(sio_oe),
      .rst_n (rst_n)
  );

endmodule
/* verilator lint_on UNUSEDSIGNAL */


module sasic_top (
    input  wire clk, input  wire rst_n,
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
    wire [7:0] ui_in  = {in_7,in_6,in_5,in_4,in_3,in_2,in_1,in_0};
    wire [7:0] uio_in = {in_15,in_14,in_13,in_12,in_11,in_10,in_9,in_8};
    wire [7:0] uo_out, uio_out, uio_oe;
    tt_um_kianV_rv32ima_uLinux_SoC tt_inst (
        .ui_in(ui_in),.uo_out(uo_out),.uio_in(uio_in),
        .uio_out(uio_out),.uio_oe(uio_oe),
        .ena(1'b1),.clk(clk),.rst_n(rst_n)
    );
    assign {out_7,out_6,out_5,out_4,out_3,out_2,out_1,out_0} = uo_out;
    assign {out_15,out_14,out_13,out_12,out_11,out_10,out_9,out_8} = uio_out;
    assign {out_39,out_38,out_37,out_36,out_35,out_34,out_33,out_32,
            out_31,out_30,out_29,out_28,out_27,out_26,out_25,out_24,
            out_23,out_22,out_21,out_20,out_19,out_18,out_17,out_16} = 24'd0;
    assign {oeb_7,oeb_6,oeb_5,oeb_4,oeb_3,oeb_2,oeb_1,oeb_0} = 8'hFF;
    assign {oeb_15,oeb_14,oeb_13,oeb_12,oeb_11,oeb_10,oeb_9,oeb_8} = ~uio_oe;
    assign {oeb_39,oeb_38,oeb_37,oeb_36,oeb_35,oeb_34,oeb_33,oeb_32,
            oeb_31,oeb_30,oeb_29,oeb_28,oeb_27,oeb_26,oeb_25,oeb_24,
            oeb_23,oeb_22,oeb_21,oeb_20,oeb_19,oeb_18,oeb_17,oeb_16} = 24'hFFFFFF;
endmodule
