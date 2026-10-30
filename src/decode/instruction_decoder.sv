module decoder
import riscv_pkg::*;
(
    input  logic [31:0] instr,

    // ALU control
    output alu_op_t     alu_op,
    output logic        alu_src,        // 1: ALU B input = immediate
    output logic        alu_a_pc,       // 1: ALU A input = PC

    // Immediate
    output imm_sel_t    imm_sel,

    // Register file / writeback
    output logic        reg_write,
    output wb_sel_t     wb_sel,

    // Data memory
    output logic        mem_read,
    output logic        mem_write,
    output logic [1:0]  mem_width,      // 00: byte, 01: halfword, 10: word
    output logic        load_unsigned,

    // Control flow
    output logic        comp_en,        // branch instruction
    output comp_op_t    comp_op,
    output logic        jump,           // unconditional jump (JAL)
    output logic        sig_jalr,         // used to distinguish JALR from JAL 
    // Exceptions
    output logic        illegal_instr
);

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    always_comb begin : decode_comb
        // Defaults (prevent latches)
        alu_op        = ALU_ADD;
        alu_src       = 1'b0;
        alu_a_pc      = 1'b0;
        imm_sel       = IMM_I;
        reg_write     = 1'b0;
        wb_sel        = WB_ALU;
        mem_read      = 1'b0;
        mem_write     = 1'b0;
        mem_width     = 2'b10;
        load_unsigned = 1'b0;
        comp_en       = 1'b0;
        comp_op       = COMP_EQUAL;
        jump          = 1'b0;
        illegal_instr = 1'b0;
        sig_jalr      = 1'b0;  

        case (opcode)

            // ---------------- R-type ----------------
            OP_OP: begin
                reg_write = 1'b1;
                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: alu_op = ALU_ADD;
                    {7'b0100000, 3'b000}: alu_op = ALU_SUB;
                    {7'b0000000, 3'b001}: alu_op = ALU_SLL;
                    {7'b0000000, 3'b010}: alu_op = ALU_SLT;
                    {7'b0000000, 3'b011}: alu_op = ALU_SLTU;
                    {7'b0000000, 3'b100}: alu_op = ALU_XOR;
                    {7'b0000000, 3'b101}: alu_op = ALU_SRL;
                    {7'b0100000, 3'b101}: alu_op = ALU_SRA;
                    {7'b0000000, 3'b110}: alu_op = ALU_OR;
                    {7'b0000000, 3'b111}: alu_op = ALU_AND;
                    default:              illegal_instr = 1'b1;
                endcase
            end

            // ---------------- I-type ALU ----------------
            OP_IMM: begin
                alu_src   = 1'b1;
                reg_write = 1'b1;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    3'b001: begin
                        if (funct7 == 7'b0000000) alu_op = ALU_SLL;
                        else                      illegal_instr = 1'b1;
                    end
                    3'b101: begin
                        case (funct7)
                            7'b0000000: alu_op = ALU_SRL;
                            7'b0100000: alu_op = ALU_SRA;
                            default:    illegal_instr = 1'b1;
                        endcase
                    end
                    default: illegal_instr = 1'b1;
                endcase
            end

            // ---------------- Loads ----------------
            OP_LOAD: begin
                wb_sel    = WB_MEM;
                alu_src   = 1'b1;
                mem_read  = 1'b1;
                reg_write = 1'b1;
                case (funct3)
                    3'b000: begin mem_width = 2'b00; load_unsigned = 1'b0; end // LB
                    3'b001: begin mem_width = 2'b01; load_unsigned = 1'b0; end // LH
                    3'b010: begin mem_width = 2'b10; load_unsigned = 1'b0; end // LW
                    3'b100: begin mem_width = 2'b00; load_unsigned = 1'b1; end // LBU
                    3'b101: begin mem_width = 2'b01; load_unsigned = 1'b1; end // LHU
                    default: illegal_instr = 1'b1;
                endcase
            end

            // ---------------- Stores ----------------
            OP_STORE: begin
                imm_sel   = IMM_S;
                alu_src   = 1'b1;
                mem_write = 1'b1;
                case (funct3)
                    3'b000: mem_width = 2'b00; // SB
                    3'b001: mem_width = 2'b01; // SH
                    3'b010: mem_width = 2'b10; // SW
                    default: illegal_instr = 1'b1;
                endcase
            end

            // ---------------- Upper immediates ----------------
            OP_AUIPC: begin
                imm_sel   = IMM_U;
                alu_a_pc  = 1'b1;
                alu_src   = 1'b1;
                alu_op    = ALU_ADD;
                reg_write = 1'b1;
            end

            OP_LUI: begin
                imm_sel   = IMM_U;
                wb_sel    = WB_UPPER_IMM;
                reg_write = 1'b1;
            end

            // ---------------- Branches ----------------
            OP_BRANCH: begin
                imm_sel  = IMM_B;
                comp_en  = 1'b1;
                alu_a_pc = 1'b1;   // target = PC + imm_B (remove if using a dedicated adder)
                alu_src  = 1'b1;
                case (funct3)
                    3'b000: comp_op = COMP_EQUAL;  // BEQ
                    3'b001: comp_op = COMP_NEQUAL; // BNE
                    3'b100: comp_op = COMP_SLT;    // BLT
                    3'b101: comp_op = COMP_SGE;    // BGE
                    3'b110: comp_op = COMP_ULT;    // BLTU
                    3'b111: comp_op = COMP_UGE;    // BGEU
                    default: illegal_instr = 1'b1;
                endcase
            end

            // ---------------- Jumps ----------------
            OP_JAL: begin
                imm_sel   = IMM_J;
                alu_a_pc  = 1'b1;
                alu_src   = 1'b1;
                jump      = 1'b1;
                reg_write = 1'b1;
                wb_sel    = WB_PC4;
            end

            OP_JALR: begin
            if (funct3 == 3'b000) begin
                imm_sel   = IMM_I;
                alu_src   = 1'b1;
                jump      = 1'b1;
                reg_write = 1'b1;
                sig_jalr  = 1'b1;
                wb_sel    = WB_PC4;
            end 
            else begin
                illegal_instr = 1'b1;
            end
            end

            default: illegal_instr = 1'b1;
        endcase

        // An illegal instruction must have no side effects
        if (illegal_instr) begin
            reg_write = 1'b0;
            mem_read  = 1'b0;
            mem_write = 1'b0;
            comp_en   = 1'b0;
            jump      = 1'b0;
        end
    end

endmodule