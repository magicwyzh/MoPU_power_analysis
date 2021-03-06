module ACCFIFO_single #(parameter
ACCFIFO_size = 32,
data_width = 24 
)(
	input [data_width-1: 0] data_in,
	input compute_fifo_sel,
	input compute_fifo_read,
	input compute_fifo_write,
	input out_fifo_read,
	
	input clk, rst_n,
	output reg [data_width-1: 0] compute_fifo_out,
	output [data_width-1: 0] out_fifo_out
);
localparam AFIFO_size = ACCFIFO_size;
//reg out
assign out_fifo_out = compute_fifo_out;
wire [data_width-1: 0] compute_fifo_out_D;
wire [data_width-1: 0] out_fifo_out_D;
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		compute_fifo_out <= 0;
	end
	else begin
		compute_fifo_out <= compute_fifo_out_D;
	end
end

wire [data_width-1: 0] fifo0_out, fifo1_out;
wire fifo0_write, fifo0_read, fifo1_write, fifo1_read;
assign fifo0_write = compute_fifo_sel == 0 ? compute_fifo_write : 0;
assign fifo0_read = compute_fifo_sel == 0 ? compute_fifo_read : out_fifo_read;
assign fifo1_read = ~fifo0_read;
assign fifo1_write = compute_fifo_sel == 1 ? compute_fifo_write : 0;
assign compute_fifo_out_D = compute_fifo_sel == 0 ? fifo0_out : fifo0_out;
assign out_fifo_out_D = compute_fifo_sel == 0 ? fifo0_out :fifo0_out;
FIFO #(
    .nb_data               ( AFIFO_size                            ),
    .L_data                         ( data_width                            ),
    .SRAM_IMPL                      ( 1                             ))
ACCFIFO_0(
    .DataOut                        ( fifo0_out                       ),
    .stk_full                       (              ),
    .stk_almost_full                (              ),
    .stk_half_full                  (              ),
    .stk_almost_empty               (              ),
    .stk_empty                      (              ),
    .DataIn                         (  data_in     ),
    .write                          (  fifo0_write                         ),
    .read                           (  fifo0_read                          ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         )
);
/*
FIFO #(
    .nb_data               ( AFIFO_size                            ),
    .L_data                         ( data_width                            ),
    .SRAM_IMPL                      ( 1                             ))
ACCFIFO_1(
    .DataOut                        ( fifo1_out                       ),
    .stk_full                       (              ),
    .stk_almost_full                (              ),
    .stk_half_full                  (              ),
    .stk_almost_empty               (              ),
    .stk_empty                      (              ),
    .DataIn                         (  data_in     ),
    .write                          (  fifo1_write                         ),
    .read                           (  fifo1_read                          ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         )
);
*/
endmodule
