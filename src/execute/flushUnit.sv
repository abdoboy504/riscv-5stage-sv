// Flush unit (combinational), assumes branches/jumps are resolved in EX.
// When EX redirects the PC, the two instructions behind it (in ID and IF/ID)
// were fetched from the wrong path and must be turned into NOPs.
module flush_unit (
    input  logic ex_branch,     // instruction in EX is a conditional branch
    input  logic cmp_true,      // branch comparator result (condition met)
    input  logic ex_jal,        // instruction in EX is JAL
    input  logic ex_jalr,       // instruction in EX is JALR

    output logic pc_redirect,   // 1 = PC takes the target from EX
    output logic flush_if_id,   // turn the instruction in IF/ID into a NOP
    output logic flush_id_ex    // turn the instruction in ID/EX into a bubble
);

    assign pc_redirect  = (ex_branch && cmp_true) || ex_jal || ex_jalr;

    assign flush_if_id  = pc_redirect;
    assign flush_id_ex  = pc_redirect;

endmodule