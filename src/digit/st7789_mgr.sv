`timescale 1ns / 1ps



module st7789_mgr #(
    parameter        SYMBOL_WIDTH       = 20        ,
    parameter        SYMBOL_HEIGHT      = 40        ,
    parameter        INTERSYMBOL_WIDTH  = 10        ,
    parameter        OFFSET_Y           = 0         ,
    parameter        OFFSET_X           = 0         ,
    parameter        NUMBER_OF_SEGMENTS = 6          
) (
    input  logic       CLK          ,
    input  logic       RESET        ,
    input  logic       RUN          ,

    input  logic [7:0] BACKGROUND_R  ,
    input  logic [7:0] BACKGROUND_G  ,
    input  logic [7:0] BACKGROUND_B  ,

    input  logic [7:0] SYMBOL_R  ,
    input  logic [7:0] SYMBOL_G  ,
    input  logic [7:0] SYMBOL_B  ,

    input  logic [3:0] TIME_HOUR_H  ,
    input  logic [3:0] TIME_HOUR_L  ,
    input  logic [3:0] TIME_MIN_H   ,
    input  logic [3:0] TIME_MIN_L   ,
    input  logic [3:0] TIME_SEC_H   ,
    input  logic [3:0] TIME_SEC_L   ,

    input  logic       TIME_VALID   ,
    
    output logic [7:0] M_AXIS_TDATA ,
    output logic       M_AXIS_TKEEP ,
    output logic       M_AXIS_TUSER ,
    output logic       M_AXIS_TVALID,
    output logic       M_AXIS_TLAST ,
    input  logic       M_AXIS_TREADY
);

    localparam integer PIXEL_LIMIT = 172800;
    // localparam integer PAUSE_SIZE = 5000000;
    localparam integer PAUSE_SIZE = 500;


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
        DISPON_ST               ,

        TIME_CASET_ST           ,
        TIME_RASET_ST           ,
        TIME_RAMWR_CMD_ST       , 
        TIME_RAMWR_DATA_ST      ,

        TIME_INC_ADDR_ST         

    } fsm;

    fsm current_state = RESET_ST;

    logic [7:0] out_din_data = '{default:0};
    logic       out_din_user = 1'b0        ;
    logic       out_din_last = 1'b0        ;
    logic       out_wren     = 1'b0        ;
    logic       out_full                   ;
    logic       out_awfull                 ;


    logic [                 31:0] word_counter  = '{default:0};
    logic [$clog2(PIXEL_LIMIT):0] pixel_counter = '{default:0};
    logic [ $clog2(PAUSE_SIZE):0] pause_counter = '{default:0};

    logic [23:0] rgb_reg ;

    logic [$clog2(NUMBER_OF_SEGMENTS):0] segment_index = '{default:0};


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
                        current_state <= IDLE_ST;


                IDLE_ST : 
                    if (RUN)
                        current_state <= CASET_ST;
                    else
                        if (TIME_VALID)
                            current_state <= TIME_CASET_ST;
                        else 
                            current_state <= current_state;

                CASET_ST : 
                    if (word_counter == 4)
                        current_state <=  RASET_ST;

                RASET_ST : 
                    if (word_counter == 4)
                        current_state <=  RAM_WR_CMD_ST;

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


                TIME_CASET_ST : 
                    if (!out_awfull)
                        if (word_counter == 4)
                            current_state <=  TIME_RASET_ST;


                TIME_RASET_ST : 
                    if (!out_awfull)
                        if (word_counter == 4)
                            current_state <=  TIME_RAMWR_CMD_ST;


                TIME_RAMWR_CMD_ST : 
                    if (!out_awfull) begin 
                        current_state <= TIME_RAMWR_DATA_ST;
                    end else begin 
                        current_state <= current_state;
                    end 


                // Transmit all ROM for current symbol 
                TIME_RAMWR_DATA_ST:  
                    if (!out_awfull) begin 
                        if (pixel_counter == (SYMBOL_WIDTH * SYMBOL_HEIGHT * 3) -1) begin 
                            if (segment_index == (NUMBER_OF_SEGMENTS-1)) begin 
                                current_state <= IDLE_ST;
                            end else begin 
                                current_state <= TIME_CASET_ST;
                            end 
                        end else begin 
                            current_state <= current_state;
                        end 
                    end else begin 
                        current_state <= current_state;
                    end 



                default : 
                    current_state <= IDLE_ST;

            endcase // current_state

    end     


    always_ff @(posedge CLK) begin 
        case (current_state)

            IDLE_ST : 
                segment_index <= '{default:0};


            TIME_RAMWR_DATA_ST : 
                if (!out_awfull) 
                    if (pixel_counter == (SYMBOL_WIDTH * SYMBOL_HEIGHT * 3) -1)
                        segment_index <= segment_index + 1;




        endcase // current_state
    end


    logic [15:0] offset_y_low  = '{default:0};
    logic [15:0] offset_y_high = '{default:0};


    always_ff @(posedge CLK) begin 
        case (segment_index) 
            0 : offset_y_low <= (OFFSET_Y);
            1 : offset_y_low <= (OFFSET_Y);
            2 : offset_y_low <= (OFFSET_Y);
            3 : offset_y_low <= (OFFSET_Y);
            4 : offset_y_low <= (OFFSET_Y);
            5 : offset_y_low <= (OFFSET_Y);
            default : offset_y_low <= offset_y_low;
        endcase // segment_index
    end 


    always_ff @(posedge CLK) begin 
        offset_y_high <= (offset_y_low + (SYMBOL_HEIGHT-1));
    end 


    logic [15:0] offset_x_low  = '{default:0};
    logic [15:0] offset_x_high = '{default:0};

    always_ff @(posedge CLK) begin 
        case (segment_index) 
            0 : offset_x_low <= ((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*0)+OFFSET_X;
            1 : offset_x_low <= ((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*1)+OFFSET_X;
            2 : offset_x_low <= ((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*2)+OFFSET_X;
            3 : offset_x_low <= ((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*3)+OFFSET_X;
            4 : offset_x_low <= ((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*4)+OFFSET_X;
            5 : offset_x_low <= ((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*5)+OFFSET_X;
            default : offset_x_low <= offset_x_low;
        endcase // segment_index
    end 


    always_ff @(posedge CLK) begin 
        offset_x_high <= (offset_x_low + (SYMBOL_WIDTH-1));
    end 



    always_ff @(posedge CLK) begin 
        case (current_state)

            IDLE_ST : 
                rgb_reg <= {BACKGROUND_R, BACKGROUND_G, BACKGROUND_B};

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

            TIME_RASET_ST : 
                case (word_counter)
                    'd0 : out_din_data <= 8'h2B;
                    'd1 : out_din_data <= offset_y_low[15:8];
                    'd2 : out_din_data <= offset_y_low[7:0];
                    'd3 : out_din_data <= offset_y_high[15:8];
                    'd4 : out_din_data <= offset_y_high[7:0];
                    default : out_din_data <= out_din_data;
                endcase

            TIME_CASET_ST :
                case (word_counter)
                    'd0 : out_din_data <= 8'h2A;
                    'd1 : out_din_data <= offset_x_low[15:8];
                    'd2 : out_din_data <= offset_x_low[7:0];
                    'd3 : out_din_data <= offset_x_high[15:8];
                    'd4 : out_din_data <= offset_x_high[7:0];
                    default : out_din_data <= out_din_data;
                endcase

            TIME_RAMWR_CMD_ST: 
                out_din_data <= 8'h2C;            

            TIME_RAMWR_DATA_ST: 
                if (digit_rom_value)
                    case (word_counter)
                        'd0 : out_din_data <= SYMBOL_R;
                        'd1 : out_din_data <= SYMBOL_G;
                        'd2 : out_din_data <= SYMBOL_B;
                        default : out_din_data <= out_din_data;
                    endcase
                else 
                    case (word_counter)
                        'd0 : out_din_data <= rgb_reg[23:16];
                        'd1 : out_din_data <= rgb_reg[15: 8];
                        'd2 : out_din_data <= rgb_reg[ 7: 0];
                        default : out_din_data <= out_din_data;
                    endcase
                    

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

            TIME_RAMWR_CMD_ST : 
                out_din_user <= 1'b0;

            TIME_RAMWR_DATA_ST : 
                out_din_user <= 1'b1;

            TIME_RASET_ST : 
                if (word_counter == 0)
                    out_din_user <= 1'b0;
                else
                    out_din_user <= 1'b1;

            TIME_CASET_ST : 
                if (word_counter == 0)
                    out_din_user <= 1'b0;
                else
                    out_din_user <= 1'b1;   


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



            TIME_RASET_ST :
                if (word_counter == 4) 
                    out_din_last <= 1'b1;
                else
                    out_din_last <= 1'b0;

            TIME_CASET_ST :
                if (word_counter == 4) 
                    out_din_last <= 1'b1;
                else
                    out_din_last <= 1'b0;

            TIME_RAMWR_DATA_ST : 
                if (pixel_counter == (SYMBOL_HEIGHT * SYMBOL_WIDTH * 3)-1)
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

            TIME_RASET_ST : 
                if (!out_awfull)
                    out_wren <= 1'b1;
                else 
                    out_wren <= 1'b0;                

            TIME_CASET_ST : 
                if (!out_awfull)
                    out_wren <= 1'b1;
                else 
                    out_wren <= 1'b0;                

            TIME_RAMWR_CMD_ST : 
                if (!out_awfull)
                    out_wren <= 1'b1;
                else 
                    out_wren <= 1'b0;                

            TIME_RAMWR_DATA_ST : 
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


            TIME_RASET_ST : 
                if (!out_awfull)
                    if (word_counter == 4)
                        word_counter <= '{default:0};
                    else 
                        word_counter <= word_counter + 1;

            TIME_CASET_ST : 
                if (!out_awfull) 
                    if (word_counter == 4) 
                        word_counter <= '{default:0};
                    else 
                        word_counter <= word_counter + 1;

            TIME_RAMWR_DATA_ST : 
                if (!out_awfull)
                    if (word_counter == 2)
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

            TIME_RAMWR_DATA_ST : 
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

    logic [8:0] digit_addr = '{default:0};
    logic [4:0] symbol_addr = '{default:0};

    logic [3:0] segment_muxed = '{default:0};

    always_ff @(posedge CLK) begin
        case (segment_index)
            1       : segment_muxed <= TIME_HOUR_L ;
            2       : segment_muxed <= TIME_MIN_H  ;
            3       : segment_muxed <= TIME_MIN_L  ;
            4       : segment_muxed <= TIME_SEC_H  ;
            5       : segment_muxed <= TIME_SEC_L  ;
            default : segment_muxed <= TIME_HOUR_H ;
        endcase // current_state
    end 

    always_ff @(posedge CLK) begin 
        
        case (current_state)

            TIME_CASET_ST: 
                case (segment_muxed) 
                    4'h1 : digit_addr <= (SYMBOL_HEIGHT*1);
                    4'h2 : digit_addr <= (SYMBOL_HEIGHT*2);
                    4'h3 : digit_addr <= (SYMBOL_HEIGHT*3);
                    4'h4 : digit_addr <= (SYMBOL_HEIGHT*4);
                    4'h5 : digit_addr <= (SYMBOL_HEIGHT*5);
                    4'h6 : digit_addr <= (SYMBOL_HEIGHT*6);
                    4'h7 : digit_addr <= (SYMBOL_HEIGHT*7);
                    4'h8 : digit_addr <= (SYMBOL_HEIGHT*8);
                    4'h9 : digit_addr <= (SYMBOL_HEIGHT*9);
                    default : digit_addr <= '{default:0};
                endcase // TIME_HOUR_H

            TIME_RAMWR_DATA_ST : 
                if (!out_awfull) begin 
                    if (word_counter == 2) begin 
                        if (symbol_addr == SYMBOL_WIDTH-1) begin 
                            digit_addr <= digit_addr + 1;
                        end else begin 
                            digit_addr <= digit_addr;
                        end 
                    end else begin 
                        digit_addr <= digit_addr;
                    end 
                end else begin 
                    digit_addr <= digit_addr;
                end 


            default : 
                digit_addr <= digit_addr;


        endcase
    
    end  

    always_ff @(posedge CLK) begin 
        case (current_state)
            TIME_RAMWR_DATA_ST : 
                if (!out_awfull) begin 
                    if (word_counter == 2) begin 
                        if (symbol_addr == (SYMBOL_WIDTH-1)) begin 
                            symbol_addr <= '{default:0};
                        end else begin 
                            symbol_addr <= symbol_addr + 1;
                        end 
                    end else begin  
                        symbol_addr <= symbol_addr;
                    end 
                end else begin 
                    symbol_addr <= symbol_addr;
                end  


            default : 
                symbol_addr <= symbol_addr;

        endcase // current_state
    end 

    logic digit_rom_value;

    digit_rom digit_rom_inst (
        .CLK        (CLK            ),
        .DIGIT_ADDR (digit_addr     ),
        .SYMBOL_ADDR(symbol_addr    ),
        .DATA_OUT   (digit_rom_value)
    );



endmodule
