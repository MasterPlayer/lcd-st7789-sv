library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use ieee.std_Logic_unsigned.all;
    use ieee.std_Logic_arith.all;

library UNISIM;
    use UNISIM.VComponents.all;

entity st7789_driver_vhd is
    port(
        CLK                 :   in      std_Logic                                        ;
        RESET               :   in      std_Logic                                        ;
        SCLK                :   in      std_Logic                                        ;
        S_AXIS_TDATA        :   in      std_Logic_vector ( 7 downto 0 )                  ;
        S_AXIS_TKEEP        :   in      std_Logic                                        ;
        S_AXIS_TUSER        :   in      std_Logic                                        ;
        S_AXIS_TVALID       :   in      std_Logic                                        ;
        S_AXIS_TLAST        :   in      std_Logic                                        ;
        S_AXIS_TREADY       :   out     std_Logic                                        ;
        LCD_BLK             :   out     std_Logic                                        ;
        LCD_RST             :   out     std_Logic                                        ;
        LCD_DC              :   out     std_Logic                                        ;
        LCD_SDA             :   out     std_Logic                                        ;
        LCD_SCK             :   out     std_Logic                                         
    );
end st7789_driver_vhd;



architecture st7789_driver_vhd_arch of st7789_driver_vhd is

    constant  RESET_COUNTER_LIMIT   : integer := 1000000;

    type fsm is (
        RESET_ST    ,
        IDLE_ST     ,
        TX_DATA_ST  
    );

    signal  current_state           :       fsm                                 := RESET_ST             ;
    signal  sreset                  :       std_logic                                                   ;
    signal  reset_counter           :       std_logic_vector ( 31 downto 0 )    := (others => '0')      ;

    component fifo_in_async_user_xpm
        generic(
            CDC_SYNC        :           integer         :=  4                               ;
            DATA_WIDTH      :           integer         :=  16                              ;
            USER_WIDTH      :           integer         :=  1                               ;
            MEMTYPE         :           String          :=  "block"                         ;
            DEPTH           :           integer         :=  16                              
        );
        port(
            S_AXIS_CLK      :   in      std_logic                                               ;
            S_AXIS_RESET    :   in      std_logic                                               ;
            M_AXIS_CLK      :   in      std_logic                                               ;
            
            S_AXIS_TDATA    :   in      std_logic_Vector ( DATA_WIDTH-1 downto 0 )              ;
            S_AXIS_TKEEP    :   in      std_logic_Vector (( DATA_WIDTH/8)-1 downto 0 )          ;
            S_AXIS_TUSER    :   in      std_logic_vector ( USER_WIDTH-1 downto 0 )              ;
            S_AXIS_TVALID   :   in      std_logic                                               ;
            S_AXIS_TLAST    :   in      std_logic                                               ;
            S_AXIS_TREADY   :   out     std_logic                                               ;

            IN_DOUT_DATA    :   out     std_logic_Vector ( DATA_WIDTH-1 downto 0 )              ;
            IN_DOUT_KEEP    :   out     std_logic_Vector ( ( DATA_WIDTH/8)-1 downto 0 )         ;
            IN_DOUT_USER    :   out     std_logic_vector ( USER_WIDTH-1 downto 0 )              ;
            IN_DOUT_LAST    :   out     std_logic                                               ;
            IN_RDEN         :   in      std_logic                                               ;
            IN_EMPTY        :   out     std_logic                                                
        );
    end component;

    signal  in_dout_data            :       std_Logic_vector (  7 downto 0 )                            ;
    signal  in_dout_data_shift      :       std_Logic_vector (  7 downto 0 )    := (others => '1')      ;
    signal  in_dout_user            :       std_Logic                                                   ;
    signal  in_dout_user_saved      :       std_Logic                           := '1'                  ;
    signal  in_dout_keep            :       std_Logic                                                   ;
    signal  in_dout_last            :       std_Logic                                                   ;
    signal  in_dout_last_saved      :       std_Logic                           := '0'                  ;
    signal  in_rden                 :       std_Logic                           := '0'                  ;
    signal  in_empty                :       std_Logic                                                   ;
    signal  bit_cnt                 :       std_logic_Vector ( 2 downto 0 )     := (others => '0')      ;
    signal  clk_en                  :       std_Logic                                                   ;

    signal  lcd_sda_reg             :       std_logic                                                   ;
    signal  lcd_dc_reg              :       std_logic                                                   ;
    signal  lcd_rst_reg             :       std_logic                                                   ;
    signal  lcd_blk_reg             :       std_Logic                                                   ;

begin

    LCD_SDA <= lcd_sda_reg;
    LCD_DC <= lcd_dc_reg;
    LCD_RST <= lcd_rst_reg;
    LCD_BLK <= lcd_blk_reg;

    xpm_cdc_sync_rst_inst : xpm_cdc_sync_rst
        generic map (
            DEST_SYNC_FF      => 4                ,
            INIT              => 1                ,
            INIT_SYNC_FF      => 0                ,
            SIM_ASSERT_CHK    => 0                 
        )
        port map (
            dest_rst          => sreset            ,
            dest_clk          => SCLK              ,
            src_rst           => RESET              
        );




    clk_en <= '0' when current_state = TX_DATA_ST else '1';



    lcd_sda_processing : process(SCLK) 
    begin 
        if CLK'event AND CLK = '1' then 
            lcd_sda_reg <= in_dout_data_shift(7) ;
            lcd_dc_reg  <= in_dout_user_saved    ;
        end if;
    end process;
       


    reset_counter_processing : process(SCLK) 
    begin 
        if SCLK'event AND SCLK = '1' then 
            if (sreset = '1') then 
                reset_counter <= (others => '0');
            else
                case (current_state) is 
                    when RESET_ST =>
                        reset_counter <= reset_counter + 1;

                    when others =>
                        reset_counter <= (others => '0');
                end case;
            end if;
        end if;
    end process;



    lcd_rst_reg_processing : process(SCLK) 
    begin 
        if SCLK'event AND SCLK = '1' then 

            case (current_state) is 
                when RESET_ST =>
                    lcd_rst_reg <= '0';

                when others =>
                    lcd_rst_reg <= '1';
            end case;
        end if;
    end process;



    current_state_processing : process(SCLK) 
    begin 
        if SCLK'event AND SCLK = '1' then 

            if (sreset = '1') then 
                current_state <= RESET_ST;
            else 
                case (current_state) is 
                    when RESET_ST =>
                        if (reset_counter = RESET_COUNTER_LIMIT) then 
                            current_state <= IDLE_ST;
                        else 
                            current_state <= current_state;
                        end if;

                    when IDLE_ST =>
                        if (in_empty = '0') then 
                            current_state <= TX_DATA_ST;
                        else 
                            current_state <= current_state;
                        end if;

                    when TX_DATA_ST =>
                        if (bit_cnt = 7) then 
                            if (in_dout_last_saved = '1') then 
                                current_state <= IDLE_ST;
                            end if;
                        end if;

                    when others =>
                        current_state <= current_state;
                
                end case;
            end if;
        end if;
    end process;



    lcd_blk_reg_processing : process(SCLK) 
    begin 
        if SCLK'event AND SCLK = '1' then 

            case (current_state) is 
                when RESET_ST =>
                    lcd_blk_reg <= '0';

                when others =>
                    lcd_blk_reg <= '1';

            end case;
        end if;
    end process;



    bit_cnt_processing : process(SCLK) 
    begin 
        if SCLK'event AND SCLK = '1' then 

            case (current_state) is 
                when TX_DATA_ST =>
                    if (bit_cnt < 7) then 
                        bit_cnt <= bit_cnt + 1;
                    else 
                        bit_cnt <= (others => '0');
                    end if;

                when others =>
                    bit_cnt <= (others => '0');

            end case;
        end if;
    end process;



    in_dout_data_shift_processing : process(SCLK) 
    begin 
        if SCLK'event AND SCLK = '1' then 

            case (current_state) is 
                when IDLE_ST =>
                    if (in_empty = '0') then 
                        in_dout_data_shift <= in_dout_data;
                    else 
                        in_dout_data_shift <= (others => '1');
                    end if;

                when TX_DATA_ST =>
                    if (bit_cnt = 7) then 
                        in_dout_data_shift <= in_dout_data;
                    else 
                        in_dout_data_shift <= in_dout_data_shift(6 downto 0) & '1';
                    end if;

                when others =>
                    in_dout_data_shift <= in_dout_data_shift;

            end case;
        end if;
    end process;



    in_dout_last_saved_processing : process(SCLK) 
    begin 
        if SCLK'event AND SCLK = '1' then 

            case (current_state) is 
                when IDLE_ST =>
                    if (in_empty = '0') then 
                        in_dout_last_saved <= in_dout_last;
                    end if;

                when TX_DATA_ST =>
                    if (bit_cnt = 7) then 
                        in_dout_last_saved <= in_dout_last;
                    end if;

                when others =>
                    in_dout_last_saved <= in_dout_last_saved;

            end case;
        end if;
    end process;



    in_dout_user_saved_processing : process(SCLK) 
    begin 
        if SCLK'event AND SCLK = '1' then 

            case (current_state) is 
                when IDLE_ST =>
                    if (in_empty = '0') then 
                        in_dout_user_saved <= in_dout_user;
                    else 
                        in_dout_user_saved <= '1';
                    end if;

                when TX_DATA_ST =>
                    if (bit_cnt = 7) then 
                        in_dout_user_saved <= in_dout_user;
                    end if;

                when others =>
                    in_dout_user_saved <= in_dout_user_saved;

            end case;
        end if;
    end process;



    in_rden_processing : process(SCLK) 
    begin 
        if SCLK'event AND SCLK = '1' then 

            case (current_state) is 
                when TX_DATA_ST =>
                    if (bit_cnt = 0) then 
                        in_rden <= '1';
                    else
                        in_rden <= '0';    
                    end if;

                when others =>
                    in_rden <= '0';

            end case;
        end if;
    end process;



    fifo_in_async_user_xpm_inst : fifo_in_async_user_xpm
        generic map (
            CDC_SYNC        =>  4           ,
            DATA_WIDTH      =>  8           ,
            USER_WIDTH      =>  1           ,
            MEMTYPE         =>  "block"     ,
            DEPTH           =>  16          
        )
        port map (
            S_AXIS_CLK      => CLK                              ,
            S_AXIS_RESET    => RESET                            ,
            M_AXIS_CLK      => SCLK                             ,
            
            S_AXIS_TDATA    => S_AXIS_TDATA                     ,
            S_AXIS_TKEEP(0) => S_AXIS_TKEEP                     ,
            S_AXIS_TUSER(0) => S_AXIS_TUSER                     ,
            S_AXIS_TVALID   => S_AXIS_TVALID                    ,
            S_AXIS_TLAST    => S_AXIS_TLAST                     ,
            S_AXIS_TREADY   => S_AXIS_TREADY                    ,

            IN_DOUT_DATA    => in_dout_data                     ,
            IN_DOUT_KEEP(0) => in_dout_keep                     ,
            IN_DOUT_USER(0) => in_dout_user                     ,
            IN_DOUT_LAST    => in_dout_last                     ,
            IN_RDEN         => in_rden                          ,
            IN_EMPTY        => in_empty                          
        );


    ODDR_inst : ODDR
        generic map(
            DDR_CLK_EDGE    => "OPPOSITE_EDGE"  , -- "OPPOSITE_EDGE" or "SAME_EDGE" 
            INIT            => '1'              ,   -- Initial value for Q port ('1' or '0')
            SRTYPE          => "SYNC"
        )
        port map (
            Q               =>  LCD_SCK         ,
            C               =>  SCLK            ,
            CE              =>  '1'             ,
            D1              =>  clk_en          ,
            D2              =>  '1'             ,
            R               =>  '0'             ,
            S               =>  '0'              
        );


end st7789_driver_vhd_arch;
