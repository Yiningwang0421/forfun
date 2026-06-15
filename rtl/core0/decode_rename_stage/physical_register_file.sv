module physical_register_file #(
    parameter int NUM_PREG  = 96,
    parameter int NUM_RPORT = 4,
    parameter int NUM_WPORT = 2,
    parameter int DATA_W    = 64,
    parameter int PREG_W    = $clog2(NUM_PREG)
)(
    input  logic clk,
    input  logic reset_n,

    input  logic [NUM_RPORT-1:0][PREG_W-1:0] raddr,
    output logic [NUM_RPORT-1:0][DATA_W-1:0] rdata,

    input  logic [NUM_WPORT-1:0]              we,
    input  logic [NUM_WPORT-1:0][PREG_W-1:0] waddr,
    input  logic [NUM_WPORT-1:0][DATA_W-1:0] wdata
);

    logic [DATA_W-1:0] reg_file [0:NUM_PREG-1];

    // Combinational read
    always_comb begin
        for (int i = 0; i < NUM_RPORT; i++) begin
            if (raddr[i] == '0)
                rdata[i] = '0;
            else
                rdata[i] = reg_file[raddr[i]];
        end
    end

    // Synchronous reset + synchronous write
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            for (int i = 0; i < NUM_PREG; i++) begin
                reg_file[i] <= '0;
            end
        end else begin
            for (int i = 0; i < NUM_WPORT; i++) begin
                if (we[i] && (waddr[i] != '0)) begin
                    reg_file[waddr[i]] <= wdata[i];
                end
            end

            // p0 is always zero
            reg_file[0] <= '0;
        end
    end

    // Detect illegal same-cycle double write to same physical register
    always_comb begin
        for (int i = 0; i < NUM_WPORT; i++) begin
            for (int j = i + 1; j < NUM_WPORT; j++) begin
                assert (!(we[i] && we[j] &&
                          (waddr[i] == waddr[j]) &&
                          (waddr[i] != '0)))
                    else $fatal("Multiple write ports write same physical register");
            end
        end
    end

endmodule