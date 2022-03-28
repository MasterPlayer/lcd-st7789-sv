library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use ieee.std_Logic_unsigned.all;
    use ieee.std_logic_arith.all;


library UNISIM;
    use UNISIM.VComponents.all;


entity st7789_mgr_segment_vhd is
    generic (
        SYMBOL_WIDTH            :           integer                             :=  20                              ;
        SYMBOL_HEIGHT           :           integer                             :=  40                              ;
        INTERSYMBOL_WIDTH       :           integer                             :=  10                              ;
        OFFSET_Y                :           integer                             :=  0                               ;
        OFFSET_X                :           integer                             :=  0                               ;
        NUMBER_OF_SEGMENTS      :           integer                             :=  6                               ;
        BACKGROUND_COLOR        :           std_logic_Vector ( 23 downto 0 )    := x"FFFFFF"                        ;
        FONT_COLOR              :           std_logic_Vector ( 23 downto 0 )    := x"FFFFFF" 
    ); 
    port (
        CLK                     :   in      std_logic                                                               ;
        RESET                   :   in      std_logic                                                               ;

        TIME_HOUR_H             :   in      std_logic_vector ( 6 downto 0 )                                         ;
        TIME_HOUR_L             :   in      std_logic_vector ( 6 downto 0 )                                         ;
        TIME_MIN_H              :   in      std_logic_vector ( 6 downto 0 )                                         ;
        TIME_MIN_L              :   in      std_logic_vector ( 6 downto 0 )                                         ;
        TIME_SEC_H              :   in      std_logic_vector ( 6 downto 0 )                                         ;
        TIME_SEC_L              :   in      std_logic_vector ( 6 downto 0 )                                         ;
        TIME_VALID              :   in      std_logic                                                               ;

        M_AXIS_TDATA            :   out     std_logic_vector ( 7 downto 0 )                                         ;
        M_AXIS_TKEEP            :   out     std_logic                                                               ;
        M_AXIS_TUSER            :   out     std_logic                                                               ;
        M_AXIS_TVALID           :   out     std_logic                                                               ;
        M_AXIS_TLAST            :   out     std_logic                                                               ;
        M_AXIS_TREADY           :   in      std_logic                                                                
    );
end st7789_mgr_segment_vhd;



architecture st7789_mgr_segment_vhd_arch of st7789_mgr_segment_vhd is


    constant  PIXEL_LIMIT : integer := 172800;
    constant  PAUSE_SIZE : integer := 5000000;
    
    type fsm is (
        RESET_ST                ,
        PAUSE_ST                ,

        IDLE_ST                 ,
        
        RESET_SW_ST             ,
        SLEEP_OUT_ST            ,
        RAM_WR_CMD_ST           ,
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

    );

    signal  current_state           :           fsm                             := RESET_ST;


    component fifo_out_sync_tuser_xpm
        generic(
            DATA_WIDTH              :           integer         :=  16                                      ;
            USER_WIDTH              :           integer         :=  1                                       ;
            MEMTYPE                 :           String          :=  "block"                                 ;
            DEPTH                   :           integer         :=  16                                       
        );
        port(
            CLK                     :   in      std_logic                                                   ;
            RESET                   :   in      std_logic                                                   ;
            
            OUT_DIN_DATA            :   in      std_logic_Vector ( DATA_WIDTH-1 downto 0 )                  ;
            OUT_DIN_KEEP            :   in      std_logic_Vector ( ( DATA_WIDTH/8)-1 downto 0 )             ;
            OUT_DIN_USER            :   in      std_logic_Vector ( USER_WIDTH-1 downto 0 )                  ;
            OUT_DIN_LAST            :   in      std_logic                                                   ;
            OUT_WREN                :   in      std_logic                                                   ;
            OUT_FULL                :   out     std_logic                                                   ;
            OUT_AWFULL              :   out     std_logic                                                   ;
            
            M_AXIS_TDATA            :   out     std_logic_Vector ( DATA_WIDTH-1 downto 0 )                  ;
            M_AXIS_TKEEP            :   out     std_logic_Vector (( DATA_WIDTH/8)-1 downto 0 )              ;
            M_AXIS_TUSER            :   out     std_logic_vector ( USER_WIDTH-1 downto 0 )                  ;
            M_AXIS_TVALID           :   out     std_logic                                                   ;
            M_AXIS_TLAST            :   out     std_logic                                                   ;
            M_AXIS_TREADY           :   in      std_logic                                                    
        );
    end component;

    signal  out_din_data            :           std_logic_Vector(  7 downto 0 )  := (others => '0')         ;
    signal  out_din_user            :           std_Logic                        := '0'                     ;
    signal  out_din_last            :           std_Logic                        := '0'                     ;
    signal  out_wren                :           std_Logic                        := '0'                     ;
    signal  out_full                :           std_Logic                                                   ;
    signal  out_awfull              :           std_Logic                                                   ;

    signal  word_counter            :           std_Logic_vector ( 31 downto 0 ) := (others => '0')         ;
    signal  pixel_counter           :           std_Logic_vector ( 31 downto 0 ) := (others => '0')         ;
    signal  pause_counter           :           std_Logic_vector ( 31 downto 0 ) := (others => '0')         ;

    signal  offset_y_low            :           std_logic_Vector ( 15 downto 0 ) := (others => '0')         ;
    signal  offset_y_high           :           std_logic_Vector ( 15 downto 0 ) := (others => '0')         ;
    signal  offset_x_low            :           std_logic_Vector ( 15 downto 0 ) := (others => '0')         ;
    signal  offset_x_high           :           std_logic_Vector ( 15 downto 0 ) := (others => '0')         ;



    component segment_rom
        port(
            CLK                     :   in      std_logic                                                   ;
            ADDRESS                 :   in      std_logic_vector (  4 downto 0 )                            ;
            START_PTR_X             :   out     std_Logic_vector (  7 downto 0 )                            ;
            END_PTR_X               :   out     std_Logic_vector (  7 downto 0 )                            ;
            START_PTR_Y             :   out     std_Logic_vector (  7 downto 0 )                            ;
            END_PTR_Y               :   out     std_Logic_vector (  7 downto 0 )                             
        );
    end component;

    signal  rom_address             :           std_logic_vector (  4 downto 0 ) := (others => '0')         ;
    signal  rom_start_ptr_x         :           std_logic_vector (  7 downto 0 )                            ;
    signal  rom_end_ptr_x           :           std_logic_vector (  7 downto 0 )                            ;
    signal  rom_start_ptr_y         :           std_logic_vector (  7 downto 0 )                            ;
    signal  rom_end_ptr_y           :           std_logic_vector (  7 downto 0 )                            ; 

    signal  length_x                :           std_logic_vector (  7 downto 0 )                            ;
    signal  length_y                :           std_logic_vector (  7 downto 0 )                            ;
    signal  length                  :           std_logic_vector (  7 downto 0 )                            ;

    signal  segment_index           :           std_Logic_vector (  7 downto 0 ) := (others => '0')         ;
    signal  segment_muxed           :           std_Logic_vector (  6 downto 0 ) := (others => '0')         ;
    signal  line_index              :           std_Logic_Vector (  1 downto 0 ) := (others => '0')         ;
    signal  segment_muxed_address   :           std_Logic_Vector (  2 downto 0 ) := (others => '0')         ;


begin



    current_state_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 
            if (RESET = '1') then 
                current_state <= RESET_ST;
            else 
                case (current_state) is 

                    when RESET_ST => 
                        current_state <= RESET_SW_ST;

                    when RESET_SW_ST => 
                        if (out_awfull = '0') then 
                            current_state <= PAUSE_ST;
                        end if;

                    when PAUSE_ST => 
                        if (pause_counter  < PAUSE_SIZE-1) then 
                            current_state <= current_state;
                        else 
                            current_state <= SLEEP_OUT_ST;
                        end if;

                    when SLEEP_OUT_ST => 
                        if (out_awfull = '0') then 
                            current_state <= INVON_ST;
                        end if;

                    when INVON_ST => 
                        if (out_awfull = '0') then 
                            current_state <= DISPON_ST;
                        end if;

                    when DISPON_ST => 
                        if (out_awfull = '0') then 
                            current_state <= CASET_ST;
                        end if;

                    when CASET_ST => 
                        if (word_counter = 4) then 
                            current_state <=  RASET_ST;
                        end if;

                    when RASET_ST => 
                        if (word_counter = 4) then
                            --current_state <=  RAM_WR_CMD_ST;
                            current_state <=  IDLE_ST;
                        end if;

                    when RAM_WR_CMD_ST => 
                        if (out_awfull = '0') then 
                            current_state <= RAM_WR_DATA_ST;
                        end if;

                    when RAM_WR_DATA_ST => 
                        if (out_awfull = '0') then 
                            if (pixel_counter = PIXEL_LIMIT-1) then 
                                current_state <= IDLE_ST;
                            end if;
                        else 
                            current_state <= current_state;
                        end if;

                    when IDLE_ST => 
                        if (TIME_VALID = '1') then
                            current_state <= TIME_CASET_ST;
                        else 
                            current_state <= current_state;
                        end if;

                    when TIME_CASET_ST => 
                        if (out_awfull = '0') then 
                            if (word_counter = 4) then
                                current_state <=  TIME_RASET_ST;
                            end if;
                        else 
                            current_state <= current_state;
                        end if;

                    when TIME_RASET_ST => 
                        if (out_awfull = '0') then 
                            if (word_counter = 4) then
                                current_state <=  TIME_RAMWR_CMD_ST;
                            else
                                current_state <= current_state;
                            end if;
                        else
                            current_state <= current_state;
                        end if;

                    when TIME_RAMWR_CMD_ST => 
                        if (out_awfull = '0') then 
                            current_state <= TIME_RAMWR_DATA_ST;
                        else
                            current_state <= current_state;
                        end if;

                    when TIME_RAMWR_DATA_ST => 
                        if (out_awfull = '0') then  
                            if (pixel_counter = length) then
                                if (word_counter = 2)  then
                                    if (rom_address = 27)  then
                                        if (segment_index = (NUMBER_OF_SEGMENTS-1)) then
                                            current_state <= IDLE_ST;
                                        else 
                                            current_state <= TIME_CASET_ST;    
                                        end if;
                                    else 
                                        current_state <= TIME_CASET_ST;
                                    end if;
                                else 
                                    current_state <= current_state;
                                end  if;
                            else 
                                current_state <= current_state;
                            end if;
                        else 
                            current_state <= current_state;
                        end  if;

                    when others => 
                        current_state <= IDLE_ST;

                end case;
            end if;
        end if;
    end process;



    rom_address_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 

            case (current_state)  is 

                when TIME_RAMWR_DATA_ST =>
                    if (out_awfull = '0') then  
                        if (pixel_counter = length)  then  
                            if (word_counter = 2)  then  
                                if (rom_address = 27) then   
                                    rom_address <= (others => '0');
                                else
                                    rom_address <= rom_address + 1;
                                end if;
                            else 
                                rom_address <= rom_address;
                            end if;
                        else 
                            rom_address <= rom_address;
                        end if; 
                    else 
                        rom_address <= rom_address;
                    end if;

                when others => 
                    rom_address <= rom_address;

            end case;
        end if;
    end process;



    segment_index_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 

            case (current_state) is 

                when IDLE_ST => 
                    segment_index <= (others => '0');

                when TIME_RAMWR_DATA_ST => 
                    if (out_awfull = '0') then   
                        if (pixel_counter = length) then 
                            if (word_counter = 2)  then 
                                if (rom_address = 27) then  
                                    if (segment_index = (NUMBER_OF_SEGMENTS-1)) then 
                                        segment_index <= (others => '0');
                                    else   
                                        segment_index <= segment_index + 1;
                                    end if;
                                else  
                                    segment_index <= segment_index;
                                end if;
                            else  
                                segment_index <= segment_index;
                            end if;
                        else  
                            segment_index <= segment_index;
                        end if;
                    else  
                        segment_index <= segment_index;
                    end if;

                when others => 
                    segment_index <= segment_index;

            end case;
        end if;
    end process;



    offset_y_low_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 
            offset_y_low <= EXT(OFFSET_Y + rom_start_ptr_y, offset_y_low'length);
        end if;
    end process;



    offset_y_high_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 
            offset_y_high <= EXT(OFFSET_Y + rom_end_ptr_y, offset_y_high'length);
        end if;
    end process;



    offset_x_low_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 
            case (conv_integer(segment_index))  is 
                when 0      => offset_x_low <= conv_std_logic_vector((((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*0)+OFFSET_X), offset_x_low'length) + rom_start_ptr_x;
                when 1      => offset_x_low <= conv_std_logic_vector((((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*1)+OFFSET_X), offset_x_low'length) + rom_start_ptr_x;
                when 2      => offset_x_low <= conv_std_logic_vector((((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*2)+OFFSET_X), offset_x_low'length) + rom_start_ptr_x;
                when 3      => offset_x_low <= conv_std_logic_vector((((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*3)+OFFSET_X), offset_x_low'length) + rom_start_ptr_x;
                when 4      => offset_x_low <= conv_std_logic_vector((((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*4)+OFFSET_X), offset_x_low'length) + rom_start_ptr_x;
                when 5      => offset_x_low <= conv_std_logic_vector((((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*5)+OFFSET_X), offset_x_low'length) + rom_start_ptr_x;
                when others => offset_x_low <= offset_x_low;
           end case;
        end if;
    end process;
   


    offset_x_high_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 

            case (conv_integer(segment_index))  is 
                when 0      =>  offset_x_high <= conv_std_logic_vector((((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*0)+OFFSET_X), offset_x_high'length) + rom_end_ptr_x;
                when 1      =>  offset_x_high <= conv_std_logic_vector((((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*1)+OFFSET_X), offset_x_high'length) + rom_end_ptr_x;
                when 2      =>  offset_x_high <= conv_std_logic_vector((((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*2)+OFFSET_X), offset_x_high'length) + rom_end_ptr_x;
                when 3      =>  offset_x_high <= conv_std_logic_vector((((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*3)+OFFSET_X), offset_x_high'length) + rom_end_ptr_x;
                when 4      =>  offset_x_high <= conv_std_logic_vector((((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*4)+OFFSET_X), offset_x_high'length) + rom_end_ptr_x;
                when 5      =>  offset_x_high <= conv_std_logic_vector((((SYMBOL_WIDTH+INTERSYMBOL_WIDTH)*5)+OFFSET_X), offset_x_high'length) + rom_end_ptr_x;
                when others =>  offset_x_high <= offset_x_high;
            end case;
        end if;
    end process;



    length_x_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 
            length_x <= rom_end_ptr_x - rom_start_ptr_x;
        end if;
    end process;



    length_y_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 
            length_y <= rom_end_ptr_y - rom_start_ptr_y;
        end if;
    end process;



    length_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 
            length <= length_x + length_y;
        end if;
    end process;



    out_din_data_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 
            case (current_state) is 
                when RESET_SW_ST => 
                    out_din_data <= x"01";

                when SLEEP_OUT_ST => 
                    out_din_data <= x"11";

                when RAM_WR_CMD_ST => 
                    out_din_data <= x"2C";            

                when RAM_WR_DATA_ST => 
                    case (conv_integer(word_counter)) is
                         when 0     => out_din_data <= BACKGROUND_COLOR( 23 downto 16 );
                         when 1     => out_din_data <= BACKGROUND_COLOR( 15 downto  8 );
                         when 2     => out_din_data <= BACKGROUND_COLOR(  7 downto  0 );
                        when others => out_din_data <= out_din_data;
                    end case;

                when RASET_ST => 
                    case (conv_integer(word_counter)) is
                         when 0     => out_din_data <= x"2B";
                         when 1     => out_din_data <= x"00";
                         when 2     => out_din_data <= x"00";
                         when 3     => out_din_data <= x"00";
                         when 4     => out_din_data <= x"EF";
                        when others => out_din_data <= out_din_data;
                    end case;

                when CASET_ST => 
                    case (conv_integer(word_counter)) is
                         when 0     => out_din_data <= x"2A";
                         when 1     => out_din_data <= x"00";
                         when 2     => out_din_data <= x"00";
                         when 3     => out_din_data <= x"00";
                         when 4     => out_din_data <= x"EF";
                        when others => out_din_data <= out_din_data;
                    end case;

                when INVON_ST => 
                    out_din_data <= x"21";            

                when DISPON_ST => 
                    out_din_data <= x"29";           

                when TIME_RASET_ST => 
                    case (conv_integer(word_counter)) is
                         when 0     => out_din_data <= x"2B";
                         when 1     => out_din_data <= offset_y_low( 15 downto 8 );
                         when 2     => out_din_data <= offset_y_low(  7 downto 0 );
                         when 3     => out_din_data <= offset_y_high( 15 downto 8 );
                         when 4     => out_din_data <= offset_y_high(  7 downto 0 );
                        when others => out_din_data <= out_din_data;
                    end case;

                when TIME_CASET_ST => 
                    case (conv_integer(word_counter)) is
                        when 0      => out_din_data <= x"2A";
                        when 1      => out_din_data <= offset_x_low( 15 downto 8 );
                        when 2      => out_din_data <= offset_x_low(  7 downto 0 );
                        when 3      => out_din_data <= offset_x_high( 15 downto 8 );
                        when 4      => out_din_data <= offset_x_high(  7 downto 0 );
                        when others => out_din_data <= out_din_data;
                    end case;

                when TIME_RAMWR_CMD_ST => 
                    out_din_data <= x"2C";            

                when TIME_RAMWR_DATA_ST => 
                    if (segment_muxed(conv_integer(segment_muxed_address)) = '1') then 
                        case (conv_integer(word_counter)) is
                            when 0      => out_din_data <= FONT_COLOR ( 23 downto 16);
                            when 1      => out_din_data <= FONT_COLOR ( 15 downto  8);
                            when 2      => out_din_data <= FONT_COLOR (  7 downto  0);
                            when others => out_din_data <= out_din_data;
                        end case;
                    else 
                        case (conv_integer(word_counter)) is
                            when 0      => out_din_data <= BACKGROUND_COLOR ( 23 downto 16);
                            when 1      => out_din_data <= BACKGROUND_COLOR ( 15 downto  8);
                            when 2      => out_din_data <= BACKGROUND_COLOR (  7 downto  0);
                            when others => out_din_data <= out_din_data;
                        end case;
                    end if;      

                when others => 
                    out_din_data <= out_din_data;

            end case; 
        end if;
    end process;



    out_din_user_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 

            case (current_state) is 
                when RESET_SW_ST =>
                    out_din_user <= '0';

                when SLEEP_OUT_ST =>
                    out_din_user <= '0';

                when RAM_WR_CMD_ST =>
                    out_din_user <= '0';

                when RAM_WR_DATA_ST =>
                    out_din_user <= '1';

                when INVON_ST =>
                    out_din_user <= '0';

                when DISPON_ST =>
                    out_din_user <= '0';

                when RASET_ST =>
                    if (word_counter = 0) then 
                        out_din_user <= '0';
                    else
                        out_din_user <= '1';
                    end if;

                when CASET_ST =>
                    if (word_counter = 0) then 
                        out_din_user <= '0';
                    else
                        out_din_user <= '1';   
                    end if;

                when TIME_RAMWR_CMD_ST =>
                    out_din_user <= '0';

                when TIME_RAMWR_DATA_ST =>
                    out_din_user <= '1';

                when TIME_RASET_ST =>
                    if (word_counter = 0) then 
                        out_din_user <= '0';
                    else
                        out_din_user <= '1';
                    end if;

                when TIME_CASET_ST =>
                    if (word_counter = 0) then 
                        out_din_user <= '0';
                    else
                        out_din_user <= '1';   
                    end if;

                when others => 
                    out_din_user <= out_din_user;

            end case; 
        end if;
    end process;



    out_din_last_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 

            case (current_state) is 
                when RESET_SW_ST => 
                    out_din_last <= '1';

                when SLEEP_OUT_ST => 
                    out_din_last <= '1';

                when RAM_WR_DATA_ST => 
                    if (pixel_counter = PIXEL_LIMIT-1) then 
                        out_din_last <= '1';
                    else 
                        out_din_last <= '0';
                    end if;

                when INVON_ST => 
                    out_din_last <= '1';

                when DISPON_ST => 
                    out_din_last <= '1';

                when RASET_ST => 
                    if (word_counter = 4) then
                        out_din_last <= '1';
                    else
                        out_din_last <= '0';
                    end if;

                when CASET_ST => 
                    if (word_counter = 4) then
                        out_din_last <= '1';
                    else
                        out_din_last <= '0';
                    end if;

                when TIME_RASET_ST => 
                    if (word_counter = 4) then
                        out_din_last <= '1';
                    else
                        out_din_last <= '0';
                    end if;

                when TIME_CASET_ST => 
                    if (word_counter = 4) then
                        out_din_last <= '1';
                    else
                        out_din_last <= '0';
                    end if;

                when TIME_RAMWR_DATA_ST => 
                    if (pixel_counter = length) then 
                        if (word_counter = 2) then 
                            out_din_last <= '1';
                        else 
                            out_din_last <= '0';
                        end if;
                    else 
                        out_din_last <= '0';
                    end if;

                when others =>
                    out_din_last <= '0';

            end case;
        end if;
    end process;



    out_wren_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 

            case (current_state) is 
                when RESET_SW_ST => 
                    if (out_awfull = '0') then 
                        out_wren <= '1';
                    else 
                        out_wren <= '0';
                    end if;

                when SLEEP_OUT_ST => 
                    if (out_awfull = '0') then 
                        out_wren <= '1';
                    else 
                        out_wren <= '0';
                    end if;

                when RAM_WR_CMD_ST => 
                    if (out_awfull = '0') then 
                        out_wren <= '1';
                    else 
                        out_wren <= '0';                
                    end if;

                when RAM_WR_DATA_ST => 
                    if (out_awfull = '0') then 
                        out_wren <= '1';
                    else 
                        out_wren <= '0';                
                    end if;

                when INVON_ST => 
                    if (out_awfull = '0') then 
                        out_wren <= '1';
                    else 
                        out_wren <= '0';                
                    end if;

                when DISPON_ST => 
                    if (out_awfull = '0') then 
                        out_wren <= '1';
                    else 
                        out_wren <= '0';                
                    end if;

                when RASET_ST => 
                    if (out_awfull = '0') then 
                        out_wren <= '1';
                    else 
                        out_wren <= '0';                
                    end if;

                when CASET_ST => 
                    if (out_awfull = '0') then 
                        out_wren <= '1';
                    else 
                        out_wren <= '0';
                    end if;

                when TIME_RASET_ST => 
                    if (out_awfull = '0') then 
                        out_wren <= '1';
                    else 
                        out_wren <= '0';                
                    end if;

                when TIME_CASET_ST => 
                    if (out_awfull = '0') then 
                        out_wren <= '1';
                    else 
                        out_wren <= '0';                
                    end if;

                when TIME_RAMWR_CMD_ST => 
                    if (out_awfull = '0') then 
                        out_wren <= '1';
                    else 
                        out_wren <= '0';                
                    end if;

                when TIME_RAMWR_DATA_ST => 
                    if (out_awfull = '0') then 
                        out_wren <= '1';
                    else 
                        out_wren <= '0';
                    end if;

                when others =>
                    out_wren <=  '0';

            end case;
        end if;
    end process;



    word_counter_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 

            case (current_state) is 

                when RAM_WR_DATA_ST => 
                    if (out_awfull = '0') then 
                        if (word_counter = 2) then 
                            word_counter <= (others => '0');
                        else 
                            word_counter <= word_counter + 1;
                        end if;
                    end if;

                when RASET_ST => 
                    if (out_awfull = '0') then 
                        if (word_counter = 4) then 
                            word_counter <= (others => '0');
                        else 
                            word_counter <= word_counter + 1;
                        end if;
                    end if;

                when CASET_ST => 
                    if (out_awfull = '0') then 
                        if (word_counter = 4) then 
                            word_counter <= (others => '0');
                        else 
                            word_counter <= word_counter + 1;
                        end if;
                    end if;


                when TIME_RASET_ST => 
                    if (out_awfull = '0') then 
                        if (word_counter = 4) then 
                            word_counter <= (others => '0');
                        else 
                            word_counter <= word_counter + 1;
                        end if;
                    end if;

                when TIME_CASET_ST => 
                    if (out_awfull = '0') then  
                        if (word_counter = 4)  then 
                            word_counter <= (others => '0');
                        else 
                            word_counter <= word_counter + 1;
                        end if;
                    end if;

                when TIME_RAMWR_DATA_ST => 
                    if (out_awfull = '0') then 
                        if (word_counter = 2) then 
                            word_counter <= (others => '0');
                        else 
                            word_counter <= word_counter + 1;
                        end if;
                    end if;

                when others =>
                    word_counter <= (others => '0');

            end case;
        end if;
    end process;



    pixel_counter_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 

            case (current_state) is 

                when RAM_WR_DATA_ST => 
                    if (out_awfull = '0') then 
                        pixel_counter <= pixel_counter + 1;
                    end if;

                when TIME_RAMWR_DATA_ST => 
                    if (out_awfull = '0') then 
                        if (word_counter = 2) then 
                            pixel_counter <= pixel_counter + 1;
                        end if;
                    end if;

                when others =>
                    pixel_counter <= (others => '0');

            end case; 
        end if;
    end process;



    pause_counter_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 
            case (current_state) is 

                when PAUSE_ST => 
                    pause_counter <= pause_counter + 1;

                when others =>
                    pause_counter <= (others => '0');

            end case;
        end if;
    end process;



    fifo_out_sync_tuser_xpm_inst : fifo_out_sync_tuser_xpm 
        generic map (
            DATA_WIDTH      =>  8                   ,
            USER_WIDTH      =>  1                   ,
            MEMTYPE         =>  "block"             ,
            DEPTH           =>  16      
        )
        port map (
            CLK             =>  CLK                 ,
            RESET           =>  RESET               ,
            
            OUT_DIN_DATA    =>  out_din_data        ,
            OUT_DIN_KEEP    =>  "1"                 ,
            OUT_DIN_USER(0) =>  out_din_user        ,
            OUT_DIN_LAST    =>  out_din_last        ,
            OUT_WREN        =>  out_wren            ,
            OUT_FULL        =>  out_full            ,
            OUT_AWFULL      =>  out_awfull          ,
            
            M_AXIS_TDATA    =>  M_AXIS_TDATA        ,
            M_AXIS_TKEEP(0) =>  M_AXIS_TKEEP        ,
            M_AXIS_TUSER(0) =>  M_AXIS_TUSER        ,
            M_AXIS_TVALID   =>  M_AXIS_TVALID       ,
            M_AXIS_TLAST    =>  M_AXIS_TLAST        ,
            M_AXIS_TREADY   =>  M_AXIS_TREADY       
        );



    line_index_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 

            case (current_state) is 
                when TIME_RAMWR_DATA_ST => 
                    if (out_awfull = '0') then 
                        if (word_counter = 2) then 
                            if (pixel_counter = length) then 
                                line_index <= line_index + 1;
                            end if;
                        end if;
                    end if;

                when others => 
                    line_index <= line_index;

            end case;
        end if;
    end process;



    segment_muxed_address_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 
            case (current_state) is 
                when TIME_RAMWR_DATA_ST => 
                    if (out_awfull = '0') then  
                        if (word_counter = 2)  then 
                            if (pixel_counter = length) then 
                                if (line_index = 3) then 
                                    if (segment_muxed_address = 6) then 
                                        segment_muxed_address <= (others => '0');
                                    else 
                                        segment_muxed_address <= segment_muxed_address + 1;
                                    end if;
                                end if;
                            end if;
                        end if;
                    end if;

                when others => 
                    segment_muxed_address <= segment_muxed_address;
            end case;
        end if;
    end process;



    segment_muxed_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 
            case (conv_integer(segment_index)) is 
                when 1      => segment_muxed <= TIME_HOUR_L ;
                when 2      => segment_muxed <= TIME_MIN_H  ;
                when 3      => segment_muxed <= TIME_MIN_L  ;
                when 4      => segment_muxed <= TIME_SEC_H  ;
                when 5      => segment_muxed <= TIME_SEC_L  ;
                when others => segment_muxed <= TIME_HOUR_H ;
            end case;
        end if;
    end process;



    segment_rom_inst : segment_rom
        port map (
            CLK         => CLK              ,
            ADDRESS     => rom_address      ,
            START_PTR_X => rom_start_ptr_x  ,
            END_PTR_X   => rom_end_ptr_x    ,
            START_PTR_Y => rom_start_ptr_y  ,
            END_PTR_Y   => rom_end_ptr_y     
        );


end st7789_mgr_segment_vhd_arch;
