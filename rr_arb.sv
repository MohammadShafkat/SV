// Code your design here
module arb #(WIDTH = 4)
  
  (
  input     logic      clk,
  input     logic      reset,

    input    logic[WIDTH-1:0] request,
    output   logic[WIDTH-1:0] grant
  
);
  
  
  
  logic [$clog2(WIDTH)-1:0] last_grant;
  logic[WIDTH-1:0] pointer;
  
  always@(posedge clk) begin
    
    if (reset)begin
      
      grant <= 0;
      last_grant <= 0;
      pointer<=0;
      
    end
    
    else begin
      grant <= pointer;
      pointer =0;
      repeat (WIDTH) begin
        last_grant = (last_grant == WIDTH-1)? 0:last_grant +1 ;
        if (request[last_grant]) begin 
          pointer[last_grant] = 1;
          
          break;
        end
     
      
        
        
      end
        
      
      
    end
    
  end
  
  
endmodule
  
