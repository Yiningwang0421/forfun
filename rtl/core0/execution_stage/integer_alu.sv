`timescale 1ns/1ps

import riscv_types_pkg::*;

module integer_alu #(
    parameter int DATA_W = XLEN
)(
    input  logic [DATA_W-1:0] operand_a,
    input  logic [DATA_W-1:0] operand_b,
    input  alu_op_e           alu_op,

    output logic [DATA_W-1:0] result
);

    logic [5:0] shamt64;
    logic [4:0] shamt32;

    logic [31:0] word_a;
    logic [31:0] word_b;
    logic [31:0] word_result;

    assign shamt64 = operand_b[5:0];
    assign shamt32 = operand_b[4:0];

    assign word_a = operand_a[31:0];
    assign word_b = operand_b[31:0];

    always_comb begin
        result      = '0;
        word_result = '0;

        case (alu_op)

            ALU_ADD: begin
                result = operand_a + operand_b;
            end

            ALU_SUB: begin
                result = operand_a - operand_b;
            end

            ALU_AND: begin
                result = operand_a & operand_b;
            end

            ALU_OR: begin
                result = operand_a | operand_b;
            end

            ALU_XOR: begin
                result = operand_a ^ operand_b;
            end

            ALU_SLL: begin
                result = operand_a << shamt64;
            end

            ALU_SRL: begin
                result = operand_a >> shamt64;
            end

            ALU_SRA: begin
                result = $signed(operand_a) >>> shamt64;
            end

            ALU_SLT: begin
                result = ($signed(operand_a) < $signed(operand_b)) ? {{(DATA_W-1){1'b0}}, 1'b1} : '0;
            end

            ALU_SLTU: begin
                result = (operand_a < operand_b) ? {{(DATA_W-1){1'b0}}, 1'b1} : '0;
            end

            ALU_ADDW: begin
                word_result = word_a + word_b;
                result = {{(DATA_W-32){word_result[31]}}, word_result};
            end

            ALU_SUBW: begin
                word_result = word_a - word_b;
                result = {{(DATA_W-32){word_result[31]}}, word_result};
            end

            ALU_SLLW: begin
                word_result = word_a << shamt32;
                result = {{(DATA_W-32){word_result[31]}}, word_result};
            end

            ALU_SRLW: begin
                word_result = word_a >> shamt32;
                result = {{(DATA_W-32){word_result[31]}}, word_result};
            end

            ALU_SRAW: begin
                word_result = $signed(word_a) >>> shamt32;
                result = {{(DATA_W-32){word_result[31]}}, word_result};
            end

            ALU_COPY_A: begin
                result = operand_a;
            end

            ALU_COPY_B: begin
                result = operand_b;
            end

            default: begin
                result = '0;
            end

        endcase
    end

endmodule
