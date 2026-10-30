module instrFetch 
import riscv_pkg::*;
(
    input  logic        clk, rst_n_pc,rst_n_if,if_en,flush,
    input  logic [31:0] jump_target, branch_target,
    input  logic [1:0]  pc_sel,
    input logic pc_write,

    output if_id_t if_id_out
);

    logic [31:0] next_inst;
     logic [31:0] pc_out;
     logic [31:0] pc_plus;
     logic [31:0] instr;

    assign pc_plus = pc_out + 32'd4;

    always_comb begin
        case (pc_sel)
            2'b01:   next_inst = jump_target;
            2'b10:   next_inst = branch_target;
            default: next_inst = pc_plus;
        endcase
    end

    PC mypc (
        .rst_n     (rst_n_pc),
        .clk       (clk),
        .pc_write(pc_write),
        .next_inst (next_inst),
        .pc_out    (pc_out)
    );

    imem instruction_memory(
        .addr(pc_out),
        .instr(instr)

    );

    if_id if_id_reg(
        .en(if_en),
        .rst_n(rst_n_if),
        .clk(clk),
        .flush(flush),
        .instr(instr),
        .pc_out(pc_out),
        .pc_plus(pc_plus),
        .out(if_id_out)
    );
endmodule

