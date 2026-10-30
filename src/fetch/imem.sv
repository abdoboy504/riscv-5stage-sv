module imem #(
    parameter WORDS = 1024,
    parameter INIT  = "program.hex"
)(
    input  logic [31:0] addr,
    output logic [31:0] instr
);

    logic [31:0] mem [0:WORDS-1];

    initial $readmemh(INIT, mem);

    assign instr = mem[addr[$clog2(WORDS)+1:2]];

endmodule