//============================================================
// File: riscv_types_pkg.sv
// Project: Linux-capable Dual-Core OoO RV64GC RISC-V CPU
//
// Purpose:
//   Shared constants, enums, structs, and helper functions.
//
// Spec sources:
//   - RISC-V Volume I: Unprivileged ISA
//   - RISC-V Volume II: Privileged Architecture
//
// Notes:
//   ISA-visible definitions must follow the RISC-V spec.
//   Microarchitecture definitions are design choices.
//============================================================

package riscv_types_pkg;

    //============================================================
    // ISA-defined global parameters
    // Source: Volume I
    //============================================================

    parameter int XLEN = 64;
    parameter int ILEN = 32;

    parameter int ARCH_REGS = 32;
    parameter int AREG_BITS = 5;

    parameter int ZERO_REG = 0;
    parameter int ADDR_BITS = 64;

    //============================================================
    // Microarchitecture-defined parameters
    // Source: Our CPU design
    //============================================================

    parameter int PHYS_REGS   = 96;
    parameter int ROB_ENTRIES = 64;
    parameter int RS_ENTRIES  = 32;
    parameter int LSQ_ENTRIES = 32;

    parameter int PREG_BITS = $clog2(PHYS_REGS);
    parameter int ROB_BITS  = $clog2(ROB_ENTRIES);
    parameter int RS_BITS   = $clog2(RS_ENTRIES);
    parameter int LSQ_BITS  = $clog2(LSQ_ENTRIES);

    typedef logic [XLEN-1:0]      xlen_t;
    typedef logic [ADDR_BITS-1:0] addr_t;
    typedef logic [AREG_BITS-1:0] arch_reg_t;
    typedef logic [PREG_BITS-1:0] phys_reg_t;
    typedef logic [ROB_BITS-1:0]  rob_idx_t;

    //============================================================
    // RISC-V base opcodes
    // Source: Volume I instruction encoding
    //============================================================

    typedef enum logic [6:0] {
        OPCODE_LOAD      = 7'b0000011,
        OPCODE_LOAD_FP   = 7'b0000111,
        OPCODE_MISC_MEM  = 7'b0001111,
        OPCODE_OP_IMM    = 7'b0010011,
        OPCODE_AUIPC     = 7'b0010111,
        OPCODE_OP_IMM_32 = 7'b0011011,

        OPCODE_STORE     = 7'b0100011,
        OPCODE_STORE_FP  = 7'b0100111,
        OPCODE_AMO       = 7'b0101111,
        OPCODE_OP        = 7'b0110011,
        OPCODE_LUI       = 7'b0110111,
        OPCODE_OP_32     = 7'b0111011,

        OPCODE_MADD      = 7'b1000011,
        OPCODE_MSUB      = 7'b1000111,
        OPCODE_NMSUB     = 7'b1001011,
        OPCODE_NMADD     = 7'b1001111,
        OPCODE_OP_FP     = 7'b1010011,

        OPCODE_BRANCH    = 7'b1100011,
        OPCODE_JALR      = 7'b1100111,
        OPCODE_JAL       = 7'b1101111,
        OPCODE_SYSTEM    = 7'b1110011
    } opcode_e;

    //============================================================
    // Instruction formats and immediate types
    // Source: Volume I, base instruction formats
    //============================================================

    typedef enum logic [2:0] {
        FMT_R,
        FMT_I,
        FMT_S,
        FMT_B,
        FMT_U,
        FMT_J,
        FMT_SYSTEM,
        FMT_UNKNOWN
    } instr_format_e;

    typedef enum logic [2:0] {
        IMM_NONE,
        IMM_I,
        IMM_S,
        IMM_B,
        IMM_U,
        IMM_J,
        IMM_CSR
    } imm_type_e;

    //============================================================
    // Integer ALU operations
    // Source: Volume I RV64I
    //============================================================

    typedef enum logic [4:0] {
        ALU_ADD,
        ALU_SUB,
        ALU_AND,
        ALU_OR,
        ALU_XOR,
        ALU_SLL,
        ALU_SRL,
        ALU_SRA,
        ALU_SLT,
        ALU_SLTU,

        // RV64I 32-bit word operations.
        ALU_ADDW,
        ALU_SUBW,
        ALU_SLLW,
        ALU_SRLW,
        ALU_SRAW,

        ALU_COPY_A,
        ALU_COPY_B,
        ALU_NONE
    } alu_op_e;

    //============================================================
    // Branch and jump operations
    // Source: Volume I
    //============================================================

    typedef enum logic [3:0] {
        BR_NONE,
        BR_BEQ,
        BR_BNE,
        BR_BLT,
        BR_BGE,
        BR_BLTU,
        BR_BGEU,
        BR_JAL,
        BR_JALR
    } branch_op_e;

    //============================================================
    // Load/store operations
    // Source: Volume I RV64I load/store instructions
    //============================================================

    typedef enum logic [3:0] {
        LOAD_NONE,
        LOAD_LB,
        LOAD_LH,
        LOAD_LW,
        LOAD_LD,
        LOAD_LBU,
        LOAD_LHU,
        LOAD_LWU
    } load_op_e;

    typedef enum logic [2:0] {
        STORE_NONE,
        STORE_SB,
        STORE_SH,
        STORE_SW,
        STORE_SD
    } store_op_e;

    //============================================================
    // CSR operations
    // Source: Volume I Zicsr
    //============================================================

    typedef enum logic [2:0] {
        CSR_NONE,
        CSR_RW,
        CSR_RS,
        CSR_RC,
        CSR_RWI,
        CSR_RSI,
        CSR_RCI
    } csr_op_e;

    //============================================================
    // Privilege modes
    // Source: Volume II
    // U = 00, S = 01, M = 11
    //============================================================

    typedef enum logic [1:0] {
        PRIV_U = 2'b00,
        PRIV_S = 2'b01,
        PRIV_M = 2'b11
    } priv_mode_e;

    //============================================================
    // CSR addresses
    // Source: Volume II CSR listing
    //============================================================

    typedef enum logic [11:0] {
        CSR_FFLAGS      = 12'h001,
        CSR_FRM         = 12'h002,
        CSR_FCSR        = 12'h003,

        CSR_CYCLE       = 12'hC00,
        CSR_TIME        = 12'hC01,
        CSR_INSTRET     = 12'hC02,

        CSR_SSTATUS     = 12'h100,
        CSR_SIE         = 12'h104,
        CSR_STVEC       = 12'h105,
        CSR_SSCRATCH    = 12'h140,
        CSR_SEPC        = 12'h141,
        CSR_SCAUSE      = 12'h142,
        CSR_STVAL       = 12'h143,
        CSR_SIP         = 12'h144,
        CSR_SATP        = 12'h180,

        CSR_MSTATUS     = 12'h300,
        CSR_MISA        = 12'h301,
        CSR_MEDELEG     = 12'h302,
        CSR_MIDELEG     = 12'h303,
        CSR_MIE         = 12'h304,
        CSR_MTVEC       = 12'h305,
        CSR_MSCRATCH    = 12'h340,
        CSR_MEPC        = 12'h341,
        CSR_MCAUSE      = 12'h342,
        CSR_MTVAL       = 12'h343,
        CSR_MIP         = 12'h344,
        CSR_MHARTID     = 12'hF14
    } csr_addr_e;

    //============================================================
    // Exception causes
    // Source: Volume II trap cause codes
    //============================================================

    typedef enum logic [5:0] {
        EXC_INST_ADDR_MISALIGNED = 6'd0,
        EXC_INST_ACCESS_FAULT    = 6'd1,
        EXC_ILLEGAL_INST         = 6'd2,
        EXC_BREAKPOINT           = 6'd3,
        EXC_LOAD_ADDR_MISALIGNED = 6'd4,
        EXC_LOAD_ACCESS_FAULT    = 6'd5,
        EXC_STORE_ADDR_MISALIGN  = 6'd6,
        EXC_STORE_ACCESS_FAULT   = 6'd7,
        EXC_ECALL_U              = 6'd8,
        EXC_ECALL_S              = 6'd9,
        EXC_ECALL_M              = 6'd11,
        EXC_INST_PAGE_FAULT      = 6'd12,
        EXC_LOAD_PAGE_FAULT      = 6'd13,
        EXC_STORE_PAGE_FAULT     = 6'd15
    } exception_cause_e;

    typedef enum logic [5:0] {
        INT_SUPERVISOR_SOFTWARE = 6'd1,
        INT_MACHINE_SOFTWARE    = 6'd3,
        INT_SUPERVISOR_TIMER    = 6'd5,
        INT_MACHINE_TIMER       = 6'd7,
        INT_SUPERVISOR_EXTERNAL = 6'd9,
        INT_MACHINE_EXTERNAL    = 6'd11
    } interrupt_cause_e;

    //============================================================
    // Memory and atomic operations
    // Source: Volume I A extension and memory model
    //============================================================

    typedef enum logic [2:0] {
        MEM_NONE,
        MEM_LOAD,
        MEM_STORE,
        MEM_AMO,
        MEM_LR,
        MEM_SC
    } mem_op_e;

    typedef enum logic [3:0] {
        AMO_NONE,
        AMO_SWAP,
        AMO_ADD,
        AMO_XOR,
        AMO_AND,
        AMO_OR,
        AMO_MIN,
        AMO_MAX,
        AMO_MINU,
        AMO_MAXU,
        AMO_LR,
        AMO_SC
    } amo_op_e;

    //============================================================
    // Sv39 virtual memory constants
    // Source: Volume II supervisor virtual memory
    //============================================================

    parameter int PAGE_OFFSET_BITS = 12;
    parameter int SV39_VPN_BITS    = 9;
    parameter int SV39_LEVELS      = 3;

    typedef enum logic [3:0] {
        SATP_MODE_BARE = 4'd0,
        SATP_MODE_SV39 = 4'd8,
        SATP_MODE_SV48 = 4'd9,
        SATP_MODE_SV57 = 4'd10
    } satp_mode_e;

    typedef struct packed {
        logic [3:0]  mode;
        logic [15:0] asid;
        logic [43:0] ppn;
    } satp_t;

    typedef struct packed {
        logic v;
        logic r;
        logic w;
        logic x;
        logic u;
        logic g;
        logic a;
        logic d;
        logic [1:0] rsw;
        logic [43:0] ppn;
        logic [9:0] reserved;
    } pte_t;

    //============================================================
    // Decoded instruction bundle
    // Source: ISA fields + internal control signals
    //============================================================

    typedef struct packed {
        logic              valid;
        logic [ILEN-1:0]   instr;
        addr_t             pc;

        opcode_e           opcode;
        instr_format_e     format;
        imm_type_e         imm_type;

        arch_reg_t         rd;
        arch_reg_t         rs1;
        arch_reg_t         rs2;

        logic [2:0]        funct3;
        logic [6:0]        funct7;

        alu_op_e           alu_op;
        branch_op_e        branch_op;
        load_op_e          load_op;
        store_op_e         store_op;
        csr_op_e           csr_op;
        amo_op_e           amo_op;

        logic              uses_rs1;
        logic              uses_rs2;
        logic              writes_rd;

        logic              is_load;
        logic              is_store;
        logic              is_branch;
        logic              is_jump;
        logic              is_csr;
        logic              is_fence;
        logic              is_fence_i;
        logic              is_ecall;
        logic              is_ebreak;
        logic              is_mret;
        logic              is_sret;
        logic              is_wfi;
        logic              is_amo;
        logic              is_mul_div;
        logic              is_fp;

        logic              illegal;
    } decoded_instr_t;

    //============================================================
    // OoO microarchitecture structs
    // Source: Our CPU design
    //============================================================

    typedef struct packed {
        logic      ready;
        phys_reg_t preg;
        xlen_t     value;
    } phys_operand_t;

    typedef struct packed {
        logic              valid;
        logic              busy;
        logic              done;

        addr_t             pc;
        decoded_instr_t    decoded;

        arch_reg_t         arch_rd;
        phys_reg_t         new_preg;
        phys_reg_t         old_preg;

        logic              exception_valid;
        logic [5:0]        exception_cause;
        addr_t             exception_tval;

        logic              branch_mispredict;
        addr_t             redirect_pc;
    } rob_entry_t;

    typedef struct packed {
        logic              valid;
        rob_idx_t          rob_idx;

        decoded_instr_t    decoded;

        phys_operand_t     src1;
        phys_operand_t     src2;

        xlen_t             imm;
        phys_reg_t         dst_preg;
    } rs_entry_t;

    typedef struct packed {
        logic              valid;
        logic [1:0]        core_id;
        rob_idx_t          rob_idx;

        mem_op_e           mem_op;
        load_op_e          load_op;
        store_op_e         store_op;
        amo_op_e           amo_op;

        addr_t             vaddr;
        addr_t             paddr;

        xlen_t             wdata;
        logic [7:0]        byte_enable;
    } mem_req_t;

    typedef struct packed {
        logic              valid;
        logic [1:0]        core_id;
        rob_idx_t          rob_idx;

        xlen_t             rdata;

        logic              exception_valid;
        logic [5:0]        exception_cause;
        addr_t             exception_tval;
    } mem_resp_t;

    typedef struct packed {
        logic              valid;
        addr_t             vaddr;
        priv_mode_e        priv_mode;

        logic              is_fetch;
        logic              is_load;
        logic              is_store;
        logic              is_execute;
    } tlb_req_t;

    typedef struct packed {
        logic              valid;
        logic              hit;
        addr_t             paddr;

        logic              page_fault;
        logic              access_fault;
    } tlb_resp_t;

    typedef struct packed {
        logic              valid;
        logic              taken;
        addr_t             target;
        logic [15:0]       metadata;
    } branch_pred_t;

    typedef struct packed {
        logic              valid;
        phys_reg_t         dst_preg;
        xlen_t             value;
        rob_idx_t          rob_idx;

        logic              exception_valid;
        logic [5:0]        exception_cause;
        addr_t             exception_tval;
    } cdb_packet_t;

    //============================================================
    // Helper functions: instruction field extraction
    // Source: Volume I instruction formats
    //============================================================

    function automatic opcode_e get_opcode(input logic [31:0] instr);
        return opcode_e'(instr[6:0]);
    endfunction

    function automatic arch_reg_t get_rd(input logic [31:0] instr);
        return instr[11:7];
    endfunction

    function automatic logic [2:0] get_funct3(input logic [31:0] instr);
        return instr[14:12];
    endfunction

    function automatic arch_reg_t get_rs1(input logic [31:0] instr);
        return instr[19:15];
    endfunction

    function automatic arch_reg_t get_rs2(input logic [31:0] instr);
        return instr[24:20];
    endfunction

    function automatic logic [6:0] get_funct7(input logic [31:0] instr);
        return instr[31:25];
    endfunction

    //============================================================
    // Helper functions: immediate generation
    // Source: Volume I immediate encoding variants
    //============================================================

    function automatic xlen_t imm_i(input logic [31:0] instr);
        return {{(XLEN-12){instr[31]}}, instr[31:20]};
    endfunction

    function automatic xlen_t imm_s(input logic [31:0] instr);
        return {{(XLEN-12){instr[31]}}, instr[31:25], instr[11:7]};
    endfunction

    function automatic xlen_t imm_b(input logic [31:0] instr);
        return {{(XLEN-13){instr[31]}},
                instr[31],
                instr[7],
                instr[30:25],
                instr[11:8],
                1'b0};
    endfunction

    function automatic xlen_t imm_u(input logic [31:0] instr);
        return {{(XLEN-32){instr[31]}}, instr[31:12], 12'b0};
    endfunction

    function automatic xlen_t imm_j(input logic [31:0] instr);
        return {{(XLEN-21){instr[31]}},
                instr[31],
                instr[19:12],
                instr[20],
                instr[30:21],
                1'b0};
    endfunction

    function automatic xlen_t imm_csr(input logic [31:0] instr);
        return {{(XLEN-5){1'b0}}, instr[19:15]};
    endfunction

    function automatic xlen_t get_imm(
        input logic [31:0] instr,
        input imm_type_e   imm_type
    );
        case (imm_type)
            IMM_I:   return imm_i(instr);
            IMM_S:   return imm_s(instr);
            IMM_B:   return imm_b(instr);
            IMM_U:   return imm_u(instr);
            IMM_J:   return imm_j(instr);
            IMM_CSR: return imm_csr(instr);
            default: return '0;
        endcase
    endfunction

    //============================================================
    // Helper functions: register checks
    //============================================================

    function automatic logic is_zero_arch_reg(input arch_reg_t reg_idx);
        return reg_idx == arch_reg_t'(ZERO_REG);
    endfunction

    function automatic logic is_zero_phys_reg(input phys_reg_t preg_idx);
        return preg_idx == '0;
    endfunction

    //============================================================
    // Helper functions: store byte enable
    //============================================================

    function automatic logic [7:0] store_byte_enable(
        input store_op_e store_op,
        input logic [2:0] addr_offset
    );
        case (store_op)
            STORE_SB: return 8'b0000_0001 << addr_offset;
            STORE_SH: return 8'b0000_0011 << addr_offset;
            STORE_SW: return 8'b0000_1111 << addr_offset;
            STORE_SD: return 8'b1111_1111;
            default:  return 8'b0000_0000;
        endcase
    endfunction

    //============================================================
    // Helper functions: load extension
    //============================================================

    function automatic xlen_t load_extend(
        input load_op_e load_op,
        input xlen_t    raw_data,
        input logic [2:0] addr_offset
    );
        logic [7:0]  byte_val;
        logic [15:0] half_val;
        logic [31:0] word_val;

        begin
            byte_val = raw_data >> (addr_offset * 8);
            half_val = raw_data >> (addr_offset * 8);
            word_val = raw_data >> (addr_offset * 8);

            case (load_op)
                LOAD_LB:  return {{(XLEN-8){byte_val[7]}}, byte_val};
                LOAD_LH:  return {{(XLEN-16){half_val[15]}}, half_val};
                LOAD_LW:  return {{(XLEN-32){word_val[31]}}, word_val};
                LOAD_LD:  return raw_data;
                LOAD_LBU: return {{(XLEN-8){1'b0}}, byte_val};
                LOAD_LHU: return {{(XLEN-16){1'b0}}, half_val};
                LOAD_LWU: return {{(XLEN-32){1'b0}}, word_val};
                default:  return '0;
            endcase
        end
    endfunction

endpackage