`timescale 1ns / 1ps



module st7789_mgr (
    input  logic       CLK          ,
    input  logic       RESET        ,
    input  logic       RUN          ,
    // input  logic [7:0] OPERATION    ,
    input  logic [7:0] COMPONENT_R  ,
    input  logic [7:0] COMPONENT_G  ,
    input  logic [7:0] COMPONENT_B  ,
    output logic [7:0] M_AXIS_TDATA ,
    output logic       M_AXIS_TKEEP ,
    output logic       M_AXIS_TUSER ,
    output logic       M_AXIS_TVALID,
    output logic       M_AXIS_TLAST ,
    input  logic       M_AXIS_TREADY
);

    localparam PIXEL_LIMIT = 172800;
    localparam PAUSE_SIZE = 50000000;


    typedef enum {
        RESET_ST                ,
        PAUSE_ST                ,
        IDLE_ST                 ,
        RESET_SW_ST             ,
        SLEEP_OUT_ST            ,
        RAM_WR_CMD_ST           ,
        // RAM_WR_CONTINUE_CMD_ST  ,
        RAM_WR_DATA_ST          ,
        INC_RGB_ST              ,
        CASET_ST                , 
        RASET_ST                ,
        INVON_ST                ,
        DISPON_ST 

    } fsm;

    fsm current_state = RESET_ST;

    logic [7:0] out_din_data = '{default:0};
    logic       out_din_keep = 1'b0        ;
    logic       out_din_user = 1'b0        ;
    logic       out_din_last = 1'b0        ;
    logic       out_wren     = 1'b0        ;
    logic       out_full                   ;
    logic       out_awfull                 ;


    // logic d_run = 1'b0;
    // logic run_event;


    logic [                   31:0] word_counter  = '{default:0};
    logic [$clog2(PIXEL_LIMIT):0] pixel_counter = '{default:0};
    logic [ $clog2(PAUSE_SIZE):0] pause_counter = '{default:0};

    logic [23:0] rgb_reg ;

    // always_ff @(posedge CLK) begin 
    //     d_run <= RUN; 
    // end 

    // always_comb begin 
    //     run_event = (~d_run) & RUN;
    // end 

    always_ff @(posedge CLK) begin 
        if (RESET)
            current_state <= RESET_ST;
        else 
            case (current_state)

                RESET_ST : 
                    current_state <= RESET_SW_ST;


                RESET_SW_ST : 
                    if (!out_awfull)
                        current_state <= PAUSE_ST;

                PAUSE_ST : 
                    if (pause_counter  < PAUSE_SIZE-1) 
                        current_state <= current_state;
                    else 
                        current_state <= SLEEP_OUT_ST;


                SLEEP_OUT_ST : 
                    if (!out_awfull)
                        current_state <= INVON_ST;

                INVON_ST : 
                    if (!out_awfull) 
                        current_state <= DISPON_ST;

                DISPON_ST : 
                    if (!out_awfull) 
                        current_state <= CASET_ST;

                CASET_ST : 
                    if (word_counter == 4)
                        current_state <=  RASET_ST;

                RASET_ST : 
                    if (word_counter == 4)
                        current_state <=  IDLE_ST;

                IDLE_ST : 
                    if (RUN)
                        current_state <= RAM_WR_CMD_ST;
                    else
                        current_state <= current_state;
                    // if (run_event)
                        // case (OPERATION)
                        // 8'h2C : current_state <= RAM_WR_CMD_ST;
                            // 8'h3C : current_state <= RAM_WR_CONTINUE_CMD_ST;
                            // default: current_state <= current_state;
                        // endcase // OPERATION

                RAM_WR_CMD_ST : 
                    if (!out_awfull) 
                        current_state <= RAM_WR_DATA_ST;


                // RAM_WR_CONTINUE_CMD_ST : 
                //     if (!out_awfull) 
                //         current_state <= RAM_WR_DATA_ST;

                RAM_WR_DATA_ST:
                    if (!out_awfull) 
                        if (pixel_counter == PIXEL_LIMIT-1)
                            current_state <= INC_RGB_ST;

                INC_RGB_ST : 
                    if (RUN)
                        if (pause_counter < PAUSE_SIZE-1)
                            current_state <= current_state;
                        else 
                            current_state <= RAM_WR_CMD_ST;
                    else 
                        current_state <= IDLE_ST;

                default : 
                    current_state <= IDLE_ST;

            endcase // current_state

    end     



    always_ff @(posedge CLK) begin 
        case (current_state)

            IDLE_ST : 
                rgb_reg <= {COMPONENT_R, COMPONENT_G, COMPONENT_B};

            INC_RGB_ST : 
                if (pause_counter == PAUSE_SIZE-1)
                    rgb_reg <= {rgb_reg[22:0], rgb_reg[23]};

            default: 
                rgb_reg <= rgb_reg;

        endcase // current_state
    end



    always_ff @(posedge CLK) begin 
        case (current_state)
            RESET_SW_ST : 
                out_din_data <= 8'h01;

            SLEEP_OUT_ST : 
                out_din_data <= 8'h11;

            RAM_WR_CMD_ST: 
                out_din_data <= 8'h2C;            

            // RAM_WR_CONTINUE_CMD_ST : 
            //     out_din_data <= 8'h3C;         

            RAM_WR_DATA_ST :
                case (word_counter)
                    'd0 : out_din_data <= rgb_reg[23:16];
                    'd1 : out_din_data <= rgb_reg[15: 8];
                    'd2 : out_din_data <= rgb_reg[ 7: 0];
                    default : out_din_data <= out_din_data;
                endcase


            RASET_ST : 
                case (word_counter)
                    'd0 : out_din_data <= 8'h2B;
                    'd1 : out_din_data <= 8'h00;
                    'd2 : out_din_data <= 8'h00;
                    'd3 : out_din_data <= 8'h00;
                    'd4 : out_din_data <= 8'hEF;
                    default : out_din_data <= out_din_data;
                endcase

            CASET_ST : 
                case (word_counter)
                    'd0 : out_din_data <= 8'h2A;
                    'd1 : out_din_data <= 8'h00;
                    'd2 : out_din_data <= 8'h00;
                    'd3 : out_din_data <= 8'h00;
                    'd4 : out_din_data <= 8'hEF;
                    default : out_din_data <= out_din_data;
                endcase


            INVON_ST: 
                out_din_data <= 8'h21;            

            DISPON_ST: 
                out_din_data <= 8'h29;            

        endcase // current_state
    end 


    always_ff @(posedge CLK) begin 
        case (current_state)
            RESET_SW_ST : 
                out_din_user <= 1'b0;

            SLEEP_OUT_ST : 
                out_din_user <= 1'b0;

            RAM_WR_CMD_ST : 
                out_din_user <= 1'b0;

            // RAM_WR_CONTINUE_CMD_ST:
            //     out_din_user <= 1'b0;

            RAM_WR_DATA_ST : 
                out_din_user <= 1'b1;

            INVON_ST : 
                out_din_user <= 1'b0;

            DISPON_ST : 
                out_din_user <= 1'b0;

            RASET_ST : 
                if (word_counter == 0)
                    out_din_user <= 1'b0;
                else
                    out_din_user <= 1'b1;

            CASET_ST : 
                if (word_counter == 0)
                    out_din_user <= 1'b0;
                else
                    out_din_user <= 1'b1;   

            DISPON_ST : 
                out_din_user <= 1'b0;


        endcase // current_state
    end 

  always_ff @(posedge CLK) begin 
        case (current_state)
            RESET_SW_ST : 
                out_din_last <= 1'b1;

            SLEEP_OUT_ST : 
                out_din_last <= 1'b1;

            RAM_WR_DATA_ST : 
                if (pixel_counter == PIXEL_LIMIT-1)
                    out_din_last <= 1'b1;
                else 
                    out_din_last <= 1'b0;


            INVON_ST : 
                out_din_last <= 1'b1;

            DISPON_ST : 
                out_din_last <= 1'b1;

            RASET_ST :
                if (word_counter == 4) 
                    out_din_last <= 1'b1;
                else
                    out_din_last <= 1'b0;

            CASET_ST :
                if (word_counter == 4) 
                    out_din_last <= 1'b1;
                else
                    out_din_last <= 1'b0;

            default:
                out_din_last <= 1'b0;


        endcase // current_state
    end 


    always_ff @(posedge CLK) begin 
        case (current_state)
            RESET_SW_ST : 
                if (!out_awfull)
                    out_wren <= 1'b1;
                else 
                    out_wren <= 1'b0;

            SLEEP_OUT_ST : 
                if (!out_awfull)
                    out_wren <= 1'b1;
                else 
                    out_wren <= 1'b0;

            RAM_WR_CMD_ST : 
                if (!out_awfull)
                    out_wren <= 1'b1;
                else 
                    out_wren <= 1'b0;                

            // RAM_WR_CONTINUE_CMD_ST:
            //     if (!out_awfull)
            //         out_wren <= 1'b1;
            //     else 
            //         out_wren <= 1'b0;                

            RAM_WR_DATA_ST : 
                if (!out_awfull)
                    out_wren <= 1'b1;
                else 
                    out_wren <= 1'b0;                


            INVON_ST : 
                if (!out_awfull)
                    out_wren <= 1'b1;
                else 
                    out_wren <= 1'b0;                

            DISPON_ST : 
                if (!out_awfull)
                    out_wren <= 1'b1;
                else 
                    out_wren <= 1'b0;                

            RASET_ST : 
                if (!out_awfull)
                    out_wren <= 1'b1;
                else 
                    out_wren <= 1'b0;                

            CASET_ST : 
                if (!out_awfull)
                    out_wren <= 1'b1;
                else 
                    out_wren <= 1'b0;                


            default : 
                out_wren <= 1'b0;

        endcase // current_state
    end 

    always_ff @(posedge CLK) begin 
        case (current_state)

            RAM_WR_DATA_ST : 
                if (!out_awfull)
                    if (word_counter == 2)
                        word_counter <= '{default:0};
                    else 
                        word_counter <= word_counter + 1;

            RASET_ST : 
                if (!out_awfull)
                    if (word_counter == 4)
                        word_counter <= '{default:0};
                    else 
                        word_counter <= word_counter + 1;

            CASET_ST : 
                if (!out_awfull)
                    if (word_counter == 4)
                        word_counter <= '{default:0};
                    else 
                        word_counter <= word_counter + 1;


            default : 
                word_counter <= '{default:0};
        endcase // current_state
    end 

    always_ff @(posedge CLK) begin 
        case (current_state)

            RAM_WR_DATA_ST : 
                if (!out_awfull)
                    pixel_counter <= pixel_counter + 1;

            default : 
                pixel_counter <= '{default:0};
        endcase // current_state
    end 



    always_ff @(posedge CLK) begin 
        case (current_state)

            PAUSE_ST : 
                pause_counter <= pause_counter + 1;

            INC_RGB_ST : 
                pause_counter <= pause_counter + 1;


            default : 
                pause_counter <= '{default:0};
        endcase // current_state
    end 

    fifo_out_sync_tuser_xpm #(
        .DATA_WIDTH(8      ),
        .USER_WIDTH(1      ),
        .MEMTYPE   ("block"),
        .DEPTH     (16     )
    ) fifo_out_sync_tuser_xpm_inst (
        .CLK          (CLK          ),
        .RESET        (RESET        ),
        
        .OUT_DIN_DATA (out_din_data ),
        .OUT_DIN_KEEP (1'b1         ),
        .OUT_DIN_USER (out_din_user ),
        .OUT_DIN_LAST (out_din_last ),
        .OUT_WREN     (out_wren     ),
        .OUT_FULL     (out_full     ),
        .OUT_AWFULL   (out_awfull   ),
        
        .M_AXIS_TDATA (M_AXIS_TDATA ),
        .M_AXIS_TKEEP (M_AXIS_TKEEP ),
        .M_AXIS_TUSER (M_AXIS_TUSER ),
        .M_AXIS_TVALID(M_AXIS_TVALID),
        .M_AXIS_TLAST (M_AXIS_TLAST ),
        .M_AXIS_TREADY(M_AXIS_TREADY)
    );




endmodule
