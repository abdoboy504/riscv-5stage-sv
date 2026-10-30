// Top-level 5-stage RV32I core: IF -> ID -> EX -> MEM -> WB
module core
import riscv_pkg::*;
(
    input  logic clk,
    input  logic rst_n,
    output logic illegal_instr      // debug: decoder saw an unsupported instruction
);

    // ---------------- pipeline register outputs ----------------
    if_id_t   if_id_out;
    id_ex_t   id_ex_out;
    ex_mem_t  ex_mem_out;
    mem_wb_t  mem_wb_out;

    // ---------------- hazard / redirect signals ----------------
    logic        stall;             // load-use stall (from ID)
    logic        pc_redirect;       // taken branch or jump (from EX)
    logic [31:0] target;            // redirect target (from EX)
    logic        flush_if_id;       // from EX
    logic        flush_id_ex;       // from EX

    // ---------------- write-back signals ----------------
    logic        wb_reg_write;
    logic [4:0]  wb_rd;
    logic [31:0] wb_data;

    // ---------------- IF ----------------
    // Redirect wins over stall: the PC must still take the target.
    // IF/ID: flush has priority over enable inside the if_id module.
    instrFetch u_if (
        .clk           (clk),
        .rst_n_pc      (rst_n),
        .rst_n_if      (rst_n),
        .if_en         (!stall),
        .flush         (flush_if_id),
        .jump_target   (target),
        .branch_target (target),
        .pc_sel        (pc_redirect ? 2'b01 : 2'b00),
        .pc_write      (!stall || pc_redirect),
        .if_id_out     (if_id_out)
    );

    // ---------------- ID ----------------
    instrDecode u_id (
        .clk           (clk),
        .rst_n         (rst_n),
        .if_out        (if_id_out),
        .flush         (flush_id_ex),
        .wb_we         (wb_reg_write),
        .wb_addr       (wb_rd),
        .wb_data       (wb_data),
        .id_ex_out     (id_ex_out),
        .stall         (stall),
        .illegal_instr (illegal_instr)
    );

    // ---------------- EX ----------------
    execute u_ex (
        .clk          (clk),
        .rst_n        (rst_n),
        .ex_in        (id_ex_out),
        .wb_reg_write (wb_reg_write),
        .wb_rd        (wb_rd),
        .wb_data      (wb_data),
        .ex_mem_out   (ex_mem_out),
        .pc_redirect  (pc_redirect),
        .target       (target),
        .flush_if_id  (flush_if_id),
        .flush_id_ex  (flush_id_ex)
    );

    // ---------------- MEM ----------------
    memory_stage u_mem (
        .clk        (clk),
        .rst_n      (rst_n),
        .mem_in     (ex_mem_out),
        .mem_wb_out (mem_wb_out)
    );

    // ---------------- WB ----------------
    writeback u_wb (
        .wb_in        (mem_wb_out),
        .wb_data      (wb_data),
        .wb_rd        (wb_rd),
        .wb_reg_write (wb_reg_write)
    );

endmodule