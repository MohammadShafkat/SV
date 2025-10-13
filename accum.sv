// Code your design here
module accumulator #(
WIDTH = 32,
DEPTH = 16


)(
  logic clk,rst,

  bus_if#(.W(WIDTH,.D(DEPTH))).write write_if,
  bus_if#(.W(WIDTH,.D(DEPTH))).read  read_if

);
  
  logic signed [W:0] accum [D-1:0]
  typedef enum logic[1:0] {NOP, ADD, SET} W_state;
  
  W_state state_write;
  
  always_comb begin
    
    case(write_if.write_op)
      2'b00:  state_write = NOP;
      2'b01:  state_write = ADD;
      2'b10:  state_write = SET;
      default: state_write = NOP;
      
    endcase
    
  end
  
  always_ff(posedge clk) 
    
    begin
      
      if (state_write == ADD) begin
        accum[write_if.addr] <= accum[write_if.addr] + write_if.data;
        
      end
      
      if (state_write == SET) begin
        accum[write_if.addr] <= write_if.data;
        
      end
      
    end
  
    always_ff(posedge clk) 
    
    begin
      
      if (read_if.read_op) begin
        read_if.data <= accum[read_if.addr];
        
      end
      
      else  read_if.data <= WIDTH'sd0;
      
    end
  
  
endmodule






interface bus_if #(parameter W = 8, D=16) (input logic clk, input logic rst_n);
  logic[1:0]              write_op;
  logic              read_op;
  logic[D-1:0]       addr;
  logic signed [W-1:0]      data;

  // Master drives valid and data. Slave drives ready.
  modport write (input  write_op, addr, data);

  modport read  (input  read_op, addr,
                 output data);
endinterface
