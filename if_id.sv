module if_id
import riscv_pkg::*;
(
    input  logic        clk, rst_n, en, flush,
    input  logic [31:0] instr, pc_out, pc_plus,
    output if_id_t      out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out.instr   <= 32'h00000013;
            out.pc_out  <= 32'd0;
            out.pc_plus <= 32'd0;
        end else if (flush) begin
            out.instr   <= 32'h00000013;
            out.pc_out  <= 32'd0;
            out.pc_plus <= 32'd0;
        end else if (en) begin
            out.instr   <= instr;
            out.pc_out  <= pc_out;
            out.pc_plus <= pc_plus;
        end
    end

endmodule