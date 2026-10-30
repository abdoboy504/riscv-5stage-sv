`timescale 1ns/1ps

// Directed testbench: loads a small program into imem, resets the core,
// runs a fixed number of cycles, then checks registers / data memory.
module core_tb;

    // ------------------------------------------------------------
    // CHANGE THESE if your hierarchy / array names differ
    // ------------------------------------------------------------
    `define IMEM   dut.u_if.instruction_memory.mem      // imem's internal array (name is a guess)
    `define DMEM   dut.u_mem.u_dmem.mem
    `define REG(i) dut.u_id.u_regfile.regs[i]
    localparam int IMEM_DEPTH = 256;                    // words to clear in imem
    localparam int DMEM_DEPTH = 1024;

    // ------------------------------------------------------------
    // DUT + clock
    // ------------------------------------------------------------
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic illegal_instr;

    core dut (.clk(clk), .rst_n(rst_n), .illegal_instr(illegal_instr));

    always #5 clk = ~clk;

    int illegal_seen = 0;
    always @(posedge clk)
        if (rst_n && illegal_instr === 1'b1) illegal_seen++;

    // ------------------------------------------------------------
    // Instruction encoders (so programs read like assembly)
    // ------------------------------------------------------------
    function automatic logic [31:0] ADD  (input int rd, input int rs1, input int rs2);
        return {7'b0000000, rs2[4:0], rs1[4:0], 3'b000, rd[4:0], 7'b0110011};
    endfunction
    function automatic logic [31:0] SUB  (input int rd, input int rs1, input int rs2);
        return {7'b0100000, rs2[4:0], rs1[4:0], 3'b000, rd[4:0], 7'b0110011};
    endfunction
    function automatic logic [31:0] ADDI (input int rd, input int rs1, input int imm);
        return {imm[11:0], rs1[4:0], 3'b000, rd[4:0], 7'b0010011};
    endfunction
    function automatic logic [31:0] LW   (input int rd, input int rs1, input int imm);
        return {imm[11:0], rs1[4:0], 3'b010, rd[4:0], 7'b0000011};
    endfunction
    function automatic logic [31:0] LB   (input int rd, input int rs1, input int imm);
        return {imm[11:0], rs1[4:0], 3'b000, rd[4:0], 7'b0000011};
    endfunction
    function automatic logic [31:0] LBU  (input int rd, input int rs1, input int imm);
        return {imm[11:0], rs1[4:0], 3'b100, rd[4:0], 7'b0000011};
    endfunction
    function automatic logic [31:0] SW   (input int rs2, input int rs1, input int imm);
        return {imm[11:5], rs2[4:0], rs1[4:0], 3'b010, imm[4:0], 7'b0100011};
    endfunction
    function automatic logic [31:0] SB   (input int rs2, input int rs1, input int imm);
        return {imm[11:5], rs2[4:0], rs1[4:0], 3'b000, imm[4:0], 7'b0100011};
    endfunction
    function automatic logic [31:0] BEQ  (input int rs1, input int rs2, input int off);
        return {off[12], off[10:5], rs2[4:0], rs1[4:0], 3'b000, off[4:1], off[11], 7'b1100011};
    endfunction
    function automatic logic [31:0] BNE  (input int rs1, input int rs2, input int off);
        return {off[12], off[10:5], rs2[4:0], rs1[4:0], 3'b001, off[4:1], off[11], 7'b1100011};
    endfunction
    function automatic logic [31:0] LUI  (input int rd, input int imm20);
        return {imm20[19:0], rd[4:0], 7'b0110111};
    endfunction
    function automatic logic [31:0] AUIPC(input int rd, input int imm20);
        return {imm20[19:0], rd[4:0], 7'b0010111};
    endfunction
    function automatic logic [31:0] JAL  (input int rd, input int off);
        return {off[20], off[10:1], off[11], off[19:12], rd[4:0], 7'b1101111};
    endfunction
    function automatic logic [31:0] JALR (input int rd, input int rs1, input int imm);
        return {imm[11:0], rs1[4:0], 3'b000, rd[4:0], 7'b1100111};
    endfunction

    // ------------------------------------------------------------
    // Test infrastructure
    // ------------------------------------------------------------
    int prog_idx;
    int errors = 0;
    int checks = 0;

    // Hold reset, wipe both memories, restart program counter for the loader
    task automatic begin_test(input string name);
        $display("\n--- Test %s ---", name);
        rst_n = 1'b0;
        @(negedge clk);
        for (int i = 0; i < IMEM_DEPTH; i++) `IMEM[i] = ADDI(0, 0, 0);   // NOP
        for (int i = 0; i < DMEM_DEPTH; i++) `DMEM[i] = 32'd0;
        prog_idx = 0;
    endtask

    task automatic emit(input logic [31:0] instr);
        `IMEM[prog_idx] = instr;
        prog_idx++;
    endtask

    // Release reset, run for a number of cycles
    task automatic run(input int cycles);
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        repeat (cycles) @(negedge clk);
    endtask

    task automatic check_reg(input int idx, input logic [31:0] expected);
        checks++;
        if (`REG(idx) !== expected) begin
            errors++;
            $display("  FAIL: x%0d = %h, expected %h", idx, `REG(idx), expected);
        end else begin
            $display("  ok:   x%0d = %h", idx, expected);
        end
    endtask

    task automatic check_mem(input int word_idx, input logic [31:0] expected);
        checks++;
        if (`DMEM[word_idx] !== expected) begin
            errors++;
            $display("  FAIL: dmem[%0d] = %h, expected %h", word_idx, `DMEM[word_idx], expected);
        end else begin
            $display("  ok:   dmem[%0d] = %h", word_idx, expected);
        end
    endtask

    // ------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------
    initial begin
        // ---------- 1. basic ALU, no hazards (NOPs in between) ----------
        begin_test("1: basic ALU");
        emit(ADDI(1, 0, 5));
        emit(ADDI(2, 0, 7));
        emit(ADDI(0, 0, 0));
        emit(ADDI(0, 0, 0));
        emit(ADDI(0, 0, 0));
        emit(ADD (3, 1, 2));
        emit(SUB (4, 2, 1));
        run(25);
        check_reg(0, 32'd0);
        check_reg(1, 32'd5);
        check_reg(2, 32'd7);
        check_reg(3, 32'd12);
        check_reg(4, 32'd2);

        // ---------- 2. forwarding: MEM->EX, WB->EX, WB->ID bypass ----------
        begin_test("2: forwarding");
        emit(ADDI(1, 0, 10));
        emit(ADDI(2, 1, 5));      // x1 from MEM          -> 15
        emit(ADD (3, 2, 1));      // x2 from MEM, x1 WB   -> 25
        emit(SUB (4, 3, 1));      // x3 from MEM, x1 via regfile bypass -> 15
        run(25);
        check_reg(1, 32'd10);
        check_reg(2, 32'd15);
        check_reg(3, 32'd25);
        check_reg(4, 32'd15);

        // ---------- 3. store-data forwarding + load-use stall ----------
        begin_test("3: store / load / load-use stall");
        emit(ADDI(1, 0, 99));
        emit(SW  (1, 0, 0));      // store data x1 forwarded from MEM
        emit(LW  (2, 0, 0));
        emit(ADDI(3, 2, 1));      // load-use: needs a 1-cycle stall -> 100
        run(25);
        check_mem(0, 32'd99);
        check_reg(2, 32'd99);
        check_reg(3, 32'd100);

        // ---------- 4. branches: taken (flush) and not taken ----------
        begin_test("4: branches");
        emit(ADDI(1, 0, 1));      // idx 0
        emit(ADDI(2, 0, 1));      // idx 1
        emit(BEQ (1, 2, 12));     // idx 2: taken -> idx 5 (operands forwarded)
        emit(ADDI(3, 0, 111));    // idx 3: wrong path, must be flushed
        emit(ADDI(4, 0, 222));    // idx 4: wrong path, must be flushed
        emit(ADDI(5, 0, 5));      // idx 5: branch target
        emit(BNE (1, 2, 12));     // idx 6: not taken
        emit(ADDI(6, 0, 6));      // idx 7: must execute
        run(30);
        check_reg(3, 32'd0);
        check_reg(4, 32'd0);
        check_reg(5, 32'd5);
        check_reg(6, 32'd6);

        // ---------- 5. JAL and JALR ----------
        begin_test("5: JAL / JALR");
        emit(JAL (1, 8));         // idx 0: -> idx 2, x1 = 4
        emit(ADDI(2, 0, 77));     // idx 1: skipped
        emit(ADDI(3, 0, 3));      // idx 2
        emit(ADDI(4, 0, 28));     // idx 3: x4 = address of idx 7
        emit(JALR(5, 4, 0));      // idx 4: -> idx 7, x5 = 20
        emit(ADDI(6, 0, 66));     // idx 5: skipped
        emit(ADDI(6, 0, 66));     // idx 6: skipped
        emit(ADDI(7, 0, 7));      // idx 7
        run(30);
        check_reg(1, 32'd4);
        check_reg(2, 32'd0);
        check_reg(3, 32'd3);
        check_reg(4, 32'd28);
        check_reg(5, 32'd20);
        check_reg(6, 32'd0);
        check_reg(7, 32'd7);

        // ---------- 6. LUI / AUIPC (+ forwarding of the upper immediate) ----------
        begin_test("6: LUI / AUIPC");
        emit(LUI  (1, 32'h12345));
        emit(ADD  (3, 1, 0));     // x1 forwarded from MEM (LUI value)
        emit(AUIPC(2, 1));        // idx 2 -> pc = 8, x2 = 0x1000 + 8
        run(25);
        check_reg(1, 32'h12345000);
        check_reg(3, 32'h12345000);
        check_reg(2, 32'h00001008);

        // ---------- 7. byte store / sign- and zero-extended loads ----------
        begin_test("7: byte access");
        emit(ADDI(1, 0, 32'h85));
        emit(SB  (1, 0, 1));      // byte 1 of word 0 = 0x85
        emit(LB  (2, 0, 1));      // sign-extended
        emit(LBU (3, 0, 1));      // zero-extended
        emit(LW  (4, 0, 0));      // whole word
        run(30);
        check_mem(0, 32'h00008500);
        check_reg(2, 32'hFFFFFF85);
        check_reg(3, 32'h00000085);
        check_reg(4, 32'h00008500);

        // ---------- summary ----------
        $display("\n==============================");
        if (illegal_seen != 0)
            $display("note: illegal_instr was high for %0d cycles", illegal_seen);
        if (errors == 0) $display("ALL %0d CHECKS PASSED", checks);
        else             $display("%0d of %0d CHECKS FAILED", errors, checks);
        $display("==============================");
        $finish;
    end

endmodule