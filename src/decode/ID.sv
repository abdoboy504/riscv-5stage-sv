// ID/EX pipeline register. Reset value is all zeros = NOP.
module id_ex
import riscv_pkg::*;
(
    input  logic    clk, rst_n,
    input  id_ex_t  in,
    output id_ex_t  out
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) out <= '0;
        else        out <= in;
    end
endmodule


// ID stage: decoder + immediate generator + register file (with WB bypass)
// + load-use stall unit + ID/EX register.
module instrDecode
import riscv_pkg::*;
(
    input  logic        clk, rst_n,
    input  if_id_t      if_out,        // from IF/ID register
    input  logic        flush,         // flush_id_ex from flush_unit (top level)

    // write-back port (from WB stage)
    input  logic        wb_we,
    input  logic [4:0]  wb_addr,
    input  logic [31:0] wb_data,

    output id_ex_t      id_ex_out,     // to EX (and rs1/rs2/rd to forwarding unit)
    output logic        stall,         // to PC, IF/ID enable (top level)
    output logic        illegal_instr
);

    // ---------------- field extraction ----------------
    logic [4:0] rs1_addr, rs2_addr, rd_addr;
    assign rs1_addr = if_out.instr[19:15];
    assign rs2_addr = if_out.instr[24:20];
    assign rd_addr  = if_out.instr[11:7];

    // ---------------- decoder ----------------
    alu_op_t   alu_op;
    logic      alu_src, alu_a_pc;
    imm_sel_t  imm_sel;
    logic      reg_write;
    wb_sel_t   wb_sel;
    logic      mem_read, mem_write;
    logic [1:0] mem_width;
    logic      load_unsigned;
    logic      comp_en;
    comp_op_t  comp_op;
    logic      jump, sig_jalr;

    decoder u_decoder (
        .instr         (if_out.instr),
        .alu_op        (alu_op),
        .alu_src       (alu_src),
        .alu_a_pc      (alu_a_pc),
        .imm_sel       (imm_sel),
        .reg_write     (reg_write),
        .wb_sel        (wb_sel),
        .mem_read      (mem_read),
        .mem_write     (mem_write),
        .mem_width     (mem_width),
        .load_unsigned (load_unsigned),
        .comp_en       (comp_en),
        .comp_op       (comp_op),
        .jump          (jump),
        .sig_jalr      (sig_jalr),
        .illegal_instr (illegal_instr)
    );

    // ---------------- immediate ----------------
    logic [31:0] imm_val;

    immediateGenerator u_imm (
        .imm_sel (imm_sel),
        .instr   (if_out.instr),
        .imm_val (imm_val)
    );

    // ---------------- register file + WB->ID bypass ----------------
    logic [31:0] rf_rd1, rf_rd2, rs1_data, rs2_data;

    regfile u_regfile (
        .clk        (clk),
        .rst_n      (rst_n),
        .we         (wb_we),
        .rs1        (rs1_addr),
        .rs2        (rs2_addr),
        .rd         (wb_addr),
        .data2write (wb_data),
        .rd1        (rf_rd1),
        .rd2        (rf_rd2)
    );

    // The regfile writes on the clock edge, so a read in the same cycle as
    // the write returns the old value. Bypass the WB data instead.
    assign rs1_data = (wb_we && wb_addr != 5'd0 && wb_addr == rs1_addr) ? wb_data : rf_rd1;
    assign rs2_data = (wb_we && wb_addr != 5'd0 && wb_addr == rs2_addr) ? wb_data : rf_rd2;

    // ---------------- stall unit (uses ID/EX output = instruction in EX) ----------------
    stall_unit u_stall (
        .id_rs1      (rs1_addr),
        .id_rs2      (rs2_addr),
        .ex_rd       (id_ex_out.rd),
        .ex_mem_read (id_ex_out.mem_read),
        .stall       (stall)
    );

    // ---------------- ID/EX register input ----------------
    logic    bubble;
    id_ex_t  id_ex_in;

    assign bubble = stall | flush;

    always_comb begin
        // data: don't care on a bubble
        id_ex_in.pc_out        = if_out.pc_out;
        id_ex_in.pc_plus       = if_out.pc_plus;
        id_ex_in.rs1_data      = rs1_data;
        id_ex_in.rs2_data      = rs2_data;
        id_ex_in.imm_val       = imm_val;
        id_ex_in.rs1           = rs1_addr;
        id_ex_in.rs2           = rs2_addr;
        id_ex_in.rd            = rd_addr;

        // pure datapath selects: harmless on a bubble
        id_ex_in.alu_op        = alu_op;
        id_ex_in.alu_src       = alu_src;
        id_ex_in.alu_a_pc      = alu_a_pc;
        id_ex_in.comp_op       = comp_op;
        id_ex_in.mem_width     = mem_width;
        id_ex_in.load_unsigned = load_unsigned;
        id_ex_in.wb_sel        = wb_sel;

        // side-effect controls: zeroed on a bubble
        id_ex_in.reg_write     = bubble ? 1'b0 : reg_write;
        id_ex_in.mem_read      = bubble ? 1'b0 : mem_read;
        id_ex_in.mem_write     = bubble ? 1'b0 : mem_write;
        id_ex_in.comp_en       = bubble ? 1'b0 : comp_en;
        id_ex_in.jump          = bubble ? 1'b0 : jump;
        id_ex_in.sig_jalr      = bubble ? 1'b0 : sig_jalr;
    end

    id_ex u_id_ex (
        .clk   (clk),
        .rst_n (rst_n),
        .in    (id_ex_in),
        .out   (id_ex_out)
    );

endmodule