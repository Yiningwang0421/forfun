`timescale 1ns/1ps

import riscv_types_pkg::*;

module immediate_generator #(
    parameter int DATA_W = XLEN
)(
    input  logic [31:0] instr,
    input  imm_type_e imm_type,
    output logic [DATA_W-1:0] imm
);

    always_comb begin
        case (imm_type)

            IMM_I: begin
                imm = {{(DATA_W-12){instr[31]}}, instr[31:20]};
            end

            IMM_S: begin
                imm = {{(DATA_W-12){instr[31]}}, instr[31:25], instr[11:7]};
            end

            IMM_B: begin
                imm = {{(DATA_W-13){instr[31]}},
                       instr[31],
                       instr[7],
                       instr[30:25],
                       instr[11:8],
                       1'b0};
            end

            IMM_U: begin
                imm = {{(DATA_W-32){instr[31]}}, instr[31:12], 12'b0};
            end

            IMM_J: begin
                imm = {{(DATA_W-21){instr[31]}},
                       instr[31],
                       instr[19:12],
                       instr[20],
                       instr[30:21],
                       1'b0};
            end

            IMM_CSR: begin
                imm = {{(DATA_W-5){1'b0}}, instr[19:15]};
            end

            default: begin
                imm = '0;
            end

        endcase
    end

endmodule