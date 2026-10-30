module Comparatore
import riscv_pkg::*;
(
    input logic [31:0] rs1,rs2,
    input comp_op_t comp_op,
    input logic  comp_en,
    output logic comp_out

);
always_comb begin
    comp_out = 1'b0;  // Default: comparison is false
if(comp_en)
begin
    case (comp_op)
        COMP_EQUAL:  comp_out = (rs1 == rs2);
        COMP_NEQUAL: comp_out = (rs1 != rs2);
        COMP_SLT:    comp_out = ($signed(rs1) < $signed(rs2));
        COMP_SGE:    comp_out = ($signed(rs1) >= $signed(rs2));
        COMP_ULT:    comp_out = (rs1 < rs2);
        COMP_UGE:    comp_out = (rs1 >= rs2);
        default:     comp_out = 1'b0;
    endcase
end
end

endmodule
