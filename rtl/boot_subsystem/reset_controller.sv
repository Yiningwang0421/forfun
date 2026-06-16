`timescale 1ns/1ps

//============================================================
// Module: reset_controller
//
// Description:
//   Reset controller for RV64GC multicore CPU.
//
//   This module synchronizes the external active-low reset and
//   generates clean per-hart reset signals.
//
//   It also tells each hart what architectural reset state should
//   be loaded:
//
//     - reset PC
//     - reset privilege mode
//     - reset cause
//     - clear pipeline
//     - clear TLB
//     - clear LR/SC reservation
//     - clear branch predictor
//
// Important:
//   This module does NOT directly write CSRs.
//   It only outputs reset intent.
//   csr_unit / privilege_controller should consume these outputs.
//
// RISC-V reset rule:
//   After reset, each hart starts in M-mode at an
//   implementation-defined reset vector.
//
// Reset convention in our RTL:
//   reset_n is active-low.
//============================================================

module reset_controller #(
    parameter int NUM_HARTS = 2,
    parameter int XLEN      = 64,

    parameter logic [XLEN-1:0] RESET_VECTOR =
        64'h0000_0000_0000_1000,

    parameter int RESET_HOLD_CYCLES = 16
)(
    input  logic clk,
    input  logic reset_n,

    input  logic external_reset_req,
    input  logic watchdog_reset_req,
    input  logic software_reset_req,
    input  logic debug_reset_req,

    output logic [NUM_HARTS-1:0] hart_reset_n,
    output logic [NUM_HARTS-1:0] core_flush,
    output logic [NUM_HARTS-1:0] reset_valid,

    output logic [NUM_HARTS-1:0][XLEN-1:0] reset_pc,
    output logic [NUM_HARTS-1:0][1:0]      reset_priv_mode,
    output logic [NUM_HARTS-1:0][XLEN-1:0] reset_mcause,

    output logic [NUM_HARTS-1:0] reset_clear_lr_reservation,
    output logic [NUM_HARTS-1:0] reset_clear_pipeline,
    output logic [NUM_HARTS-1:0] reset_clear_tlb,
    output logic [NUM_HARTS-1:0] reset_clear_branch_predictor
);

    //------------------------------------------------------------
    // Privilege mode encoding
    //------------------------------------------------------------

    localparam logic [1:0] PRIV_U = 2'b00;
    localparam logic [1:0] PRIV_S = 2'b01;
    localparam logic [1:0] PRIV_M = 2'b11;

    //------------------------------------------------------------
    // Reset cause encoding
    //
    // These are implementation-defined reset causes.
    // They are carried into csr_unit so mcause can be initialized.
    //------------------------------------------------------------

    localparam logic [XLEN-1:0] RESET_CAUSE_POWER_ON = {{(XLEN-4){1'b0}}, 4'h0};
    localparam logic [XLEN-1:0] RESET_CAUSE_EXTERNAL = {{(XLEN-4){1'b0}}, 4'h1};
    localparam logic [XLEN-1:0] RESET_CAUSE_WATCHDOG = {{(XLEN-4){1'b0}}, 4'h2};
    localparam logic [XLEN-1:0] RESET_CAUSE_SOFTWARE = {{(XLEN-4){1'b0}}, 4'h3};
    localparam logic [XLEN-1:0] RESET_CAUSE_DEBUG    = {{(XLEN-4){1'b0}}, 4'h4};

    //------------------------------------------------------------
    // Internal reset request
    //------------------------------------------------------------

    logic reset_req;

    assign reset_req =
        external_reset_req |
        watchdog_reset_req |
        software_reset_req |
        debug_reset_req;

    //------------------------------------------------------------
    // Pick reset cause priority
    //------------------------------------------------------------

    logic [XLEN-1:0] reset_cause_next;

    always_comb begin
        reset_cause_next = RESET_CAUSE_POWER_ON;

        if (debug_reset_req) begin
            reset_cause_next = RESET_CAUSE_DEBUG;
        end
        else if (watchdog_reset_req) begin
            reset_cause_next = RESET_CAUSE_WATCHDOG;
        end
        else if (software_reset_req) begin
            reset_cause_next = RESET_CAUSE_SOFTWARE;
        end
        else if (external_reset_req) begin
            reset_cause_next = RESET_CAUSE_EXTERNAL;
        end
    end

    //------------------------------------------------------------
    // Synchronize async external reset_n into clk domain
    //------------------------------------------------------------

    logic reset_sync_1;
    logic reset_sync_2;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            reset_sync_1 <= 1'b0;
            reset_sync_2 <= 1'b0;
        end
        else begin
            reset_sync_1 <= 1'b1;
            reset_sync_2 <= reset_sync_1;
        end
    end

    logic global_reset_active;

    assign global_reset_active = (!reset_sync_2) | reset_req;

    //------------------------------------------------------------
    // Reset FSM
    //------------------------------------------------------------

    typedef enum logic [1:0] {
        RESET_STATE_ASSERT,
        RESET_STATE_HOLD,
        RESET_STATE_RELEASE
    } reset_state_e;

    reset_state_e state;
    reset_state_e next_state;

    logic [$clog2(RESET_HOLD_CYCLES+1)-1:0] hold_counter;

    always_comb begin
        next_state = state;

        case (state)

            RESET_STATE_ASSERT: begin
                next_state = RESET_STATE_HOLD;
            end

            RESET_STATE_HOLD: begin
                if (hold_counter == RESET_HOLD_CYCLES[$bits(hold_counter)-1:0]) begin
                    next_state = RESET_STATE_RELEASE;
                end
            end

            RESET_STATE_RELEASE: begin
                if (global_reset_active) begin
                    next_state = RESET_STATE_ASSERT;
                end
            end

            default: begin
                next_state = RESET_STATE_ASSERT;
            end

        endcase
    end

    //------------------------------------------------------------
    // State registers
    //------------------------------------------------------------

    logic [XLEN-1:0] reset_cause_reg;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state           <= RESET_STATE_ASSERT;
            hold_counter    <= '0;
            reset_cause_reg <= RESET_CAUSE_POWER_ON;
        end
        else begin
            state <= next_state;

            if (global_reset_active) begin
                hold_counter    <= '0;
                reset_cause_reg <= reset_cause_next;
            end
            else if (state == RESET_STATE_HOLD) begin
                if (hold_counter != RESET_HOLD_CYCLES[$bits(hold_counter)-1:0]) begin
                    hold_counter <= hold_counter + 1'b1;
                end
            end
            else begin
                hold_counter <= '0;
            end
        end
    end

    //------------------------------------------------------------
    // Output generation
    //------------------------------------------------------------

    logic reset_is_active;
    logic reset_is_release_cycle;

    assign reset_is_active =
        (state == RESET_STATE_ASSERT) ||
        (state == RESET_STATE_HOLD)   ||
        global_reset_active;

    assign reset_is_release_cycle =
        (state == RESET_STATE_HOLD) &&
        (next_state == RESET_STATE_RELEASE);

    always_comb begin
        for (int i = 0; i < NUM_HARTS; i++) begin

            hart_reset_n[i] = !reset_is_active;

            core_flush[i] = reset_is_active;

            reset_valid[i] = reset_is_release_cycle;

            reset_pc[i] = RESET_VECTOR;

            reset_priv_mode[i] = PRIV_M;

            reset_mcause[i] = reset_cause_reg;

            reset_clear_lr_reservation[i] = reset_is_active;
            reset_clear_pipeline[i]       = reset_is_active;
            reset_clear_tlb[i]            = reset_is_active;
            reset_clear_branch_predictor[i] = reset_is_active;

        end
    end

endmodule