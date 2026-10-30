// Data memory: 4 KB, byte-addressed, little-endian,
// per-byte write enables, asynchronous (combinational) read.
module dmem (
    input  logic        clk,
    input  logic [3:0]  we,       // one enable per byte lane
    input  logic [31:0] addr,     // byte address
    input  logic [31:0] wdata,    // already aligned to the byte lanes
    output logic [31:0] rdata     // full aligned word at addr[11:2]
);
 
    logic [31:0] mem [0:1023];
    logic [9:0]  word_idx;
 
    assign word_idx = addr[11:2];
 
    initial begin
        for (int i = 0; i < 1024; i++) mem[i] = 32'd0;
    end
 
    always_ff @(posedge clk) begin
        for (int b = 0; b < 4; b++)
            if (we[b]) mem[word_idx][8*b +: 8] <= wdata[8*b +: 8];
    end
 
    assign rdata = mem[word_idx];
 
endmodule
 