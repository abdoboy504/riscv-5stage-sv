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

endpackage
module if_tb;
import riscv_pkg::*;
  logic        clk = 1'b0;
  logic        rst_n_pc, rst_n_if, if_en, flush, pc_write;
  logic [31:0] jump_target, branch_target;
  logic [1:0]  pc_sel;
  if_id_t      if_id_out;

  instrFetch dut (
    .clk(clk), .rst_n_if(rst_n_if), .rst_n_pc(rst_n_pc),
    .if_en(if_en), .flush(flush),
    .jump_target(jump_target), .branch_target(branch_target),
    .pc_sel(pc_sel), .pc_write(pc_write),
    .if_id_out(if_id_out)
  );

  always #5 clk = ~clk;

  int errors = 0;
  logic [31:0] exp_pc;

  task automatic check_pc(string msg, logic [31:0] exp);
    if (dut.pc_out !== exp) begin
      $error("%s: expected %h, got %h", msg, exp, dut.pc);
      errors++;
    end
  endtask

  // wait for a rising edge, then sample just after it
  task automatic step();
    @(posedge clk); #1;
  endtask

  initial begin
    // start in reset
    rst_n_pc = 0; rst_n_if = 0;
    if_en = 0; pc_write = 0; flush = 0;
    jump_target = 0; branch_target = 0; pc_sel = 2'b00;

    repeat (2) step();
    check_pc("reset", 32'h0);

    // release reset, enable fetch
    @(negedge clk);
    rst_n_pc = 1; rst_n_if = 1; if_en = 1; pc_write = 1;

    // sequential fetch
    exp_pc = 32'h0;
    repeat (4) begin
      step(); exp_pc += 4;
      check_pc("sequential", exp_pc);
    end

    // jump
    @(negedge clk); jump_target = 32'h20; pc_sel = 2'b01;
    step(); check_pc("jump", 32'h20);

    // back to PC+4
    @(negedge clk); pc_sel = 2'b00;
    step(); check_pc("pc+4 after jump", 32'h24);

    // branch
    @(negedge clk); branch_target = 32'h40; pc_sel = 2'b10;
    step(); check_pc("branch", 32'h40);

    @(negedge clk); pc_sel = 2'b00;
    step(); check_pc("pc+4 after branch", 32'h44);

    // stall: PC must hold
    @(negedge clk); pc_write = 0;
    repeat (3) begin step(); check_pc("stall", 32'h44); end
    @(negedge clk); pc_write = 1;
    step(); check_pc("resume after stall", 32'h48);

    // mid-run reset
    @(negedge clk); rst_n_pc = 0;
    step(); check_pc("mid-run reset", 32'h0);

    if (errors == 0) $display("IF stage: ALL PASS");
    else             $display("IF stage: %0d FAILURES", errors);
    $finish;
  end

  initial begin $dumpfile("if_tb.vcd"); $dumpvars(0, if_tb); end
endmodule