module PC(
    input logic clk,rst_n,
    input logic pc_write, 
    input logic [31:0] next_inst,
    output logic [31:0] pc_out
);

always_ff @( posedge clk  or negedge rst_n) begin : dataa
if(rst_n == 0 )
begin
   pc_out <= 32'd0;
end
else if(pc_write == 1)
begin
    pc_out <=  next_inst;
end
end
endmodule