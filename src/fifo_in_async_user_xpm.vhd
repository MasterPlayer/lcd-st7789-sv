library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use ieee.std_logic_unsigned.all;
    use ieee.std_logic_arith.all;
    use IEEE.math_real."ceil";
    use IEEE.math_real."log2";

Library xpm;
    use xpm.vcomponents.all;



entity fifo_in_async_user_xpm is
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
end fifo_in_async_user_xpm;



architecture fifo_in_async_user_xpm_arch of fifo_in_async_user_xpm is

    constant VERSION            :           string := "v1.0";

    constant FIFO_DATA_COUNT_W  :           integer := integer(ceil(log2(real(DEPTH))))                         ;
    constant FIFO_WIDTH         :           integer := ((DATA_WIDTH + (DATA_WIDTH/8)) + 1) + USER_WIDTH         ;

    signal  full                :           std_logic                                                           ;
    signal  din                 :           std_logic_vector ( FIFO_WIDTH-1 downto 0 )                          ;
    signal  dout                :           std_logic_vector ( FIFO_WIDTH-1 downto 0 )                          ;
    
    signal  wren                :           std_logic                                   := '0'                  ;

begin

    

    S_AXIS_TREADY <= not (full);
    wren <= '1' when full = '0' and S_AXIS_TVALID = '1' else '0' ;

    din <= S_AXIS_TUSER & S_AXIS_TLAST & S_AXIS_TKEEP & S_AXIS_TDATA;

    
    IN_DOUT_DATA <= dout( DATA_WIDTH-1 downto 0 ) ;
    IN_DOUT_KEEP <= dout( ((DATA_WIDTH + (DATA_WIDTH/8))-1) downto DATA_WIDTH );
    IN_DOUT_LAST <= dout( DATA_WIDTH + (DATA_WIDTH/8));
    IN_DOUT_USER <= dout(FIFO_WIDTH-1 downto (FIFO_WIDTH - USER_WIDTH));


    xpm_fifo_async_inst : xpm_fifo_async
        generic map (
            CDC_SYNC_STAGES       =>  CDC_SYNC              ,   -- DECIMAL
            DOUT_RESET_VALUE      =>  "0"                   ,   -- String
            ECC_MODE              =>  "no_ecc"              ,   -- String
            FIFO_MEMORY_TYPE      =>  "MEMTYPE"             ,   -- String
            FIFO_READ_LATENCY     =>  0                     ,   -- DECIMAL
            FIFO_WRITE_DEPTH      =>  DEPTH                 ,   -- DECIMAL
            FULL_RESET_VALUE      =>  1                     ,   -- DECIMAL
            PROG_EMPTY_THRESH     =>  10                    ,   -- DECIMAL
            PROG_FULL_THRESH      =>  10                    ,   -- DECIMAL
            RD_DATA_COUNT_WIDTH   =>  FIFO_DATA_COUNT_W     ,   -- DECIMAL
            READ_DATA_WIDTH       =>  FIFO_WIDTH            ,   -- DECIMAL
            READ_MODE             =>  "fwft"                 ,   -- String
            RELATED_CLOCKS        =>  0                     ,   -- DECIMAL
            SIM_ASSERT_CHK        =>  0                     ,   -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            USE_ADV_FEATURES      =>  "0000"                ,   -- String
            WAKEUP_TIME           =>  0                     ,   -- DECIMAL
            WRITE_DATA_WIDTH      =>  FIFO_WIDTH            ,   -- DECIMAL
            WR_DATA_COUNT_WIDTH   =>  FIFO_DATA_COUNT_W         -- DECIMAL
        )
        port map (
            almost_empty          =>  open                  ,   -- 1-bit output: Almost Empty : When asserted, this signal indicates that
            almost_full           =>  open                  ,   -- 1-bit output: Almost Full: When asserted, this signal indicates that
            data_valid            =>  open                  ,   -- 1-bit output: Read Data Valid: When asserted, this signal indicates
            dbiterr               =>  open                  ,   -- 1-bit output: Double Bit Error: Indicates that the ECC decoder
            dout                  =>  DOUT                  ,   -- READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
            empty                 =>  IN_EMPTY              ,   -- 1-bit output: Empty Flag: When asserted, this signal indicates that
            full                  =>  full                  ,   -- 1-bit output: Full Flag: When asserted, this signal indicates that the
            overflow              =>  open                  ,   -- 1-bit output: Overflow: This signal indicates that a write request
            prog_empty            =>  open                  ,   -- 1-bit output: Programmable Empty: This signal is asserted when the
            prog_full             =>  open                  ,   -- 1-bit output: Programmable Full: This signal is asserted when the
            rd_data_count         =>  open                  ,   -- RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates
            rd_rst_busy           =>  open                  ,   -- 1-bit output: Read Reset Busy: Active-High indicator that the FIFO
            sbiterr               =>  open                  ,   -- 1-bit output: Single Bit Error: Indicates that the ECC decoder
            underflow             =>  open                  ,   -- 1-bit output: Underflow: Indicates that the read request (rd_en)
            wr_ack                =>  open                  ,   -- 1-bit output: Write Acknowledge: This signal indicates that a write
            wr_data_count         =>  open                  ,   -- WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
            wr_rst_busy           =>  open                  ,   -- 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
            din                   =>  din                   ,   -- WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
            injectdbiterr         =>  '0'                   ,   -- 1-bit input: Double Bit Error Injection: Injects a double bit error if
            injectsbiterr         =>  '0'                   ,   -- 1-bit input: Single Bit Error Injection: Injects a single bit error if
            rd_clk                =>  M_AXIS_CLK            ,   -- 1-bit input: Read clock: Used for read operation. rd_clk must be a
            rd_en                 =>  IN_RDEN               ,   -- 1-bit input: Read Enable: If the FIFO is not empty, asserting this
            rst                   =>  S_AXIS_RESET          ,   -- 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
            sleep                 =>  '0'                   ,   -- 1-bit input: Dynamic power saving: If sleep is High, the memory/fifo
            wr_clk                =>  S_AXIS_CLK            ,   -- 1-bit input: Write clock: Used for write operation. wr_clk must be a
            wr_en                 =>  wren                      -- 1-bit input: Write Enable: If the FIFO is not full, asserting this
        );

            
end fifo_in_async_user_xpm_arch;
