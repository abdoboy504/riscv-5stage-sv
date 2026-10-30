
package riscv_pkg;

  typedef enum logic [3:0] {
    ALU_ADD  = 4'd0,
    ALU_SUB  = 4'd1,
    ALU_AND  = 4'd2,
    ALU_OR   = 4'd3,
    ALU_XOR  = 4'd4,
    ALU_SLL  = 4'd5,
    ALU_SRL  = 4'd6,
    ALU_SRA  = 4'd7,
    ALU_SLT  = 4'd8,
    ALU_SLTU = 4'd9
  } alu_op_t;

 typedef enum logic [2:0] {
    COMP_EQUAL  = 3'b000, // BEQ
    COMP_NEQUAL = 3'b001, // BNE
    COMP_SLT    = 3'b100, // BLT: signed less than
    COMP_SGE    = 3'b101, // BGE: signed greater or equal
    COMP_ULT    = 3'b110, // BLTU: unsigned less than
    COMP_UGE    = 3'b111  // BGEU: unsigned greater or equal
    } comp_op_t;
  typedef enum logic [6:0] {
    OP_LOAD     = 7'b0000011,
    OP_IMM      = 7'b0010011,
    OP_AUIPC    = 7'b0010111,
    OP_STORE    = 7'b0100011,
    OP_OP       = 7'b0110011,
    OP_LUI      = 7'b0110111,
    OP_BRANCH   = 7'b1100011,
    OP_JALR     = 7'b1100111,
    OP_JAL      = 7'b1101111,
    OP_SYSTEM   = 7'b1110011,
    OP_MISC_MEM = 7'b0001111
  } opcode_t;

typedef enum logic [2:0] {
    IMM_I = 3'b000,
    IMM_S = 3'b001,
    IMM_B = 3'b010,
    IMM_U = 3'b011,
    IMM_J = 3'b100
} imm_sel_t;

typedef enum logic [1:0] {
    WB_ALU,
    WB_MEM,
    WB_UPPER_IMM,
    WB_PC4
} wb_sel_t; 

typedef struct packed {
    logic [31:0] instr;
    logic [31:0] pc_out;
    logic [31:0] pc_plus;
} if_id_t;

// Paste this inside `package riscv_pkg;` (after the enums and if_id_t).
// All-zero value = harmless NOP (ALU_ADD, COMP_EQUAL, WB_ALU are all 0).

typedef struct packed {
    // data
    logic [31:0] pc_out;
    logic [31:0] pc_plus;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] imm_val;       // also needed in WB for LUI (WB_UPPER_IMM)

    // register indices (rs1/rs2 for the forwarding unit, rd for WB)
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [4:0]  rd;

    // EX controls
    alu_op_t     alu_op;
    logic        alu_src;
    logic        alu_a_pc;
    logic        comp_en;
    comp_op_t    comp_op;
    logic        jump;
    logic        sig_jalr;

    // MEM controls
    logic        mem_read;
    logic        mem_write;
    logic [1:0]  mem_width;
    logic        load_unsigned;

    // WB controls
    logic        reg_write;
    wb_sel_t     wb_sel;
} id_ex_t;

typedef struct packed {
    // data
    logic [31:0] alu_result;    // memory address, or result for ALU instructions
    logic [31:0] store_data;    // forwarded rs2 (data for SB/SH/SW)
    logic [31:0] pc_plus;       // write-back value for JAL/JALR
    logic [31:0] imm_val;       // write-back value for LUI
 
    logic [4:0]  rd;
 
    // MEM controls
    logic        mem_read;
    logic        mem_write;
    logic [1:0]  mem_width;
    logic        load_unsigned;
 
    // WB controls
    logic        reg_write;
    wb_sel_t     wb_sel;
} ex_mem_t;
 
// All-zero value = harmless NOP.

typedef struct packed {
    logic [31:0] load_data;     // aligned / extended load result
    logic [31:0] alu_result;
    logic [31:0] pc_plus;       // JAL/JALR write-back
    logic [31:0] imm_val;       // LUI write-back
    logic [4:0]  rd;
    logic        reg_write;
    wb_sel_t     wb_sel;
} mem_wb_t;

endpackage



module alu
import riscv_pkg::*;
(
    input  logic [31:0] alu_a,
    input  logic [31:0] alu_b,
    input  logic [31:0] PC,
    input  logic [31:0] imm_val,
    input  alu_op_t    op,
    input  logic       alu_a_pc,
    input  logic       alu_src,
    output logic [31:0] result,
    output logic        z
);

    logic [31:0] operand_a;
    logic [31:0] operand_b;

    always_comb begin : ops

        // Select the ALU operands
        operand_a = alu_a_pc ? PC      : alu_a;
        operand_b = alu_src  ? imm_val : alu_b;

        // Perform the selected operation
        case (op)
            ALU_ADD:  result = operand_a + operand_b;
            ALU_SUB:  result = operand_a - operand_b;
            ALU_AND:  result = operand_a & operand_b;
            ALU_OR:   result = operand_a | operand_b;
            ALU_XOR:  result = operand_a ^ operand_b;

            ALU_SLL:  result = operand_a << operand_b[4:0];
            ALU_SRL:  result = operand_a >> operand_b[4:0];
            ALU_SRA:  result = $signed(operand_a) >>> operand_b[4:0];

            ALU_SLT:  result = $signed(operand_a) < $signed(operand_b)
                               ? 32'd1 : 32'd0;

            ALU_SLTU: result = operand_a < operand_b
                               ? 32'd1 : 32'd0;

            default:  result = 32'd0;
        endcase
    end

    assign z = (result == 32'd0);

endmodule
