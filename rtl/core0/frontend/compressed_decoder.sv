`timescale 1ns/1ps

//============================================================
// Module: compressed_decoder
//
// Description:
//   RV64C compressed instruction decompressor.
//
//   This module takes a 16-bit RISC-V compressed instruction
//   and expands it into an equivalent canonical 32-bit RISC-V
//   instruction.
//
// Target:
//   RV64GC frontend
//
// Supported:
//   - RV64C integer compressed instructions
//   - RV64C stack-pointer loads/stores
//   - RV64C compressed doubleword loads/stores
//   - RV64C compressed floating-point double loads/stores
//
// Not supported here:
//   - Zcb
//   - Zcmp
//   - Zcmt
//   - custom compressed extensions
//
// Design Rule:
//   compressed_decoder.sv only expands instruction encoding.
//   It does not generate full control signals.
//   The expanded 32-bit instruction goes into decoder.sv.
//
//============================================================

module compressed_decoder (
    input  logic [15:0] cinstr,

    output logic [31:0] instr,
    output logic        is_compressed,
    output logic        illegal
);

    //--------------------------------------------------------
    // 32-bit RISC-V opcodes
    //--------------------------------------------------------

    localparam logic [6:0] OPCODE_LOAD      = 7'b0000011;
    localparam logic [6:0] OPCODE_LOAD_FP   = 7'b0000111;
    localparam logic [6:0] OPCODE_MISC_MEM  = 7'b0001111;
    localparam logic [6:0] OPCODE_OP_IMM    = 7'b0010011;
    localparam logic [6:0] OPCODE_AUIPC     = 7'b0010111;
    localparam logic [6:0] OPCODE_OP_IMM_32 = 7'b0011011;
    localparam logic [6:0] OPCODE_STORE     = 7'b0100011;
    localparam logic [6:0] OPCODE_STORE_FP  = 7'b0100111;
    localparam logic [6:0] OPCODE_OP        = 7'b0110011;
    localparam logic [6:0] OPCODE_LUI       = 7'b0110111;
    localparam logic [6:0] OPCODE_OP_32     = 7'b0111011;
    localparam logic [6:0] OPCODE_BRANCH    = 7'b1100011;
    localparam logic [6:0] OPCODE_JALR      = 7'b1100111;
    localparam logic [6:0] OPCODE_JAL       = 7'b1101111;
    localparam logic [6:0] OPCODE_SYSTEM    = 7'b1110011;

    //--------------------------------------------------------
    // Integer register numbers
    //--------------------------------------------------------

    localparam logic [4:0] X0  = 5'd0;
    localparam logic [4:0] X1  = 5'd1;
    localparam logic [4:0] X2  = 5'd2;

    //--------------------------------------------------------
    // Common compressed fields
    //--------------------------------------------------------

    logic [1:0] quadrant;
    logic [2:0] funct3;

    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;

    logic [4:0] rd_p;
    logic [4:0] rs1_p;
    logic [4:0] rs2_p;

    assign quadrant = cinstr[1:0];
    assign funct3   = cinstr[15:13];

    assign rd  = cinstr[11:7];
    assign rs1 = cinstr[11:7];
    assign rs2 = cinstr[6:2];

    // compressed register subset x8-x15
    assign rd_p  = {2'b01, cinstr[4:2]};
    assign rs1_p = {2'b01, cinstr[9:7]};
    assign rs2_p = {2'b01, cinstr[4:2]};

    //--------------------------------------------------------
    // 32-bit instruction encoding helper functions
    //--------------------------------------------------------

    function automatic logic [31:0] enc_r (
        input logic [6:0] funct7,
        input logic [4:0] rs2_i,
        input logic [4:0] rs1_i,
        input logic [2:0] funct3_i,
        input logic [4:0] rd_i,
        input logic [6:0] opcode_i
    );
        enc_r = {funct7, rs2_i, rs1_i, funct3_i, rd_i, opcode_i};
    endfunction

    function automatic logic [31:0] enc_i (
        input logic [11:0] imm_i,
        input logic [4:0]  rs1_i,
        input logic [2:0]  funct3_i,
        input logic [4:0]  rd_i,
        input logic [6:0]  opcode_i
    );
        enc_i = {imm_i, rs1_i, funct3_i, rd_i, opcode_i};
    endfunction

    function automatic logic [31:0] enc_s (
        input logic [11:0] imm_i,
        input logic [4:0]  rs2_i,
        input logic [4:0]  rs1_i,
        input logic [2:0]  funct3_i,
        input logic [6:0]  opcode_i
    );
        enc_s = {imm_i[11:5], rs2_i, rs1_i, funct3_i, imm_i[4:0], opcode_i};
    endfunction

    function automatic logic [31:0] enc_b (
        input logic [12:0] imm_i,
        input logic [4:0]  rs2_i,
        input logic [4:0]  rs1_i,
        input logic [2:0]  funct3_i,
        input logic [6:0]  opcode_i
    );
        enc_b = {
            imm_i[12],
            imm_i[10:5],
            rs2_i,
            rs1_i,
            funct3_i,
            imm_i[4:1],
            imm_i[11],
            opcode_i
        };
    endfunction

    function automatic logic [31:0] enc_u (
        input logic [19:0] imm_i,
        input logic [4:0]  rd_i,
        input logic [6:0]  opcode_i
    );
        enc_u = {imm_i, rd_i, opcode_i};
    endfunction

    function automatic logic [31:0] enc_j (
        input logic [20:0] imm_i,
        input logic [4:0]  rd_i,
        input logic [6:0]  opcode_i
    );
        enc_j = {
            imm_i[20],
            imm_i[10:1],
            imm_i[11],
            imm_i[19:12],
            rd_i,
            opcode_i
        };
    endfunction

    //--------------------------------------------------------
    // Immediate helper functions
    //--------------------------------------------------------

    function automatic logic [11:0] sext6_to_12 (
        input logic [5:0] imm6
    );
        sext6_to_12 = {{6{imm6[5]}}, imm6};
    endfunction

    function automatic logic [19:0] sext6_to_20 (
        input logic [5:0] imm6
    );
        sext6_to_20 = {{14{imm6[5]}}, imm6};
    endfunction

    //--------------------------------------------------------
    // Main decompression logic
    //--------------------------------------------------------

    always_comb begin
        instr         = 32'h0000_0013; // default NOP: addi x0, x0, 0
        illegal       = 1'b0;
        is_compressed = (quadrant != 2'b11);

        if (cinstr == 16'h0000) begin
            illegal = 1'b1;
        end

        if (!is_compressed) begin
            instr   = 32'h0000_0013;
            illegal = 1'b0;
        end
        else begin
            case (quadrant)

                //====================================================
                // Quadrant 0: cinstr[1:0] = 00
                //====================================================
                2'b00: begin
                    case (funct3)

                        //------------------------------------------------
                        // C.ADDI4SPN
                        // addi rd', x2, nzuimm
                        //------------------------------------------------
                        3'b000: begin
                            logic [11:0] nzuimm;

                            nzuimm = {
                                2'b00,
                                cinstr[10:7],
                                cinstr[12:11],
                                cinstr[5],
                                cinstr[6],
                                2'b00
                            };

                            instr = enc_i(nzuimm, X2, 3'b000, rd_p, OPCODE_OP_IMM);

                            if (nzuimm == 12'b0)
                                illegal = 1'b1;
                        end

                        //------------------------------------------------
                        // C.FLD
                        // fld rd', offset(rs1')
                        //------------------------------------------------
                        3'b001: begin
                            logic [11:0] uimm;

                            uimm = {
                                4'b0000,
                                cinstr[6:5],
                                cinstr[12:10],
                                3'b000
                            };

                            instr = enc_i(uimm, rs1_p, 3'b011, rd_p, OPCODE_LOAD_FP);
                        end

                        //------------------------------------------------
                        // C.LW
                        // lw rd', offset(rs1')
                        //------------------------------------------------
                        3'b010: begin
                            logic [11:0] uimm;

                            uimm = {
                                5'b00000,
                                cinstr[5],
                                cinstr[12:10],
                                cinstr[6],
                                2'b00
                            };

                            instr = enc_i(uimm, rs1_p, 3'b010, rd_p, OPCODE_LOAD);
                        end

                        //------------------------------------------------
                        // C.LD
                        // ld rd', offset(rs1')
                        //------------------------------------------------
                        3'b011: begin
                            logic [11:0] uimm;

                            uimm = {
                                4'b0000,
                                cinstr[6:5],
                                cinstr[12:10],
                                3'b000
                            };

                            instr = enc_i(uimm, rs1_p, 3'b011, rd_p, OPCODE_LOAD);
                        end

                        //------------------------------------------------
                        // C.FSD
                        // fsd rs2', offset(rs1')
                        //------------------------------------------------
                        3'b101: begin
                            logic [11:0] uimm;

                            uimm = {
                                4'b0000,
                                cinstr[6:5],
                                cinstr[12:10],
                                3'b000
                            };

                            instr = enc_s(uimm, rs2_p, rs1_p, 3'b011, OPCODE_STORE_FP);
                        end

                        //------------------------------------------------
                        // C.SW
                        // sw rs2', offset(rs1')
                        //------------------------------------------------
                        3'b110: begin
                            logic [11:0] uimm;

                            uimm = {
                                5'b00000,
                                cinstr[5],
                                cinstr[12:10],
                                cinstr[6],
                                2'b00
                            };

                            instr = enc_s(uimm, rs2_p, rs1_p, 3'b010, OPCODE_STORE);
                        end

                        //------------------------------------------------
                        // C.SD
                        // sd rs2', offset(rs1')
                        //------------------------------------------------
                        3'b111: begin
                            logic [11:0] uimm;

                            uimm = {
                                4'b0000,
                                cinstr[6:5],
                                cinstr[12:10],
                                3'b000
                            };

                            instr = enc_s(uimm, rs2_p, rs1_p, 3'b011, OPCODE_STORE);
                        end

                        default: begin
                            illegal = 1'b1;
                        end

                    endcase
                end

                //====================================================
                // Quadrant 1: cinstr[1:0] = 01
                //====================================================
                2'b01: begin
                    case (funct3)

                        //------------------------------------------------
                        // C.NOP / C.ADDI
                        // addi rd, rd, imm
                        //------------------------------------------------
                        3'b000: begin
                            logic [5:0]  imm6;
                            logic [11:0] imm12;

                            imm6  = {cinstr[12], cinstr[6:2]};
                            imm12 = sext6_to_12(imm6);

                            instr = enc_i(imm12, rd, 3'b000, rd, OPCODE_OP_IMM);
                        end

                        //------------------------------------------------
                        // C.ADDIW
                        // addiw rd, rd, imm
                        //------------------------------------------------
                        3'b001: begin
                            logic [5:0]  imm6;
                            logic [11:0] imm12;

                            imm6  = {cinstr[12], cinstr[6:2]};
                            imm12 = sext6_to_12(imm6);

                            instr = enc_i(imm12, rd, 3'b000, rd, OPCODE_OP_IMM_32);

                            if (rd == X0)
                                illegal = 1'b1;
                        end

                        //------------------------------------------------
                        // C.LI
                        // addi rd, x0, imm
                        //------------------------------------------------
                        3'b010: begin
                            logic [5:0]  imm6;
                            logic [11:0] imm12;

                            imm6  = {cinstr[12], cinstr[6:2]};
                            imm12 = sext6_to_12(imm6);

                            instr = enc_i(imm12, X0, 3'b000, rd, OPCODE_OP_IMM);
                        end

                        //------------------------------------------------
                        // C.ADDI16SP / C.LUI
                        //------------------------------------------------
                        3'b011: begin
                            if (rd == X2) begin
                                logic [11:0] nzimm;

                                nzimm = {
                                    {2{cinstr[12]}},
                                    cinstr[12],
                                    cinstr[4:3],
                                    cinstr[5],
                                    cinstr[2],
                                    cinstr[6],
                                    4'b0000
                                };

                                instr = enc_i(nzimm, X2, 3'b000, X2, OPCODE_OP_IMM);

                                if (nzimm == 12'b0)
                                    illegal = 1'b1;
                            end
                            else begin
                                logic [5:0]  imm6;
                                logic [19:0] imm20;

                                imm6  = {cinstr[12], cinstr[6:2]};
                                imm20 = sext6_to_20(imm6);

                                instr = enc_u(imm20, rd, OPCODE_LUI);

                                if ((rd == X0) || (rd == X2) || (imm6 == 6'b0))
                                    illegal = 1'b1;
                            end
                        end

                        //------------------------------------------------
                        // C.SRLI / C.SRAI / C.ANDI / C.SUB / C.XOR
                        // C.OR / C.AND / C.SUBW / C.ADDW
                        //------------------------------------------------
                        3'b100: begin
                            case (cinstr[11:10])

                                //----------------------------------------
                                // C.SRLI
                                //----------------------------------------
                                2'b00: begin
                                    logic [5:0] shamt;

                                    shamt = {cinstr[12], cinstr[6:2]};

                                    instr = enc_i(
                                        {6'b000000, shamt},
                                        rs1_p,
                                        3'b101,
                                        rs1_p,
                                        OPCODE_OP_IMM
                                    );
                                end

                                //----------------------------------------
                                // C.SRAI
                                //----------------------------------------
                                2'b01: begin
                                    logic [5:0] shamt;

                                    shamt = {cinstr[12], cinstr[6:2]};

                                    instr = enc_i(
                                        {6'b010000, shamt},
                                        rs1_p,
                                        3'b101,
                                        rs1_p,
                                        OPCODE_OP_IMM
                                    );
                                end

                                //----------------------------------------
                                // C.ANDI
                                //----------------------------------------
                                2'b10: begin
                                    logic [5:0]  imm6;
                                    logic [11:0] imm12;

                                    imm6  = {cinstr[12], cinstr[6:2]};
                                    imm12 = sext6_to_12(imm6);

                                    instr = enc_i(imm12, rs1_p, 3'b111, rs1_p, OPCODE_OP_IMM);
                                end

                                //----------------------------------------
                                // C.SUB / C.XOR / C.OR / C.AND
                                // C.SUBW / C.ADDW
                                //----------------------------------------
                                2'b11: begin
                                    case ({cinstr[12], cinstr[6:5]})

                                        3'b000: begin
                                            instr = enc_r(7'b0100000, rs2_p, rs1_p, 3'b000, rs1_p, OPCODE_OP);
                                        end

                                        3'b001: begin
                                            instr = enc_r(7'b0000000, rs2_p, rs1_p, 3'b100, rs1_p, OPCODE_OP);
                                        end

                                        3'b010: begin
                                            instr = enc_r(7'b0000000, rs2_p, rs1_p, 3'b110, rs1_p, OPCODE_OP);
                                        end

                                        3'b011: begin
                                            instr = enc_r(7'b0000000, rs2_p, rs1_p, 3'b111, rs1_p, OPCODE_OP);
                                        end

                                        3'b100: begin
                                            instr = enc_r(7'b0100000, rs2_p, rs1_p, 3'b000, rs1_p, OPCODE_OP_32);
                                        end

                                        3'b101: begin
                                            instr = enc_r(7'b0000000, rs2_p, rs1_p, 3'b000, rs1_p, OPCODE_OP_32);
                                        end

                                        default: begin
                                            illegal = 1'b1;
                                        end

                                    endcase
                                end

                            endcase
                        end

                        //------------------------------------------------
                        // C.J
                        // jal x0, offset
                        //------------------------------------------------
                        3'b101: begin
                            logic [20:0] jimm;

                            jimm = {
                                {9{cinstr[12]}},
                                cinstr[12],
                                cinstr[8],
                                cinstr[10:9],
                                cinstr[6],
                                cinstr[7],
                                cinstr[2],
                                cinstr[11],
                                cinstr[5:3],
                                1'b0
                            };

                            instr = enc_j(jimm, X0, OPCODE_JAL);
                        end

                        //------------------------------------------------
                        // C.BEQZ
                        // beq rs1', x0, offset
                        //------------------------------------------------
                        3'b110: begin
                            logic [12:0] bimm;

                            bimm = {
                                {4{cinstr[12]}},
                                cinstr[12],
                                cinstr[6:5],
                                cinstr[2],
                                cinstr[11:10],
                                cinstr[4:3],
                                1'b0
                            };

                            instr = enc_b(bimm, X0, rs1_p, 3'b000, OPCODE_BRANCH);
                        end

                        //------------------------------------------------
                        // C.BNEZ
                        // bne rs1', x0, offset
                        //------------------------------------------------
                        3'b111: begin
                            logic [12:0] bimm;

                            bimm = {
                                {4{cinstr[12]}},
                                cinstr[12],
                                cinstr[6:5],
                                cinstr[2],
                                cinstr[11:10],
                                cinstr[4:3],
                                1'b0
                            };

                            instr = enc_b(bimm, X0, rs1_p, 3'b001, OPCODE_BRANCH);
                        end

                        default: begin
                            illegal = 1'b1;
                        end

                    endcase
                end

                //====================================================
                // Quadrant 2: cinstr[1:0] = 10
                //====================================================
                2'b10: begin
                    case (funct3)

                        //------------------------------------------------
                        // C.SLLI
                        // slli rd, rd, shamt
                        //------------------------------------------------
                        3'b000: begin
                            logic [5:0] shamt;

                            shamt = {cinstr[12], cinstr[6:2]};

                            instr = enc_i(
                                {6'b000000, shamt},
                                rd,
                                3'b001,
                                rd,
                                OPCODE_OP_IMM
                            );
                        end

                        //------------------------------------------------
                        // C.FLDSP
                        // fld rd, offset(x2)
                        //------------------------------------------------
                        3'b001: begin
                            logic [11:0] uimm;

                            uimm = {
                                3'b000,
                                cinstr[4:2],
                                cinstr[12],
                                cinstr[6:5],
                                3'b000
                            };

                            instr = enc_i(uimm, X2, 3'b011, rd, OPCODE_LOAD_FP);
                        end

                        //------------------------------------------------
                        // C.LWSP
                        // lw rd, offset(x2)
                        //------------------------------------------------
                        3'b010: begin
                            logic [11:0] uimm;

                            uimm = {
                                4'b0000,
                                cinstr[3:2],
                                cinstr[12],
                                cinstr[6:4],
                                2'b00
                            };

                            instr = enc_i(uimm, X2, 3'b010, rd, OPCODE_LOAD);

                            if (rd == X0)
                                illegal = 1'b1;
                        end

                        //------------------------------------------------
                        // C.LDSP
                        // ld rd, offset(x2)
                        //------------------------------------------------
                        3'b011: begin
                            logic [11:0] uimm;

                            uimm = {
                                3'b000,
                                cinstr[4:2],
                                cinstr[12],
                                cinstr[6:5],
                                3'b000
                            };

                            instr = enc_i(uimm, X2, 3'b011, rd, OPCODE_LOAD);

                            if (rd == X0)
                                illegal = 1'b1;
                        end

                        //------------------------------------------------
                        // C.JR / C.MV / C.EBREAK / C.JALR / C.ADD
                        //------------------------------------------------
                        3'b100: begin
                            if ((cinstr[12] == 1'b0) && (rs2 == X0)) begin
                                // C.JR
                                // jalr x0, 0(rs1)
                                instr = enc_i(12'b0, rs1, 3'b000, X0, OPCODE_JALR);

                                if (rs1 == X0)
                                    illegal = 1'b1;
                            end
                            else if ((cinstr[12] == 1'b0) && (rs2 != X0)) begin
                                // C.MV
                                // add rd, x0, rs2
                                instr = enc_r(7'b0000000, rs2, X0, 3'b000, rd, OPCODE_OP);
                            end
                            else if ((cinstr[12] == 1'b1) && (rs2 == X0) && (rs1 == X0)) begin
                                // C.EBREAK
                                instr = enc_i(12'h001, X0, 3'b000, X0, OPCODE_SYSTEM);
                            end
                            else if ((cinstr[12] == 1'b1) && (rs2 == X0) && (rs1 != X0)) begin
                                // C.JALR
                                // jalr x1, 0(rs1)
                                instr = enc_i(12'b0, rs1, 3'b000, X1, OPCODE_JALR);
                            end
                            else begin
                                // C.ADD
                                // add rd, rd, rs2
                                instr = enc_r(7'b0000000, rs2, rd, 3'b000, rd, OPCODE_OP);
                            end
                        end

                        //------------------------------------------------
                        // C.FSDSP
                        // fsd rs2, offset(x2)
                        //------------------------------------------------
                        3'b101: begin
                            logic [11:0] uimm;

                            uimm = {
                                3'b000,
                                cinstr[9:7],
                                cinstr[12:10],
                                3'b000
                            };

                            instr = enc_s(uimm, rs2, X2, 3'b011, OPCODE_STORE_FP);
                        end

                        //------------------------------------------------
                        // C.SWSP
                        // sw rs2, offset(x2)
                        //------------------------------------------------
                        3'b110: begin
                            logic [11:0] uimm;

                            uimm = {
                                4'b0000,
                                cinstr[8:7],
                                cinstr[12:9],
                                2'b00
                            };

                            instr = enc_s(uimm, rs2, X2, 3'b010, OPCODE_STORE);
                        end

                        //------------------------------------------------
                        // C.SDSP
                        // sd rs2, offset(x2)
                        //------------------------------------------------
                        3'b111: begin
                            logic [11:0] uimm;

                            uimm = {
                                3'b000,
                                cinstr[9:7],
                                cinstr[12:10],
                                3'b000
                            };

                            instr = enc_s(uimm, rs2, X2, 3'b011, OPCODE_STORE);
                        end

                        default: begin
                            illegal = 1'b1;
                        end

                    endcase
                end

                default: begin
                    illegal = 1'b1;
                end

            endcase
        end
    end

endmodule
