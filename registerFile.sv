module regfile (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        we,
    input  logic [4:0]  rs1, rs2, rd,
    input  logic [31:0] data2write,
    output logic [31:0] rd1, rd2
);

    // outputs of the 32 registers
    logic [31:0] regs [32];

    // x0: hardwired to zero, no reg32 instance
    assign regs[0] = 32'd0;

    // x1..x31: one reg32 each
    for (genvar i = 1; i < 32; i++) begin : gen_regs
        reg32 u_reg (
            .clk         (clk),
            .rst         (rst_n),
            .we          (we && (rd == i)),
            .data        (data2write),
            .stored_data (regs[i])
        );
    end

    // read muxes
    assign rd1 = regs[rs1];
    assign rd2 = regs[rs2];

endmodule