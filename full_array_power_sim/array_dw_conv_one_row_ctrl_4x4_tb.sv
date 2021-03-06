`timescale 1ns/1ns
module array_dw_conv_one_row_ctrl_4x4_tb #(parameter 
    num_pe_row = 4,
    num_pe_col = 4,
    total_num_pe = num_pe_row * num_pe_col,
    //parameters for PE and FoFIR
	nb_taps = 11,
	activation_width = 16,
	compressed_act_width = activation_width + 1,
	weight_width = 16,
	tap_width = 24,
	weight_bpr_width = ((weight_width+1)/2)*3,
	act_bpr_width = ((activation_width+1)/2)*3,
	ETC_width = 4,
	width_current_tap = nb_taps > 8 ? 4 : 3,
	output_width = tap_width
    )();

           /**** Ports to control the PE array (started with ``pe_ctrl/data")*****/
        // AFIFO data
        logic [num_pe_row-1: 0][compressed_act_width-1: 0] pe_data_compressed_act_in;
        logic [num_pe_col-1: 0][compressed_act_width-1: 0] pe_data_last_row_shadow_AFIFO_data_in;
    // configuration
        logic [total_num_pe-1: 0][4-1: 0] pe_ctrl_n_ap;
    // control ports for PAMAC
        logic [total_num_pe-1: 0][3-1: 0] pe_ctrl_PAMAC_BPEB_sel;
        logic [total_num_pe-1: 0] pe_ctrl_PAMAC_DFF_en;
        logic [total_num_pe-1: 0] pe_ctrl_PAMAC_first_cycle;
        logic [total_num_pe-1: 0] pe_ctrl_PAMAC_MDecomp;
        logic [total_num_pe-1: 0] pe_ctrl_PAMAC_AWDecomp;
    // control ports for FoFIR
        logic [total_num_pe-1: 0][width_current_tap-1: 0] pe_ctrl_current_tap;
        logic [total_num_pe-1: 0][nb_taps-1: 0] pe_ctrl_DRegs_en;
        logic [total_num_pe-1: 0][nb_taps-1: 0] pe_ctrl_DRegs_clr;
        logic [total_num_pe-1: 0][nb_taps-1: 0] pe_ctrl_DRegs_in_sel;
        logic [total_num_pe-1: 0] pe_ctrl_index_update_en;
        logic [total_num_pe-1: 0] pe_ctrl_out_mux_sel;
        logic [total_num_pe-1: 0] pe_ctrl_out_reg_en;
    // control ports for FIFOs
        logic [total_num_pe-1: 0] pe_ctrl_AFIFO_write;
        logic [total_num_pe-1: 0] pe_ctrl_AFIFO_read; 
        logic [total_num_pe-1: 0] pe_ctrl_ACCFIFO_write;
        logic [total_num_pe-1: 0] pe_ctrl_ACCFIFO_read;
        logic [total_num_pe-1: 0] pe_ctrl_ACCFIFO_read_to_outbuffer;
        logic [total_num_pe-1: 0] pe_ctrl_out_mux_sel_PE;//
        logic [total_num_pe-1: 0] pe_ctrl_out_to_right_pe_en;	
        logic [total_num_pe-1: 0] pe_ctrl_add_zero;
        logic [total_num_pe-1: 0] pe_ctrl_feed_zero_to_accfifo;
        logic [total_num_pe-1: 0] pe_ctrl_accfifo_head_to_tail;
        logic [total_num_pe-1: 0] pe_ctrl_which_accfifo_for_compute;
        logic [num_pe_col-1: 0] pe_ctrl_last_row_shadow_AFIFO_write;
        logic [total_num_pe-1: 0] pe_ctrl_compute_AFIFO_read_delay_enable;
        logic [total_num_pe-1: 0] pe_ctrl_which_afifo_for_compute;
    /**** End of Ports to control the PE array***/

    /**** Ports from PE array for some info ****/
        logic [total_num_pe-1: 0][width_current_tap-1: 0] pe_ctrl_PD0;
        logic [total_num_pe-1: 0] pe_ctrl_AFIFO_full;
        logic [total_num_pe-1: 0] pe_ctrl_AFIFO_empty;
        logic [total_num_pe-1: 0][compressed_act_width-1: 0] pe_data_afifo_out;
    /**** End of Ports from PE array for some info****/

    /**** Ports of some weights info*****************/
        logic [num_pe_col-1: 0][weight_width*nb_taps-1: 0] WRegs;
        logic [num_pe_col-1: 0][weight_bpr_width*nb_taps-1: 0] WBPRs;
        logic [num_pe_col-1: 0][ETC_width*nb_taps-1: 0] WETCs;
    /**** End of ports for weights info**************/

    /**** Transactions with global scheduler *******/
        logic clk;
        int kernel_size; 
        int quantized_bits; 
        logic first_acc_flag;
        logic [4-1:0] n_ap;
        logic rst_n;
        logic [num_pe_row-1: 0][output_width-1:0] out_fr_rightest_PE_even_col;
        logic [num_pe_row-1: 0][output_width-1:0] out_fr_rightest_PE_odd_col;
        logic [total_num_pe-1: 0] pe_ctrl_ACCFIFO_empty;
    /**** End of Transactions with global scheduler*****/



    ArrayConvOneRowCtrl #(
        .num_pe_col(num_pe_col),
        .num_pe_row(num_pe_row))
    DUT_Ctrl(
    	.pe_data_compressed_act_in    (pe_data_compressed_act_in    ),
        .pe_data_last_row_shadow_AFIFO_data_in (pe_data_last_row_shadow_AFIFO_data_in),
        .pe_ctrl_n_ap                 (pe_ctrl_n_ap                 ),
        .pe_ctrl_PAMAC_BPEB_sel       (pe_ctrl_PAMAC_BPEB_sel       ),
        .pe_ctrl_PAMAC_DFF_en         (pe_ctrl_PAMAC_DFF_en         ),
        .pe_ctrl_PAMAC_first_cycle    (pe_ctrl_PAMAC_first_cycle    ),
        .pe_ctrl_PAMAC_MDecomp        (pe_ctrl_PAMAC_MDecomp        ),
        .pe_ctrl_PAMAC_AWDecomp       (pe_ctrl_PAMAC_AWDecomp       ),
        .pe_ctrl_current_tap          (pe_ctrl_current_tap          ),
        .pe_ctrl_DRegs_en             (pe_ctrl_DRegs_en             ),
        .pe_ctrl_DRegs_clr            (pe_ctrl_DRegs_clr            ),
        .pe_ctrl_DRegs_in_sel         (pe_ctrl_DRegs_in_sel         ),
        .pe_ctrl_index_update_en      (pe_ctrl_index_update_en      ),
        .pe_ctrl_out_mux_sel          (pe_ctrl_out_mux_sel          ),
        .pe_ctrl_out_reg_en           (pe_ctrl_out_reg_en           ),
        .pe_ctrl_AFIFO_write          (pe_ctrl_AFIFO_write          ),
        .pe_ctrl_AFIFO_read           (pe_ctrl_AFIFO_read           ),
        .pe_ctrl_ACCFIFO_write        (pe_ctrl_ACCFIFO_write        ),
        .pe_ctrl_ACCFIFO_read         (pe_ctrl_ACCFIFO_read         ),
        .pe_ctrl_ACCFIFO_read_to_outbuffer (pe_ctrl_ACCFIFO_read_to_outbuffer),
        .pe_ctrl_out_mux_sel_PE       (pe_ctrl_out_mux_sel_PE       ),
        .pe_ctrl_out_to_right_pe_en   (pe_ctrl_out_to_right_pe_en   ),
        .pe_ctrl_add_zero             (pe_ctrl_add_zero             ),
        .pe_ctrl_feed_zero_to_accfifo (pe_ctrl_feed_zero_to_accfifo ),
        .pe_ctrl_accfifo_head_to_tail (pe_ctrl_accfifo_head_to_tail ),
        .pe_ctrl_last_row_shadow_AFIFO_write (pe_ctrl_last_row_shadow_AFIFO_write),
        .pe_ctrl_PD0                  (pe_ctrl_PD0                  ),
        .pe_ctrl_AFIFO_full           (pe_ctrl_AFIFO_full           ),
        .pe_ctrl_AFIFO_empty          (pe_ctrl_AFIFO_empty          ),
        .pe_data_afifo_out            (pe_data_afifo_out            ),
        .pe_ctrl_ACCFIFO_empty        (pe_ctrl_ACCFIFO_empty),
        .WRegs                        (WRegs                        ),
        .WBPRs                        (WBPRs                        ),
        .WETCs                        (WETCs                        ),
        .clk                          (clk                          ),
        .kernel_size                  (kernel_size                  ),
        .quantized_bits               (quantized_bits               ),
        .first_acc_flag               (first_acc_flag               ),
        .n_ap                         (n_ap                         )
    );
    
    PEArray_for_power_analysis #(
            .num_pe_row(num_pe_row),
            .num_pe_col(num_pe_col))
        u_PEArray_for_power_analysis(
    	.pe_data_compressed_act_in    (pe_data_compressed_act_in    ),
        .pe_data_last_row_shadow_AFIFO_data_in (pe_data_last_row_shadow_AFIFO_data_in),
        .pe_ctrl_n_ap                 (pe_ctrl_n_ap                 ),
        .pe_ctrl_PAMAC_BPEB_sel       (pe_ctrl_PAMAC_BPEB_sel       ),
        .pe_ctrl_PAMAC_DFF_en         (pe_ctrl_PAMAC_DFF_en         ),
        .pe_ctrl_PAMAC_first_cycle    (pe_ctrl_PAMAC_first_cycle    ),
        .pe_ctrl_PAMAC_MDecomp        (pe_ctrl_PAMAC_MDecomp        ),
        .pe_ctrl_PAMAC_AWDecomp       (pe_ctrl_PAMAC_AWDecomp       ),
        .pe_ctrl_current_tap          (pe_ctrl_current_tap          ),
        .pe_ctrl_DRegs_en             (pe_ctrl_DRegs_en             ),
        .pe_ctrl_DRegs_clr            (pe_ctrl_DRegs_clr            ),
        .pe_ctrl_DRegs_in_sel         (pe_ctrl_DRegs_in_sel         ),
        .pe_ctrl_index_update_en      (pe_ctrl_index_update_en      ),
        .pe_ctrl_out_mux_sel          (pe_ctrl_out_mux_sel          ),
        .pe_ctrl_out_reg_en           (pe_ctrl_out_reg_en           ),
        .pe_ctrl_AFIFO_write          (pe_ctrl_AFIFO_write          ),
        .pe_ctrl_AFIFO_read           (pe_ctrl_AFIFO_read           ),
        .pe_ctrl_ACCFIFO_write        (pe_ctrl_ACCFIFO_write        ),
        .pe_ctrl_ACCFIFO_read         (pe_ctrl_ACCFIFO_read         ),
        .pe_ctrl_ACCFIFO_read_to_outbuffer         (pe_ctrl_ACCFIFO_read_to_outbuffer         ),
        .pe_ctrl_out_mux_sel_PE       (pe_ctrl_out_mux_sel_PE       ),
        .pe_ctrl_out_to_right_pe_en   (pe_ctrl_out_to_right_pe_en   ),
        .pe_ctrl_add_zero             (pe_ctrl_add_zero             ),
        .pe_ctrl_feed_zero_to_accfifo (pe_ctrl_feed_zero_to_accfifo ),
        .pe_ctrl_accfifo_head_to_tail (pe_ctrl_accfifo_head_to_tail ),
        .pe_ctrl_last_row_shadow_AFIFO_write (pe_ctrl_last_row_shadow_AFIFO_write),
        .pe_ctrl_which_afifo_for_compute(pe_ctrl_which_afifo_for_compute),
        .pe_ctrl_compute_AFIFO_read_delay_enable(pe_ctrl_compute_AFIFO_read_delay_enable),
        .pe_ctrl_which_accfifo_for_compute(pe_ctrl_which_accfifo_for_compute),
        .pe_ctrl_PD0                  (pe_ctrl_PD0                  ),
        .pe_ctrl_AFIFO_full           (pe_ctrl_AFIFO_full           ),
        .pe_ctrl_AFIFO_empty          (pe_ctrl_AFIFO_empty          ),
        .pe_data_afifo_out            (pe_data_afifo_out            ),
        .WRegs                        (WRegs                        ),
        .WBPRs                        (WBPRs                        ),
        .WETCs                        (WETCs                        ),
        .out_fr_rightest_PE_even_col  (out_fr_rightest_PE_even_col),
        .out_fr_rightest_PE_odd_col   (out_fr_rightest_PE_odd_col),
        .pe_ctrl_ACCFIFO_empty        (pe_ctrl_ACCFIFO_empty        ),
        .n_ap                         (n_ap                         ),
        .clk                          (clk                          ),
        .rst_n                        (rst_n                        )
    );
    
    initial begin
        clk = 0;
        forever 
            #10 clk = ~clk;
    end
    /**Init something**/
    initial begin
        pe_ctrl_which_accfifo_for_compute = 0;
        //array_conv_one_row_start = 0;
        kernel_size = 3;
        quantized_bits = 8;
        first_acc_flag = 0;
        n_ap = 0;
        rst_n = 1;
        WRegs = 0;
        WETCs = 0;
        WBPRs = 0;
        pe_ctrl_which_afifo_for_compute = 0;
        pe_ctrl_compute_AFIFO_read_delay_enable = 0;
    end

    /*** some signals for easy debuggging**/
    logic is_loading_fr_accfifo;
    logic is_convolving;

    logic [weight_width: 0] weights[3*3];
    /**Main***/
    task load_weights_fr_file();
        int n, fp, pix;
        logic [weight_width-1: 0] r;
        pix = 0;
        fp = $fopen("C:/Users/dell/Desktop/mopu-testbench/full_array_power_sim/weights.dat","r");
        while(!$feof(fp)) begin
            n = $fscanf(fp, "%x\n", r);
            weights[pix] = r;
            pix++;
        end
    endtask
    task load_WRegs(input int krow);
        for(int cc = 0; cc<num_pe_col; cc++) begin
            for(int i = 0; i < kernel_size; i++) begin
                WRegs[cc][i*weight_width+:weight_width] = weights[krow*3+i];
                BPEB_Enc_task(
                    WRegs[cc][i*weight_width +: weight_width], /*in*/
                    n_ap, 
                    WBPRs[cc][i*weight_bpr_width +: weight_bpr_width], /**encoded results**/
                    WETCs[cc][i*ETC_width +: ETC_width]
                );
            end
        end
    endtask


    // Here the weights of 3 kernel rows should all have non-zero weights
    // Need to provide another dw_conv function that will peek the following krows
    // or just take care of all kernel rows and make up a control schedule
    // so that unnecessary inner Array data transfer is avoided and ensure the compute sequence 
    // is correct.
    task dw_conv(
        input int infm2d_start_row
    );
        load_WRegs(0);
        if(WETCs[0] == 0) begin
                $stop("There is one kernel_row with all zero!");
                $stop;
        end
        pe_ctrl_compute_AFIFO_read_delay_enable = {total_num_pe{1'b1}};
        first_acc_flag = 1;
        $display("@%t, Kernel_row = 0 start",$time);
        fork
            DUT_Ctrl.load_infm2d_to_array_accord_workload(infm2d_start_row);
            DUT_Ctrl.array_dw_conv_one_row_task(1);
            DUT_Ctrl.feed_last_pe_row_shadow_afifo(infm2d_start_row+num_pe_row);
        join
        
        @(posedge clk);
        first_acc_flag = 0;
        for(int krow=1; krow<kernel_size;krow++) begin
            load_WRegs(krow);
            if(WETCs[0] == 0) begin
                $stop("There is one kernel_row with all zero!");
                $stop;
            end
            $display("@%t, Kernel_row = %d start",$time, krow);
            pe_ctrl_which_afifo_for_compute = ~pe_ctrl_which_afifo_for_compute;
            pe_ctrl_compute_AFIFO_read_delay_enable = krow==(kernel_size-1)? 0 : {total_num_pe{1'b1}}; 
            fork
                DUT_Ctrl.array_dw_conv_one_row_task(0);
                begin
                    if(krow!=kernel_size-1) begin
                        DUT_Ctrl.feed_last_pe_row_shadow_afifo(infm2d_start_row+num_pe_row+krow);
                    end
                end
            join
        end
        first_acc_flag = 0;
        pe_ctrl_compute_AFIFO_read_delay_enable = 0;
    endtask
    initial begin
        string image_file_path;
        is_loading_fr_accfifo = 0;
        is_convolving = 0;
        image_file_path = "C:/Users/dell/Desktop/mopu-testbench/full_array_power_sim/image.dat";
        load_weights_fr_file();
        pe_ctrl_which_accfifo_for_compute = 0;
        pe_ctrl_which_afifo_for_compute = 0;
        DUT_Ctrl.load_infm2d_from_file(
            image_file_path,
            32,
            32
        );
        #5;
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        pe_ctrl_which_accfifo_for_compute = 0;
        DUT_Ctrl.dw_conv_pe_workload_gen(
            32, //inp_col_size
            1, //stride
            3//kernel_size
        );
        is_convolving = 1;
        dw_conv(0); //start conv.
        is_convolving = 0;
        pe_ctrl_which_accfifo_for_compute = ~pe_ctrl_which_accfifo_for_compute;
        repeat(5) begin
            @(posedge clk);
        end
        fork
            begin
                is_loading_fr_accfifo = 1;
                DUT_Ctrl.array_give_out_results();
                is_loading_fr_accfifo = 0;
            end
            begin
                is_convolving = 1;
                dw_conv(num_pe_row);
                is_convolving = 0;
            end
        join
        repeat(5) begin
            @(posedge clk);
        end
        pe_ctrl_which_accfifo_for_compute = ~pe_ctrl_which_accfifo_for_compute;

        is_loading_fr_accfifo = 1;
        DUT_Ctrl.array_give_out_results();
        is_loading_fr_accfifo = 0;

        $finish;

    end

    task BPEB_Enc_task(
        input [16-1: 0] in,
        input [4-1: 0] n_ap,
        output [8*3-1: 0] encoded_result,
        output [4-1: 0] ETC
        
    ); 
    begin
        for(int i = 0; i < 8; i++ ) begin
            if(i >= n_ap) begin
                encoded_result[3*i+1] = in[2*i];
                encoded_result[3*i+2] = in[2*i+1];
                encoded_result[3*i] = i==0 ? 0 : in[2*i-1];
            end
            else begin
                //abandoned terms
                encoded_result[3*i+2 -: 3] = 3'b000;
            end
        end
    
        ETC = 0;
        for(int t=0; t < 8; t++) begin
            if(encoded_result[3*(t+1)-1 -: 3] != 3'b000 && encoded_result[3*(t+1)-1 -: 3] != 3'b111) begin
                ETC += 1;
            end
        end
    end
    endtask
    
    
endmodule