`timescale 1ns/1ps

//============================================================
// Module: boot_rom
//
// Description:
//   Simple read-only boot ROM for RV64GC CPU.
//
//   After reset, reset_controller should set PC to BOOT_ROM_BASE.
//   The frontend fetches instructions from this ROM.
//
//   This ROM does not execute instructions.
//   It only maps:
//
//      fetch address -> 32-bit instruction
//
// Target:
//   RV64GC
//   Linux-capable boot path
//   OpenSBI-style M-mode entry
//
// Notes:
//   - Reset starts in M-mode.
//   - Boot ROM is read-only.
//   - Instruction fetch returns 32-bit words.
//   - C-extension 16-bit instructions are handled later by frontend.
//
//============================================================

module boot_rom #(
    parameter int ADDR_W = 64,
    parameter int DATA_W = 32,

    parameter logic [ADDR_W-1:0] BOOT_ROM_BASE =
        64'h0000_0000_0000_1000,

    parameter int ROM_WORDS = 1024,
    parameter int ROM_ADDR_W = $clog2(ROM_WORDS)
)(
    input  logic clk,
    input  logic reset_n,

    input  logic             req_valid,
    input  logic [ADDR_W-1:0] req_addr,

    output logic             resp_valid,
    output logic [DATA_W-1:0] resp_rdata,
    output logic             resp_error
);

    //------------------------------------------------------------
    // ROM storage
    //------------------------------------------------------------

    logic [DATA_W-1:0] rom [0:ROM_WORDS-1];

    //------------------------------------------------------------
    // Address decode
    //------------------------------------------------------------

    logic [ADDR_W-1:0] byte_offset;
    logic [ROM_ADDR_W-1:0] word_index;
    logic addr_in_range;
    logic addr_aligned;

    assign byte_offset = req_addr - BOOT_ROM_BASE;

    assign word_index = byte_offset[ROM_ADDR_W+1:2];

    assign addr_in_range =
        (req_addr >= BOOT_ROM_BASE) &&
        (byte_offset < ROM_WORDS * 4);

    assign addr_aligned = (req_addr[1:0] == 2'b00);

    //------------------------------------------------------------
    // ROM contents
    //
    // This is only a placeholder boot program.
    //
    // Real boot code should be generated from boot.S and loaded
    // using $readmemh.
    //------------------------------------------------------------

    initial begin
        for (int i = 0; i < ROM_WORDS; i++) begin
            rom[i] = 32'h0000_0013; // nop
        end

        $readmemh("boot_rom.hex", rom); // Load boot program from hex file， did not finish the boot program, just a placeholder for now.
    end

    //------------------------------------------------------------
    // Read response
    //------------------------------------------------------------

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            resp_valid <= 1'b0;
            resp_rdata <= '0;
            resp_error <= 1'b0;
        end
        else begin
            resp_valid <= req_valid;

            if (req_valid) begin
                if (!addr_in_range || !addr_aligned) begin
                    resp_rdata <= 32'h0000_0000; // illegal instruction
                    resp_error <= 1'b1;
                end
                else begin
                    resp_rdata <= rom[word_index];
                    resp_error <= 1'b0;
                end
            end
            else begin
                resp_rdata <= '0;
                resp_error <= 1'b0;
            end
        end
    end

endmodule