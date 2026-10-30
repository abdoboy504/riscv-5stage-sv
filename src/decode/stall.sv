// Load-use stall unit (combinational)
// stall = 1 when the instruction in EX is a load whose destination
// is a source register of the instruction currently in ID.
//
// Wire `stall` to:
//   - PC register      : hold
//   - IF/ID register   : hold
//   - ID/EX register   : insert bubble (zero side-effect controls)
module stall_unit (
    input  logic [4:0] id_rs1,
    input  logic [4:0] id_rs2,

    input  logic [4:0] ex_rd,
    input  logic       ex_mem_read,   // 1 = instruction in EX is a load

    output logic       stall
);

    assign stall = ex_mem_read
                && (ex_rd != 5'd0)
                && ((ex_rd == id_rs1) || (ex_rd == id_rs2));

endmodule