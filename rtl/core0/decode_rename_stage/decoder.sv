//============================================================
// Module: decoder
//
// Description:
// Main RV64GC instruction decoder.
//
// This module decodes a 32-bit RISC-V instruction and
// generates architectural control signals used by the
// rename, dispatch, execute, memory, and commit stages.
//
// Supported ISA:
//   - RV64I
//   - M Extension
//   - A Extension
//   - F Extension (decode only)
//   - D Extension (decode only)
//   - Zicsr
//   - Zifencei
//
// Notes:
//   - Compressed (C) instructions are NOT decoded here.
//   - All C instructions must first pass through
//     compressed_decoder.sv and be expanded into a
//     canonical 32-bit instruction.
//
// Reference:
//   RISC-V Unprivileged ISA Specification
//   Volume I
//============================================================

`timescale 1ns/1ps

import riscv_types_pkg::*;

module decoder (
    input  logic [31:0] instr,
    output decoded_instr_t decoded
);

    opcode_e    opcode;
    arch_reg_t  rd;
    arch_reg_t  rs1;
    arch_reg_t  rs2;
    logic [2:0] funct3;
    logic [6:0] funct7;

    always_comb begin
        opcode = opcode_e'(instr[6:0]);
        rd     = instr[11:7];
        funct3 = instr[14:12];
        rs1    = instr[19:15];
        rs2    = instr[24:20];
        funct7 = instr[31:25];

        decoded = '0;

        decoded.valid  = 1'b1;
        decoded.instr  = instr;

        decoded.opcode = opcode;
        decoded.rd     = rd;
        decoded.rs1    = rs1;
        decoded.rs2    = rs2;
        decoded.funct3 = funct3;
        decoded.funct7 = funct7;

        decoded.format   = FMT_UNKNOWN;
        decoded.imm_type = IMM_NONE;

        decoded.alu_op    = ALU_NONE;
        decoded.branch_op = BR_NONE;
        decoded.load_op   = LOAD_NONE;
        decoded.store_op  = STORE_NONE;
        decoded.csr_op    = CSR_NONE;
        decoded.amo_op    = AMO_NONE;

        decoded.illegal = 1'b0;

        case (opcode)

            OPCODE_LUI: begin
                decoded.format    = FMT_U;
                decoded.imm_type  = IMM_U;
                decoded.alu_op    = ALU_COPY_B;
                decoded.writes_rd = (rd != '0);
            end

            OPCODE_AUIPC: begin
                decoded.format    = FMT_U;
                decoded.imm_type  = IMM_U;
                decoded.alu_op    = ALU_ADD;
                decoded.writes_rd = (rd != '0);
            end

            OPCODE_JAL: begin
                decoded.format    = FMT_J;
                decoded.imm_type  = IMM_J;
                decoded.branch_op = BR_JAL;
                decoded.is_jump   = 1'b1;
                decoded.writes_rd = (rd != '0);
            end

            OPCODE_JALR: begin
                decoded.format    = FMT_I;
                decoded.imm_type  = IMM_I;
                decoded.branch_op = BR_JALR;
                decoded.uses_rs1  = 1'b1;
                decoded.is_jump   = 1'b1;
                decoded.writes_rd = (rd != '0);

                if (funct3 != 3'b000)
                    decoded.illegal = 1'b1;
            end

            OPCODE_BRANCH: begin
                decoded.format    = FMT_B;
                decoded.imm_type  = IMM_B;
                decoded.uses_rs1  = 1'b1;
                decoded.uses_rs2  = 1'b1;
                decoded.is_branch = 1'b1;

                case (funct3)
                    3'b000: decoded.branch_op = BR_BEQ;
                    3'b001: decoded.branch_op = BR_BNE;
                    3'b100: decoded.branch_op = BR_BLT;
                    3'b101: decoded.branch_op = BR_BGE;
                    3'b110: decoded.branch_op = BR_BLTU;
                    3'b111: decoded.branch_op = BR_BGEU;
                    default: decoded.illegal = 1'b1;
                endcase
            end

            OPCODE_LOAD: begin
                decoded.format    = FMT_I;
                decoded.imm_type  = IMM_I;
                decoded.uses_rs1  = 1'b1;
                decoded.writes_rd = (rd != '0);
                decoded.is_load   = 1'b1;
                decoded.alu_op    = ALU_ADD;

                case (funct3)
                    3'b000: decoded.load_op = LOAD_LB;
                    3'b001: decoded.load_op = LOAD_LH;
                    3'b010: decoded.load_op = LOAD_LW;
                    3'b011: decoded.load_op = LOAD_LD;
                    3'b100: decoded.load_op = LOAD_LBU;
                    3'b101: decoded.load_op = LOAD_LHU;
                    3'b110: decoded.load_op = LOAD_LWU;
                    default: decoded.illegal = 1'b1;
                endcase
            end

            OPCODE_STORE: begin
                decoded.format    = FMT_S;
                decoded.imm_type  = IMM_S;
                decoded.uses_rs1  = 1'b1;
                decoded.uses_rs2  = 1'b1;
                decoded.is_store  = 1'b1;
                decoded.alu_op    = ALU_ADD;

                case (funct3)
                    3'b000: decoded.store_op = STORE_SB;
                    3'b001: decoded.store_op = STORE_SH;
                    3'b010: decoded.store_op = STORE_SW;
                    3'b011: decoded.store_op = STORE_SD;
                    default: decoded.illegal = 1'b1;
                endcase
            end

            OPCODE_OP_IMM: begin
                decoded.format    = FMT_I;
                decoded.imm_type  = IMM_I;
                decoded.uses_rs1  = 1'b1;
                decoded.writes_rd = (rd != '0);

                case (funct3)
                    3'b000: decoded.alu_op = ALU_ADD;   // ADDI
                    3'b010: decoded.alu_op = ALU_SLT;   // SLTI
                    3'b011: decoded.alu_op = ALU_SLTU;  // SLTIU
                    3'b100: decoded.alu_op = ALU_XOR;   // XORI
                    3'b110: decoded.alu_op = ALU_OR;    // ORI
                    3'b111: decoded.alu_op = ALU_AND;   // ANDI

                    3'b001: begin                        // SLLI
                        decoded.alu_op = ALU_SLL;
                        if (funct7 != 7'b0000000)
                            decoded.illegal = 1'b1;
                    end

                    3'b101: begin
                        case (funct7)
                            7'b0000000: decoded.alu_op = ALU_SRL; // SRLI
                            7'b0100000: decoded.alu_op = ALU_SRA; // SRAI
                            default:    decoded.illegal = 1'b1;
                        endcase
                    end

                    default: decoded.illegal = 1'b1;
                endcase
            end

            OPCODE_OP: begin
                decoded.format    = FMT_R;
                decoded.uses_rs1  = 1'b1;
                decoded.uses_rs2  = 1'b1;
                decoded.writes_rd = (rd != '0);

                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: decoded.alu_op = ALU_ADD;
                    {7'b0100000, 3'b000}: decoded.alu_op = ALU_SUB;
                    {7'b0000000, 3'b001}: decoded.alu_op = ALU_SLL;
                    {7'b0000000, 3'b010}: decoded.alu_op = ALU_SLT;
                    {7'b0000000, 3'b011}: decoded.alu_op = ALU_SLTU;
                    {7'b0000000, 3'b100}: decoded.alu_op = ALU_XOR;
                    {7'b0000000, 3'b101}: decoded.alu_op = ALU_SRL;
                    {7'b0100000, 3'b101}: decoded.alu_op = ALU_SRA;
                    {7'b0000000, 3'b110}: decoded.alu_op = ALU_OR;
                    {7'b0000000, 3'b111}: decoded.alu_op = ALU_AND;

                    // M extension
                    {7'b0000001, 3'b000}: begin decoded.is_mul_div = 1'b1; decoded.alu_op = ALU_NONE; end // MUL
                    {7'b0000001, 3'b001}: begin decoded.is_mul_div = 1'b1; decoded.alu_op = ALU_NONE; end // MULH
                    {7'b0000001, 3'b010}: begin decoded.is_mul_div = 1'b1; decoded.alu_op = ALU_NONE; end // MULHSU
                    {7'b0000001, 3'b011}: begin decoded.is_mul_div = 1'b1; decoded.alu_op = ALU_NONE; end // MULHU
                    {7'b0000001, 3'b100}: begin decoded.is_mul_div = 1'b1; decoded.alu_op = ALU_NONE; end // DIV
                    {7'b0000001, 3'b101}: begin decoded.is_mul_div = 1'b1; decoded.alu_op = ALU_NONE; end // DIVU
                    {7'b0000001, 3'b110}: begin decoded.is_mul_div = 1'b1; decoded.alu_op = ALU_NONE; end // REM
                    {7'b0000001, 3'b111}: begin decoded.is_mul_div = 1'b1; decoded.alu_op = ALU_NONE; end // REMU

                    default: decoded.illegal = 1'b1;
                endcase
            end

            OPCODE_OP_IMM_32: begin
                decoded.format    = FMT_I;
                decoded.imm_type  = IMM_I;
                decoded.uses_rs1  = 1'b1;
                decoded.writes_rd = (rd != '0);

                case (funct3)
                    3'b000: decoded.alu_op = ALU_ADDW; // ADDIW

                    3'b001: begin
                        decoded.alu_op = ALU_SLLW;     // SLLIW
                        if (funct7 != 7'b0000000)
                            decoded.illegal = 1'b1;
                    end

                    3'b101: begin
                        case (funct7)
                            7'b0000000: decoded.alu_op = ALU_SRLW; // SRLIW
                            7'b0100000: decoded.alu_op = ALU_SRAW; // SRAIW
                            default:    decoded.illegal = 1'b1;
                        endcase
                    end

                    default: decoded.illegal = 1'b1;
                endcase
            end

            OPCODE_OP_32: begin
                decoded.format    = FMT_R;
                decoded.uses_rs1  = 1'b1;
                decoded.uses_rs2  = 1'b1;
                decoded.writes_rd = (rd != '0);

                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: decoded.alu_op = ALU_ADDW;
                    {7'b0100000, 3'b000}: decoded.alu_op = ALU_SUBW;
                    {7'b0000000, 3'b001}: decoded.alu_op = ALU_SLLW;
                    {7'b0000000, 3'b101}: decoded.alu_op = ALU_SRLW;
                    {7'b0100000, 3'b101}: decoded.alu_op = ALU_SRAW;

                    // M extension word ops
                    {7'b0000001, 3'b000}: begin decoded.is_mul_div = 1'b1; decoded.alu_op = ALU_NONE; end // MULW
                    {7'b0000001, 3'b100}: begin decoded.is_mul_div = 1'b1; decoded.alu_op = ALU_NONE; end // DIVW
                    {7'b0000001, 3'b101}: begin decoded.is_mul_div = 1'b1; decoded.alu_op = ALU_NONE; end // DIVUW
                    {7'b0000001, 3'b110}: begin decoded.is_mul_div = 1'b1; decoded.alu_op = ALU_NONE; end // REMW
                    {7'b0000001, 3'b111}: begin decoded.is_mul_div = 1'b1; decoded.alu_op = ALU_NONE; end // REMUW

                    default: decoded.illegal = 1'b1;
                endcase
            end

            OPCODE_MISC_MEM: begin
                decoded.format = FMT_I;

                case (funct3)
                    3'b000: decoded.is_fence   = 1'b1; // FENCE
                    3'b001: decoded.is_fence_i = 1'b1; // FENCE.I
                    default: decoded.illegal    = 1'b1;
                endcase
            end

            OPCODE_SYSTEM: begin
                decoded.format = FMT_SYSTEM;

                case (funct3)
                    3'b000: begin
                        case (instr[31:20])
                            12'h000: decoded.is_ecall  = 1'b1;
                            12'h001: decoded.is_ebreak = 1'b1;
                            12'h102: decoded.is_sret   = 1'b1;
                            12'h302: decoded.is_mret   = 1'b1;
                            12'h105: decoded.is_wfi    = 1'b1;
                            default: decoded.illegal   = 1'b1;
                        endcase
                    end

                    3'b001: begin decoded.is_csr = 1'b1; decoded.csr_op = CSR_RW;  decoded.uses_rs1 = 1'b1; decoded.writes_rd = (rd != '0); decoded.imm_type = IMM_CSR; end
                    3'b010: begin decoded.is_csr = 1'b1; decoded.csr_op = CSR_RS;  decoded.uses_rs1 = 1'b1; decoded.writes_rd = (rd != '0); decoded.imm_type = IMM_CSR; end
                    3'b011: begin decoded.is_csr = 1'b1; decoded.csr_op = CSR_RC;  decoded.uses_rs1 = 1'b1; decoded.writes_rd = (rd != '0); decoded.imm_type = IMM_CSR; end
                    3'b101: begin decoded.is_csr = 1'b1; decoded.csr_op = CSR_RWI; decoded.writes_rd = (rd != '0); decoded.imm_type = IMM_CSR; end
                    3'b110: begin decoded.is_csr = 1'b1; decoded.csr_op = CSR_RSI; decoded.writes_rd = (rd != '0); decoded.imm_type = IMM_CSR; end
                    3'b111: begin decoded.is_csr = 1'b1; decoded.csr_op = CSR_RCI; decoded.writes_rd = (rd != '0); decoded.imm_type = IMM_CSR; end

                    default: decoded.illegal = 1'b1;
                endcase
            end

            OPCODE_AMO: begin
                decoded.format   = FMT_R;
                decoded.uses_rs1 = 1'b1;
                decoded.uses_rs2 = 1'b1;
                decoded.writes_rd = (rd != '0);
                decoded.is_amo   = 1'b1;

                case (instr[31:27])
                    5'b00010: decoded.amo_op = AMO_LR;
                    5'b00011: decoded.amo_op = AMO_SC;
                    5'b00001: decoded.amo_op = AMO_SWAP;
                    5'b00000: decoded.amo_op = AMO_ADD;
                    5'b00100: decoded.amo_op = AMO_XOR;
                    5'b01100: decoded.amo_op = AMO_AND;
                    5'b01000: decoded.amo_op = AMO_OR;
                    5'b10000: decoded.amo_op = AMO_MIN;
                    5'b10100: decoded.amo_op = AMO_MAX;
                    5'b11000: decoded.amo_op = AMO_MINU;
                    5'b11100: decoded.amo_op = AMO_MAXU;
                    default:  decoded.illegal = 1'b1;
                endcase

                if (!((funct3 == 3'b010) || (funct3 == 3'b011)))
                    decoded.illegal = 1'b1;

                if ((decoded.amo_op == AMO_LR) && (rs2 != '0))
                    decoded.illegal = 1'b1;
            end

            OPCODE_LOAD_FP: begin
                decoded.is_fp = 1'b1;
                decoded.format = FMT_I;
                decoded.imm_type = IMM_I;
                decoded.uses_rs1 = 1'b1;
                decoded.writes_rd = (rd != '0);
                decoded.is_load = 1'b1;
                decoded.alu_op = ALU_ADD;

                if (!((funct3 == 3'b010) || (funct3 == 3'b011)))
                    decoded.illegal = 1'b1;
            end

            OPCODE_STORE_FP: begin
                decoded.is_fp = 1'b1;
                decoded.format = FMT_S;
                decoded.imm_type = IMM_S;
                decoded.uses_rs1 = 1'b1;
                decoded.uses_rs2 = 1'b1;
                decoded.is_store = 1'b1;
                decoded.alu_op = ALU_ADD;

                if (!((funct3 == 3'b010) || (funct3 == 3'b011)))
                    decoded.illegal = 1'b1;
            end

            OPCODE_MADD,
            OPCODE_MSUB,
            OPCODE_NMSUB,
            OPCODE_NMADD: begin
                decoded.is_fp = 1'b1;
                decoded.format = FMT_R;
                decoded.uses_rs1 = 1'b1;
                decoded.uses_rs2 = 1'b1;
                decoded.writes_rd = (rd != '0);

                if (!((instr[26:25] == 2'b00) || (instr[26:25] == 2'b01)))
                    decoded.illegal = 1'b1;

                if ((funct3 == 3'b101) || (funct3 == 3'b110))
                    decoded.illegal = 1'b1;
            end

            OPCODE_OP_FP: begin
                decoded.is_fp = 1'b1;
                decoded.format = FMT_R;
                decoded.uses_rs1 = 1'b1;
                decoded.uses_rs2 = 1'b1;
                decoded.writes_rd = (rd != '0);

                case (funct7)
                    7'b0000000, 7'b0000001, // FADD.S/D
                    7'b0000100, 7'b0000101, // FSUB.S/D
                    7'b0001000, 7'b0001001, // FMUL.S/D
                    7'b0001100, 7'b0001101: begin // FDIV.S/D
                        if ((funct3 == 3'b101) || (funct3 == 3'b110))
                            decoded.illegal = 1'b1;
                    end

                    7'b0101100, 7'b0101101: begin // FSQRT.S/D
                        decoded.uses_rs2 = 1'b0;
                        if ((rs2 != '0) || (funct3 == 3'b101) || (funct3 == 3'b110))
                            decoded.illegal = 1'b1;
                    end

                    7'b0010000, 7'b0010001: begin // FSGNJ.S/D
                        if (funct3[2] || (funct3 == 3'b011))
                            decoded.illegal = 1'b1;
                    end

                    7'b0010100, 7'b0010101: begin // FMIN/FMAX.S/D
                        if (funct3[2] || funct3[1])
                            decoded.illegal = 1'b1;
                    end

                    7'b1010000, 7'b1010001: begin // FEQ/FLT/FLE.S/D
                        if (!((funct3 == 3'b000) || (funct3 == 3'b001) || (funct3 == 3'b010)))
                            decoded.illegal = 1'b1;
                    end

                    7'b1100000, 7'b1100001, // FCVT.W[U]/L[U].S/D
                    7'b1101000, 7'b1101001: begin // FCVT.S/D.W[U]/L[U]
                        decoded.uses_rs2 = 1'b0;
                        if ((rs2[4:2] != 3'b000) || (funct3 == 3'b101) || (funct3 == 3'b110))
                            decoded.illegal = 1'b1;
                    end

                    7'b0100000, 7'b0100001: begin // FCVT.S.D / FCVT.D.S
                        decoded.uses_rs2 = 1'b0;
                        if ((rs2 != {4'b0000, ~funct7[0]}) ||
                            (funct3 == 3'b101) || (funct3 == 3'b110))
                            decoded.illegal = 1'b1;
                    end

                    7'b1110000, 7'b1110001: begin // FMV.X.W/D, FCLASS.S/D
                        decoded.uses_rs2 = 1'b0;
                        if ((rs2 != '0) || !((funct3 == 3'b000) || (funct3 == 3'b001)))
                            decoded.illegal = 1'b1;
                    end

                    7'b1111000, 7'b1111001: begin // FMV.W/D.X
                        decoded.uses_rs2 = 1'b0;
                        if ((rs2 != '0) || (funct3 != 3'b000))
                            decoded.illegal = 1'b1;
                    end

                    default: decoded.illegal = 1'b1;
                endcase
            end

            default: begin
                decoded.illegal = 1'b1;
            end

        endcase
    end

endmodule
