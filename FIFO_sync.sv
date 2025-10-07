// =============================================================================
// Module: sync_fifo
// Description: Synchronous First-In, First-Out (FIFO) buffer.
//              Uses a single clock for both read and write operations.
//              Allows simultaneous read and write operations.
// =============================================================================
module sync_fifo #(
    parameter DATA_WIDTH = 8,  // Width of data bus
    parameter ADDR_WIDTH = 4   // Number of address bits (Depth = 2^ADDR_WIDTH)
)(
    input  logic              clk,     // Global clock signal
    input  logic              rst,     // Synchronous active-high reset

    // Write Interface
    input  logic [DATA_WIDTH-1:0] din,   // Data input
    input  logic              wr_en,   // Write enable signal
    output logic              full,    // FIFO full indicator

    // Read Interface
    output logic [DATA_WIDTH-1:0] dout,  // Data output
    input  logic              rd_en,   // Read enable signal
    output logic              empty    // FIFO empty indicator
);

    // Local Parameters
    localparam DEPTH = 1 << ADDR_WIDTH; // FIFO depth (e.g., 2^4 = 16)
    
    // Internal Memory (Implemented using an array of registers)
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers for Read and Write operations (ADDR_WIDTH + 1 bits wide)
    logic [ADDR_WIDTH:0] wr_ptr_reg, rd_ptr_reg; 

    // Internal Signals for Next Pointers (Combinational Logic)
    logic [ADDR_WIDTH:0] wr_ptr_next, rd_ptr_next; 
    
    // FIFO Occupancy Count (For logic clarity and status generation)
    // The counter is explicitly tracked to simplify the full/empty logic,
    // especially for simultaneous operations.
    logic [ADDR_WIDTH:0] count_reg, count_next; 

    // =======================================================
    // 1. Status Flags
    // =======================================================
    // EMPTY: True when count is zero.
    assign empty = (count_reg == '0);

    // FULL: True when count equals the total depth.
    assign full = (count_reg == DEPTH);


    // =======================================================
    // 2. Next Count Calculation (Combinational Logic)
    //    This is where the simultaneous R/W is handled cleanly.
    // =======================================================
    always_comb begin
        
        // Default: No change
        count_next = count_reg;
        
        // Flags indicating successful operation attempt
        // Note: The logic below implicitly implements the priority: 
        //       Write only happens if NOT full. Read only happens if NOT empty.
        
        logic do_write = wr_en && !full;
        logic do_read  = rd_en && !empty;
        
        // Calculate the net change to the count
        if (do_write && !do_read) begin      // Only Write occurred
            count_next = count_reg + 1;
        end else if (!do_write && do_read) begin // Only Read occurred
            count_next = count_reg - 1;
        end 
        // If (do_write && do_read) occurs, net change is 0, so count_next = count_reg;
        // If (!do_write && !do_read) occurs, net change is 0, so count_next = count_reg;
    end

    // =======================================================
    // 3. Next Pointer Calculation (Combinational Logic)
    // =======================================================
    always_comb begin
        wr_ptr_next = wr_ptr_reg;
        rd_ptr_next = rd_ptr_reg;

        // Write Pointer Update: Must rely on the calculated 'do_write' signal
        if (wr_en && !full) begin // A successful write moves the pointer
            wr_ptr_next = wr_ptr_reg + 1;
        end

        // Read Pointer Update: Must rely on the calculated 'do_read' signal
        if (rd_en && !empty) begin // A successful read moves the pointer
            rd_ptr_next = rd_ptr_reg + 1;
        end
    end

    // =======================================================
    // 4. Sequential Logic (Pointers and Count)
    // =======================================================
    always @(posedge clk) begin
        if (rst) begin
            wr_ptr_reg  <= '0;
            rd_ptr_reg  <= '0;
            count_reg   <= '0;
        end else begin
            // Update pointers and count based on combinational next values
            wr_ptr_reg  <= wr_ptr_next;
            rd_ptr_reg  <= rd_ptr_next;
            count_reg   <= count_next;
        end
    end

    // =======================================================
    // 5. Memory Write Logic
    // =======================================================
    always @(posedge clk) begin
        // Use the condition for a successful write
        if (wr_en && !full) begin
            // The memory address used is the current pointer's lower ADDR_WIDTH bits
            mem[wr_ptr_reg[ADDR_WIDTH-1:0]] <= din;
        end
    end

    // =======================================================
    // 6. Read Logic (Output)
    // =======================================================
    // dout is registered. Data is read *before* the pointer is incremented.
    always @(posedge clk) begin
        // Use the condition for a successful read
        if (rd_en && !empty) begin
            // Read from the memory location pointed to by the current read pointer
            dout <= mem[rd_ptr_reg[ADDR_WIDTH-1:0]];
        end 
    end

    // =======================================================
    // 7. Memory Reset Logic (Initialize memory to 0)
    // =======================================================
    always @(posedge clk) begin
        if (rst) begin
            // Use a blocking assignment loop for synchronous reset initialization
            for (int i = 0; i < DEPTH; i++) begin
                mem[i] <= '0;
            end
        end
    end

endmodule
