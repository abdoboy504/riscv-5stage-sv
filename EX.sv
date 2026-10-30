// EX/MEM pipeline register. Reset value is all zeros = NOP.
module ex_mem
import riscv_pkg::*;
(
    input  logic    clk, rst_n,
    input  ex_mem_t in,
    output ex_mem_t out
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) out <= '0;
        else        out <= in;
    end
endmodule


// EX stage: forwarding muxes + ALU + branch comparator + flush unit + EX/MEM register
module execute
import riscv_pkg::*;
(
    input  logic        clk, rst_n,
    input  id_ex_t      ex_in,          // from ID/EX register

    // write-back (instruction two ahead) for forwarding
    input  logic        wb_reg_write,
    input  logic [4:0]  wb_rd,
    input  logic [31:0] wb_data,        // FINAL write-back value (after the wb_sel mux)

    output ex_mem_t     ex_mem_out,     // to MEM (also used here for forwarding)

    // redirect / flush (to fetch and decode)
    output logic        pc_redirect,
    output logic [31:0] target,         // branch/JAL/JALR target
    output logic        flush_if_id,
    output logic        flush_id_ex
);

    // ---------------- forwarding ----------------
    logic [1:0]  forward_a, forward_b;

    forwarding_unit u_fwd (
        .ex_rs1        (ex_in.rs1),
        .ex_rs2        (ex_in.rs2),
        .mem_rd        (ex_mem_out.rd),
        .mem_reg_write (ex_mem_out.reg_write),
        .wb_rd         (wb_rd),
        .wb_reg_write  (wb_reg_write),
        .forward_a     (forward_a),
        .forward_b     (forward_b)
    );

    // Value the instruction in MEM will write back (loads excluded: the
    // load-use stall guarantees nobody needs a load result from here).
    logic [31:0] mem_fwd_data;
    always_comb begin
        case (ex_mem_out.wb_sel)
            WB_PC4:       mem_fwd_data = ex_mem_out.pc_plus;
            WB_UPPER_IMM: mem_fwd_data = ex_mem_out.imm_val;
            default:      mem_fwd_data = ex_mem_out.alu_result;
        endcase
    end

    logic [31:0] op_a, op_b;   // forwarded rs1 / rs2 values

    always_comb begin
        case (forward_a)
            2'b01:   op_a = mem_fwd_data;
            2'b10:   op_a = wb_data;
            default: op_a = ex_in.rs1_data;
        endcase

        case (forward_b)
            2'b01:   op_b = mem_fwd_data;
            2'b10:   op_b = wb_data;
            default: op_b = ex_in.rs2_data;
        endcase
    end

    // ---------------- ALU ----------------
    logic [31:0] alu_result;

    alu u_alu (
        .alu_a    (op_a),
        .alu_b    (op_b),
        .PC       (ex_in.pc_out),
        .imm_val  (ex_in.imm_val),
        .op       (ex_in.alu_op),
        .alu_a_pc (ex_in.alu_a_pc),
        .alu_src  (ex_in.alu_src),
        .result   (alu_result),
        .z        ()
    );

    // ---------------- branch comparator ----------------
    logic cmp_true;

    Comparatore u_cmp (
        .rs1     (op_a),
        .rs2     (op_b),
        .comp_op (ex_in.comp_op),
        .comp_en (ex_in.comp_en),
        .comp_out(cmp_true)
    );

    // ---------------- redirect / flush ----------------
    // Branch/JAL target = pc + imm (ALU), JALR target = rs1 + imm with bit 0 cleared.
    assign target = {alu_result[31:1], 1'b0};

    flush_unit u_flush (
        .ex_branch    (ex_in.comp_en),
        .cmp_true     (cmp_true),
        .ex_jal       (ex_in.jump && !ex_in.sig_jalr),
        .ex_jalr      (ex_in.sig_jalr),
        .pc_redirect  (pc_redirect),
        .flush_if_id  (flush_if_id),
        .flush_id_ex  (flush_id_ex)
    );

    // ---------------- EX/MEM register ----------------
    ex_mem_t ex_mem_in;

    always_comb begin
        ex_mem_in.alu_result    = alu_result;
        ex_mem_in.store_data    = op_b;             // forwarded rs2, not the immediate
        ex_mem_in.pc_plus       = ex_in.pc_plus;
        ex_mem_in.imm_val       = ex_in.imm_val;
        ex_mem_in.rd            = ex_in.rd;
        ex_mem_in.mem_read      = ex_in.mem_read;
        ex_mem_in.mem_write     = ex_in.mem_write;
        ex_mem_in.mem_width     = ex_in.mem_width;
        ex_mem_in.load_unsigned = ex_in.load_unsigned;
        ex_mem_in.reg_write     = ex_in.reg_write;
        ex_mem_in.wb_sel        = ex_in.wb_sel;
    end

    ex_mem u_ex_mem (
        .clk   (clk),
        .rst_n (rst_n),
        .in    (ex_mem_in),
        .out   (ex_mem_out)
    );

endmodule