// MEM/WB pipeline register. Reset value is all zeros = NOP.
module mem_wb
import riscv_pkg::*;
(
    input  logic    clk, rst_n,
    input  mem_wb_t in,
    output mem_wb_t out
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) out <= '0;
        else        out <= in;
    end
endmodule


// MEM stage: store alignment, data memory, load alignment/extension, MEM/WB register
module memory_stage
import riscv_pkg::*;
(
    input  logic    clk, rst_n,
    input  ex_mem_t mem_in,         // from EX/MEM register
    output mem_wb_t mem_wb_out      // to WB
);

    logic [1:0] offset;
    assign offset = mem_in.alu_result[1:0];

    // ---------------- store alignment ----------------
    logic [3:0]  byte_we;
    logic [31:0] store_word;

    always_comb begin
        byte_we    = 4'b0000;
        store_word = mem_in.store_data;

        if (mem_in.mem_write) begin
            case (mem_in.mem_width)
                2'b00: begin    // SB: replicate the byte, enable one lane
                    store_word = {4{mem_in.store_data[7:0]}};
                    byte_we    = 4'b0001 << offset;
                end
                2'b01: begin    // SH: replicate the halfword, enable two lanes
                    store_word = {2{mem_in.store_data[15:0]}};
                    byte_we    = offset[1] ? 4'b1100 : 4'b0011;
                end
                default: begin  // SW
                    store_word = mem_in.store_data;
                    byte_we    = 4'b1111;
                end
            endcase
        end
    end

    // ---------------- data memory ----------------
    logic [31:0] raw_word;

    dmem u_dmem (
        .clk   (clk),
        .we    (byte_we),
        .addr  (mem_in.alu_result),
        .wdata (store_word),
        .rdata (raw_word)
    );

    // ---------------- load alignment + extension ----------------
    logic [31:0] shifted;
    logic [31:0] load_data;

    assign shifted = raw_word >> {offset, 3'b000};   // offset * 8

    always_comb begin
        case (mem_in.mem_width)
            2'b00:   load_data = mem_in.load_unsigned ? {24'b0, shifted[7:0]}
                                                      : {{24{shifted[7]}}, shifted[7:0]};
            2'b01:   load_data = mem_in.load_unsigned ? {16'b0, shifted[15:0]}
                                                      : {{16{shifted[15]}}, shifted[15:0]};
            default: load_data = raw_word;
        endcase
    end

    // ---------------- MEM/WB register ----------------
    mem_wb_t mem_wb_in;

    always_comb begin
        mem_wb_in.load_data  = load_data;
        mem_wb_in.alu_result = mem_in.alu_result;
        mem_wb_in.pc_plus    = mem_in.pc_plus;
        mem_wb_in.imm_val    = mem_in.imm_val;
        mem_wb_in.rd         = mem_in.rd;
        mem_wb_in.reg_write  = mem_in.reg_write;
        mem_wb_in.wb_sel     = mem_in.wb_sel;
    end

    mem_wb u_mem_wb (
        .clk   (clk),
        .rst_n (rst_n),
        .in    (mem_wb_in),
        .out   (mem_wb_out)
    );

endmodule


// WB stage: pure combinational select of the final write-back value
module writeback
import riscv_pkg::*;
(
    input  mem_wb_t     wb_in,          // from MEM/WB register
    output logic [31:0] wb_data,        // -> regfile (ID) and forwarding (EX)
    output logic [4:0]  wb_rd,
    output logic        wb_reg_write
);

    always_comb begin
        case (wb_in.wb_sel)
            WB_MEM:       wb_data = wb_in.load_data;
            WB_UPPER_IMM: wb_data = wb_in.imm_val;
            WB_PC4:       wb_data = wb_in.pc_plus;
            default:      wb_data = wb_in.alu_result;
        endcase
    end

    assign wb_rd        = wb_in.rd;
    assign wb_reg_write = wb_in.reg_write;

endmodule