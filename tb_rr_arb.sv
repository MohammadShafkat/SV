`timescale 1ns/1ps

module tb_arb;

  localparam int WIDTH = 4;

  // DUT I/O
  logic                 clk;
  logic                 reset;
  logic [WIDTH-1:0]     request,request_d;
  wire  [WIDTH-1:0]     grant;

  // Instantiate DUT
  arb #(.WIDTH(WIDTH)) dut (
    .clk(clk),
    .reset(reset),
    .request(request),
    .grant(grant)
  );

  // Clock
  initial clk = 0;
  always #5 clk = ~clk;  // 100 MHz

  // Reset
  initial begin
    reset   = 1;
    request = '0;
    repeat (3) @(posedge clk);
    reset = 0;
  end

  // Simple monitor
  always @(posedge clk) begin
    request_d<= request;
    if (!reset) begin
      $display("[%0t] req=%b  grant=%b", $time, request, grant);
      // One hot or zero check
      if (!$onehot0(grant)) begin
        $error("Grant is not one hot or zero at time %0t. grant=%b", $time, grant);
      end
      // Grant must be subset of request
      if ((grant & ~request_d) != 0) begin
        $error("Grant is asserted for a non requesting channel at time %0t. req=%b grant=%b", $time, request_d, grant);
      end
    end
  end

  // Stimulus
  initial begin
    // Wait for reset to deassert
    @(negedge reset);

    // Directed patterns
    drive_req(4'b0000, 3);  // no requests
    drive_req(4'b0001, 4);
    drive_req(4'b0010, 4);
    drive_req(4'b0100, 4);
    drive_req(4'b1000, 4);

    // Multiple simultaneous requesters
    drive_req(4'b0011, 8);
    drive_req(4'b0110, 8);
    drive_req(4'b1101, 8);
    drive_req(4'b1111, 12);

    // Randomized phase
    repeat (40) begin
      drive_req($urandom_range(0, 2**WIDTH - 1), 2);
    end

    // Idle tail
    drive_req(4'b0000, 5);

    $display("Test completed at %0t", $time);
    $finish;
  end

  // Helper task to hold a request pattern for N cycles
  task drive_req(input logic [WIDTH-1:0] r, input int cycles);
    begin
      request = r;
      repeat (cycles) @(posedge clk);
    end
  endtask

endmodule
