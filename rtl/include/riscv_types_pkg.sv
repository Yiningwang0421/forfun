package riscv_types_pkg;
  parameter int unsigned XLEN = 64;
  parameter int unsigned ILEN = 32;
  parameter int unsigned ARCH_REGS = 32;
  parameter int unsigned PHYS_REGS = 96;
  parameter int unsigned ROB_ENTRIES = 64;
  parameter int unsigned RS_ENTRIES = 32;
  parameter int unsigned LSQ_ENTRIES = 32;
  parameter int unsigned L1_CACHE_LINE_BYTES = 64;
  parameter int unsigned L2_CACHE_LINE_BYTES = 64;
  parameter int unsigned PAGE_SIZE_BYTES = 4096;

  typedef logic [XLEN-1:0] xlen_t;
  typedef logic [ILEN-1:0] ilen_t;
  typedef logic [$clog2(ARCH_REGS)-1:0] arch_reg_idx_t;
  typedef logic [$clog2(PHYS_REGS)-1:0] phys_reg_idx_t;
  typedef logic [$clog2(ROB_ENTRIES)-1:0] rob_idx_t;
  typedef logic [$clog2(RS_ENTRIES)-1:0] rs_idx_t;
  typedef logic [$clog2(LSQ_ENTRIES)-1:0] lsq_idx_t;
  typedef enum logic [1:0] {
    PRIV_U = 2'd0,
    PRIV_S = 2'd1,
    PRIV_M = 2'd3
  } privilege_mode_t;

  typedef enum logic [2:0] {
    IMM_I = 3'd0,
    IMM_S = 3'd1,
    IMM_B = 3'd2,
    IMM_U = 3'd3,
    IMM_J = 3'd4
  } imm_type_t;

  typedef enum logic [3:0] {
    INSN_ALU = 4'd0,
    INSN_LOAD = 4'd1,
    INSN_STORE = 4'd2,
    INSN_BRANCH = 4'd3,
    INSN_JUMP = 4'd4,
    INSN_UPPER_IMM = 4'd5,
    INSN_SYSTEM = 4'd6,
    INSN_FENCE = 4'd7,
    INSN_ATOMIC = 4'd8,
    INSN_FLOAT = 4'd9,
    INSN_INVALID = 4'd15
  } instruction_class_t;

  typedef enum logic [5:0] {
    ALU_ADD = 6'd0,
    ALU_SUB = 6'd1,
    ALU_AND = 6'd2,
    ALU_OR = 6'd3,
    ALU_XOR = 6'd4,
    ALU_SLL = 6'd5,
    ALU_SRL = 6'd6,
    ALU_SRA = 6'd7,
    ALU_SLT = 6'd8,
    ALU_SLTU = 6'd9,
    ALU_COPY_B = 6'd10,
    ALU_PASS = 6'd11
  } alu_op_t;

  typedef enum logic [1:0] {
    REG_WRITE_NONE = 2'd0,
    REG_WRITE_ALU = 2'd1,
    REG_WRITE_MEM = 2'd2,
    REG_WRITE_PC4 = 2'd3
  } reg_write_source_t;

  typedef enum logic [1:0] {
    PRIV_LEVEL_U = 2'd0,
    PRIV_LEVEL_S = 2'd1,
    PRIV_LEVEL_M = 2'd3
  } privilege_level_t;

  typedef enum logic [1:0] {
    EXC_NONE = 2'd0,
    EXC_INTERRUPT = 2'd1,
    EXC_EXCEPTION = 2'd2,
    EXC_RESERVED = 2'd3
  } trap_kind_t;

  typedef struct packed {
    logic [6:0] opcode;
    logic [4:0] rd;
    logic [2:0] funct3;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [6:0] funct7;
  } instruction_fields_t;

  typedef struct packed {
    logic [XLEN-1:0] pc;
    logic [XLEN-1:0] pc_next;
    logic [XLEN-1:0] inst;
    logic [XLEN-1:0] rs1_value;
    logic [XLEN-1:0] rs2_value;
    logic [XLEN-1:0] rd_value;
    logic [XLEN-1:0] immediate;
    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;
    alu_op_t alu_op;
    imm_type_t imm_type;
    instruction_class_t instr_class;
  } decode_packet_t;

  typedef struct packed {
    logic valid;
    logic ready;
    logic taken;
    logic is_store;
    logic is_load;
    logic is_branch;
    logic is_jump;
  } pipeline_control_t;
endpackage : riscv_types_pkg
