/**********************************************************************************
* Module: async_fifo
* Description: A simple asynchronous FIFO (First-In, First-Out) memory buffer.
* This design uses Gray code pointers to safely cross clock domains.
* Parameters:
* - DATA_WIDTH: Width of the data bus.
* - ADDR_WIDTH: Width of the address bus (determines FIFO depth, Depth = 2^ADDR_WIDTH).
**********************************************************************************/

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
) (
    // Write Port
    input  logic                  wclk,
    input  logic                  wrst_n,
    input  logic                  winc,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic                  wfull,

    // Read Port
    input  logic                  rclk,
    input  logic                  rrst_n,
    input  logic                  rinc,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  rempty
);

    // FIFO depth calculated from address width
    localparam FIFO_DEPTH = 1 << ADDR_WIDTH;

    // Memory array for FIFO storage
    logic [DATA_WIDTH-1:0] mem [FIFO_DEPTH-1:0];

    // Pointers and control signals
    logic [ADDR_WIDTH:0] wptr_bin, rptr_bin;    // Binary pointers for addressing
    logic [ADDR_WIDTH:0] wptr_gray, rptr_gray;  // Gray code pointers for clock domain crossing
    logic [ADDR_WIDTH:0] wptr_sync, rptr_sync;  // Synchronized Gray pointers

    // Two-stage synchronizers for crossing clock domains to reduce metastability
    logic [ADDR_WIDTH:0] wptr_sync_stage1, rptr_sync_stage1;

    // Internal full and empty conditions
    logic wfull_internal, rempty_internal;

    //--------------------------------------------------------------------------
    // Write Clock Domain Logic
    //--------------------------------------------------------------------------

    // Binary to Gray code conversion function
    function logic [ADDR_WIDTH:0] bin2gray(logic [ADDR_WIDTH:0] bin);
        return bin ^ (bin >> 1);
    endfunction

    // Write pointer logic
    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wptr_bin  <= '0;
            wptr_gray <= '0;
        end else begin
            if (winc && !wfull_internal) begin
                wptr_bin <= wptr_bin + 1;
                wptr_gray <= bin2gray(wptr_bin + 1);
            end
        end
    end

    // Write data to memory
    always_ff @(posedge wclk) begin
        if (winc && !wfull_internal) begin
            mem[wptr_bin[ADDR_WIDTH-1:0]] <= wdata;
        end
    end

    // Synchronize read pointer to the write clock domain
    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            rptr_sync_stage1 <= '0;
            rptr_sync        <= '0;
        end else begin
            rptr_sync_stage1 <= rptr_gray;
            rptr_sync        <= rptr_sync_stage1;
        end
    end

    // Full condition logic: Compares the write pointer with the synchronized read pointer.
    // The MSB is inverted in the comparison for a Gray code full condition.
    assign wfull_internal = (wptr_gray == {~rptr_sync[ADDR_WIDTH:ADDR_WIDTH-1], rptr_sync[ADDR_WIDTH-2:0]});
    assign wfull = wfull_internal;

    //--------------------------------------------------------------------------
    // Read Clock Domain Logic
    //--------------------------------------------------------------------------

    // Read pointer logic
    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rptr_bin  <= '0;
            rptr_gray <= '0;
        end else begin
            if (rinc && !rempty_internal) begin
                rptr_bin <= rptr_bin + 1;
                rptr_gray <= bin2gray(rptr_bin + 1);
            end
        end
    end

    // Read data from memory (read-before-increment behavior)
    assign rdata = mem[rptr_bin[ADDR_WIDTH-1:0]];

    // Synchronize write pointer to the read clock domain
    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            wptr_sync_stage1 <= '0;
            wptr_sync        <= '0;
        end else begin
            wptr_sync_stage1 <= wptr_gray;
            wptr_sync        <= wptr_sync_stage1;
        end
    end

    // Empty condition logic: Compares the read pointer with the synchronized write pointer.
    assign rempty_internal = (rptr_gray == wptr_sync);
    assign rempty = rempty_internal;

endmodule

