module PE_for_power_analysis #(parameter
	AFIFO_size = 16,
	ACCFIFO_size = 32,
	//parameters for FoFIR
	nb_taps = 5,
	activation_width = 16,
	compressed_act_width = activation_width + 1,
	weight_width = 16,
	tap_width = 24,
	weight_bpr_width = ((weight_width+1)/2)*3,
	act_bpr_width = ((activation_width+1)/2)*3,
	ETC_width = 4,
	width_current_tap = nb_taps > 8 ? 4 : 3,
	output_width = tap_width

)(
	input [compressed_act_width-1: 0] compressed_act_in,
	input [output_width-1: 0] out_fr_left_PE,
	
	/*************control signals for FoFIR************/
	//configuration ports
	input [4-1: 0] n_ap,

	//control ports for PAMAC
	input [3-1: 0] PAMAC_BPEB_sel,
	input PAMAC_DFF_en,
	input PAMAC_first_cycle,
	//the following two inputs are reserved 
	input PAMAC_MDecomp,//1 is mulwise, 0 is layerwise
	input PAMAC_AWDecomp,// 0 is act decomp, 1 is w decomp

	//control signals for FoFIR
	input [width_current_tap-1: 0] current_tap,
	//DRegs signals
	input [nb_taps-1: 0] DRegs_en,
	input [nb_taps-1: 0] DRegs_clr,
	input [nb_taps-1: 0] DRegs_in_sel,//0 is from left, 1 is from pamac output
	
	//DRegs indexing signals
	input index_update_en,

	//output signals
	input out_mux_sel,//0 is from PAMAC, 1 is from DRegs
	input out_reg_en,
	
	/**********Weight Ports for FoFIR********************/
	input [weight_width*nb_taps-1: 0] WRegs,
	input [weight_bpr_width*nb_taps-1: 0] WBPRs,
	input [ETC_width*nb_taps-1: 0] WETCs,
	
	/************Control Signals for FIFOs***************/
	input AFIFO_write, // for compute AFIFO
	input AFIFO_read, // for compute AFIFO
    output AFIFO_full, // for compute AFIFO
    output AFIFO_empty, // for compute AFIFO
    //for double afifos
    input [compressed_act_width-1: 0] shadow_AFIFO_data_in,
    input shadow_AFIFO_write,
    output upper_PE_shadow_afifo_write,
    input compute_AFIFO_read_delay_enable, // enable the upper_PE_shadow_afifo_write to be set a cycle after when its compute_AFIFO_read=1

	input ACCFIFO_write,
	input ACCFIFO_read_0,
    input ACCFIFO_read_1, 
	input out_mux_sel_PE,//
	input out_to_right_pe_en,	

    output [compressed_act_width-1: 0] afifo_data_out,
	//in the first accumulation, zero should be added
    input add_zero,
    input feed_zero_to_accfifo,
    input accfifo_head_to_tail,
    input which_accfifo_for_compute,
    input which_afifo_for_compute,
    
	input clk,
	input rst_n,
	output [width_current_tap-1: 0] PD0,
	output [output_width-1: 0] out_to_right_PE,
	output ACCFIFO_empty
	
);

wire [compressed_act_width-1: 0] compressed_act_fr_afifo;
wire [output_width-1: 0] FIR_out;
FoFIR #(
    .nb_taps			            ( nb_taps                             ),
    .activation_width               ( activation_width                            ),
    .weight_width                   ( weight_width                            ),
    .tap_width                      ( tap_width                            ),
    .ETC_width                      ( ETC_width                             ))
U_FOFIR_0(
    .WRegs                          ( WRegs                         ),
    .WBPRs                          ( WBPRs                         ),
    .WETCs                          ( WETCs                         ),
    .act_value                      ( compressed_act_fr_afifo[activation_width-1: 0]   ),
    .n_ap                           ( n_ap                          ),
    .PAMAC_BPEB_sel                 ( PAMAC_BPEB_sel                ),
    .PAMAC_DFF_en                   ( PAMAC_DFF_en                  ),
    .PAMAC_first_cycle              ( PAMAC_first_cycle             ),
    .PAMAC_MDecomp                  ( PAMAC_MDecomp                 ),
    .PAMAC_AWDecomp                 ( PAMAC_AWDecomp                ),
    .current_tap                    ( current_tap                   ),
    .DRegs_en                       ( DRegs_en                      ),
    .DRegs_clr                      ( DRegs_clr                     ),
    .DRegs_in_sel                   ( DRegs_in_sel                  ),
    .index_update_en                ( index_update_en               ),
    .out_mux_sel                    ( out_mux_sel                   ),
    .out_reg_en                     ( out_reg_en                    ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .PD0                            (  PD0                          ),
    .F                              ( FIR_out                             )
);


assign afifo_data_out = compressed_act_fr_afifo;
/*
FIFO #(
    .nb_data               ( AFIFO_size                            ),
    .L_data                         ( compressed_act_width                            ),
    .SRAM_IMPL                      ( 0                             ))
AFIFO(
    .DataOut                        ( compressed_act_fr_afifo                       ),
    .stk_full                       ( AFIFO_full             ),
    .stk_almost_full                (              ),
    .stk_half_full                  (              ),
    .stk_almost_empty               (              ),
    .stk_empty                      ( AFIFO_empty             ),
    .DataIn                         ( compressed_act_in                        ),
    .write                          ( AFIFO_write                         ),
    .read                           ( AFIFO_read                          ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         )
);
*/
wire delayed_compute_AFIFO_read;
assign upper_PE_shadow_afifo_write = delayed_compute_AFIFO_read;
double_AFIFO #(
    .nb_data               ( AFIFO_size                            ),
    .data_width                         ( compressed_act_width                            ),
    .SRAM_IMPL                      ( 0                             ))
u_double_AFIFO(
	.shadow_AFIFO_data_in            (shadow_AFIFO_data_in            ),
    .compute_AFIFO_data_in           (compressed_act_in           ),
    .shadow_AFIFO_write              (shadow_AFIFO_write              ),
    .compute_AFIFO_read              (AFIFO_read              ),
    .compute_AFIFO_write             (AFIFO_write             ),
    .delayed_compute_AFIFO_read      (delayed_compute_AFIFO_read      ),
    .compute_AFIFO_full              (AFIFO_full              ),
    .compute_AFIFO_empty             (AFIFO_empty             ),
    .compute_AFIFO_data_out          (compressed_act_fr_afifo          ),
    .which_AFIFO_for_compute         (which_afifo_for_compute         ),
    .compute_AFIFO_read_delay_enable (compute_AFIFO_read_delay_enable ),
    .clk                             (clk                             ),
    .rst_n                           (rst_n                           )
);

wire [output_width-1: 0] ACCFIFO_out_for_compute, adder_out, ACCFIFO_out_for_global;
//assign ACCFIFO_out_for_global = accfifo_out;
//assign ACCFIFO_out_for_compute = accfifo_out;
assign adder_out = FIR_out + (add_zero == 0 ? ACCFIFO_out_for_compute : 0);
reg [output_width-1: 0] accfifo_data_in;
always@(*) begin
    case({feed_zero_to_accfifo, accfifo_head_to_tail})
        2'b00: begin
            accfifo_data_in = adder_out;
        end
        2'b01: begin 
            accfifo_data_in = ACCFIFO_out_for_compute;
        end
        2'b10: begin 
            accfifo_data_in = 0;
        end
        default: begin 
            accfifo_data_in = 0;
        end
    endcase
end
/*
wire accfifo_read_final;
assign accfifo_read_final = (ACCFIFO_read_ctrl_src_sel == 1'b0)? ACCFIFO_read_0:ACCFIFO_read_1;
FIFO #(
    .nb_data               ( ACCFIFO_size                            ),
    .L_data                         ( output_width                            ),
    .SRAM_IMPL                      ( 1                             ))
ACCFIFO_0(
    .DataOut                        ( accfifo_out                       ),
    .stk_full                       (              ),
    .stk_almost_full                (              ),
    .stk_half_full                  (              ),
    .stk_almost_empty               (              ),
    .stk_empty                      ( ACCFIFO_empty             ),
    .DataIn                         (  accfifo_data_in     ),
    .write                          (  ACCFIFO_write                         ),
    .read                           ( accfifo_read_final ),
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         )
);
*/
double_ACCFIFO #(
    .nb_data(ACCFIFO_size),
    .output_width(output_width),
    .SRAM_IMPL(1)
)
    u_double_ACCFIFO(
	.data_in               (accfifo_data_in               ),
    .compute_fifo_write    (ACCFIFO_write    ),
    .compute_fifo_read     (ACCFIFO_read_0     ),
    .shadow_fifo_read      (ACCFIFO_read_1      ),
    .which_fifo_to_compute (which_accfifo_for_compute ),
    .compute_fifo_data_out (ACCFIFO_out_for_compute ),
    .shadow_fifo_data_out  (ACCFIFO_out_for_global  ),
    .shadow_fifo_empty     (ACCFIFO_empty     ),
    .clk                   (clk                   ),
    .rst_n                 (rst_n                 )
);




MUX_DFF_en #(
    .data_width            ( output_width                            ))
U_MUX_DFF_0(
    .in1                            ( ACCFIFO_out_for_global                           ),
    .in2                            ( out_fr_left_PE                           ),
    .sel                            ( out_mux_sel_PE                           ),
    .out                            ( out_to_right_PE                           ),
	.clk							( clk),
	.rst_n							(rst_n),
	.en								( out_to_right_pe_en)
);

endmodule
