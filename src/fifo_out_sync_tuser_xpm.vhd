library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use ieee.std_logic_unsigned.all;
    use ieee.std_logic_arith.all;
    use IEEE.math_real."ceil";
    use IEEE.math_real."log2";

library UNISIM;
    use UNISIM.VComponents.all;

Library xpm;
    use xpm.vcomponents.all;



entity fifo_out_sync_tuser_xpm is
    generic(
        DATA_WIDTH      :           integer         :=  16                          ;
        USER_WIDTH      :           integer         :=  1                           ;
        MEMTYPE         :           String          :=  "block"                     ;
        DEPTH           :           integer         :=  16                           
    );
    port(
        CLK             :   in      std_logic                                       ;
        RESET           :   in      std_logic                                       ;
        
        OUT_DIN_DATA    :   in      std_logic_Vector ( DATA_WIDTH-1 downto 0 )      ;
        OUT_DIN_KEEP    :   in      std_logic_Vector ( ( DATA_WIDTH/8)-1 downto 0 ) ;
        OUT_DIN_USER    :   in      std_logic_Vector ( USER_WIDTH-1 downto 0 )      ;
        OUT_DIN_LAST    :   in      std_logic                                       ;
        OUT_WREN        :   in      std_logic                                       ;
        OUT_FULL        :   out     std_logic                                       ;
        OUT_AWFULL      :   out     std_logic                                       ;
        
        M_AXIS_TDATA    :   out     std_logic_Vector ( DATA_WIDTH-1 downto 0 )      ;
        M_AXIS_TKEEP    :   out     std_logic_Vector (( DATA_WIDTH/8)-1 downto 0 )  ;
        M_AXIS_TUSER    :   out     std_logic_vector ( USER_WIDTH-1 downto 0 )      ;
        M_AXIS_TVALID   :   out     std_logic                                       ;
        M_AXIS_TLAST    :   out     std_logic                                       ;
        M_AXIS_TREADY   :   in      std_logic                                        

    );
end fifo_out_sync_tuser_xpm;



architecture fifo_out_sync_tuser_xpm_arch of fifo_out_sync_tuser_xpm is

    constant VERSION : string := "v1.0";

    constant FIFO_WIDTH :           integer := (DATA_WIDTH + ((DATA_WIDTH/8) + 1)) + USER_WIDTH;
    constant FIFO_DATA_COUNT_W  :   integer := integer(ceil(log2(real(DEPTH))));

    ATTRIBUTE X_INTERFACE_INFO : STRING;
    ATTRIBUTE X_INTERFACE_INFO of RESET: SIGNAL is "xilinx.com:signal:reset:1.0 RESET RST";
    ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
    ATTRIBUTE X_INTERFACE_PARAMETER of RESET: SIGNAL is "POLARITY ACTIVE_HIGH";

    
    signal  din         :           std_logic_vector ( FIFO_WIDTH-1 downto 0 ) ;
    signal  dout        :           std_logic_vector ( FIFO_WIDTH-1 downto 0 ) ;
    
    signal  empty       :           std_logic                                   ;
    signal  rden        :           std_logic                                   ;
begin


    rden <= '1' when empty = '0' and M_AXIS_TREADY = '1' else '0';
   
    M_AXIS_TDATA <= dout( DATA_WIDTH-1 downto 0 ) ;
    M_AXIS_TKEEP <= dout( ((DATA_WIDTH + (DATA_WIDTH/8))-1) downto DATA_WIDTH );
    M_AXIS_TLAST <= dout( DATA_WIDTH + (DATA_WIDTH/8));
    M_AXIS_TUSER <= dout( FIFO_WIDTH-1 downto (FIFO_WIDTH-USER_WIDTH));
    M_AXIS_TVALID <= not (empty)    ;

    din <= OUT_DIN_USER & OUT_DIN_LAST & OUT_DIN_KEEP & OUT_DIN_DATA;
    

    fifo_out_xpm_isnt : xpm_fifo_sync
        generic map (
            DOUT_RESET_VALUE        =>  "0"                 ,
            ECC_MODE                =>  "no_ecc"            ,
            FIFO_MEMORY_TYPE        =>  MEMTYPE             ,
            FIFO_READ_LATENCY       =>  0                   ,
            FIFO_WRITE_DEPTH        =>  DEPTH               ,
            FULL_RESET_VALUE        =>  1                   ,
            PROG_EMPTY_THRESH       =>  10                  ,
            PROG_FULL_THRESH        =>  10                  ,
            RD_DATA_COUNT_WIDTH     =>  FIFO_DATA_COUNT_W   ,   -- DECIMAL
            READ_DATA_WIDTH         =>  FIFO_WIDTH          ,
            READ_MODE               =>  "fwft"              ,
            USE_ADV_FEATURES        =>  "0008"              ,
            WAKEUP_TIME             =>  0                   ,
            WRITE_DATA_WIDTH        =>  FIFO_WIDTH          ,
            WR_DATA_COUNT_WIDTH     =>  FIFO_DATA_COUNT_W       -- DECIMAL
        )
        port map (
            almost_empty            =>  open                ,
            almost_full             =>  OUT_AWFULL          ,
            data_valid              =>  open                ,
            dbiterr                 =>  open                ,
            dout                    =>  DOUT                ,
            empty                   =>  empty               ,
            full                    =>  OUT_FULL            ,
            overflow                =>  open                ,
            prog_empty              =>  open                ,
            prog_full               =>  open                ,
            rd_data_count           =>  open                ,
            rd_rst_busy             =>  open                ,
            sbiterr                 =>  open                ,
            underflow               =>  open                ,
            wr_ack                  =>  open                ,
            wr_data_count           =>  open                ,
            wr_rst_busy             =>  open                ,
            din                     =>  din                 ,
            injectdbiterr           =>  '0'                 ,
            injectsbiterr           =>  '0'                 ,
            rd_en                   =>  rden                ,
            rst                     =>  RESET               ,
            sleep                   =>  '0'                 ,
            wr_clk                  =>  CLK                 ,
            wr_en                   =>  OUT_WREN             
        );



end fifo_out_sync_tuser_xpm_arch;
