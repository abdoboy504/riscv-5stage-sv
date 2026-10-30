
module immediateGenerator
import riscv_pkg::*;
(
    input  imm_sel_t    imm_sel,
    input  logic [31:0] instr,
    output logic [31:0] imm_val
);

always_comb begin : imm_gen
    case (imm_sel)
        IMM_I: imm_val = {{20{instr[31]}}, instr[31:20]};

        IMM_S: imm_val = {{20{instr[31]}},
                          instr[31:25], instr[11:7]};

        IMM_B: imm_val = {
            {19{instr[31]}},
            instr[31],
            instr[7],
            instr[30:25],
            instr[11:8],
            1'b0
        };

        IMM_U: imm_val = {instr[31:12], 12'b0};

        IMM_J: imm_val = {
            {11{instr[31]}},
            instr[31],
            instr[19:12],
            instr[20],
            instr[30:21],
            1'b0
        };

        default: imm_val = 32'b0;
    endcase
end

endmodule
