library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use ieee.std_Logic_unsigned.all;
    use ieee.std_Logic_arith.all;


entity digit_rom is
    port(
        CLK         :   in      std_logic                               ;
        DIGIT_ADDR  :   in      std_logic_vector ( 8 downto 0 )         ;
        SYMBOL_ADDR :   in      std_logic_vector ( 4 downto 0 )         ;
        DATA_OUT    :   out     std_Logic                                
    );
end digit_rom;



architecture digit_rom_arch of digit_rom is
              
    type digit_rom_type is array ( 0 to 399 ) of std_logic_Vector ( 0 to 19 );

    signal  digit_rom : digit_rom_type := (

        x"00000", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"7801E", x"7801E", x"7801E",
        x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E",
        x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E",
        x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E",
        x"7801E", x"7801E", x"7801E", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"00000",

        x"00000", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"00000",

        x"00000", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"78000", x"78000",
        x"78000", x"78000", x"78000", x"78000", x"78000", x"78000", x"78000", x"78000",
        x"78000", x"78000", x"78000", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"00000",

        x"00000", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"00000",

        x"00000", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E",
        x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E",
        x"7801E", x"7801E", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"00000",

        x"00000", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"78000", x"78000", x"78000",
        x"78000", x"78000", x"78000", x"78000", x"78000", x"78000", x"78000", x"78000",
        x"78000", x"78000", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"00000",

        x"00000", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"78000", x"78000", x"78000",
        x"78000", x"78000", x"78000", x"78000", x"78000", x"78000", x"78000", x"78000",
        x"78000", x"78000", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"7801E", x"7801E",
        x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E",
        x"7801E", x"7801E", x"7801E", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"00000",

        x"00000", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"00000",

        x"00000", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"7801E", x"7801E", x"7801E",
        x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E",
        x"7801E", x"7801E", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"7801E", x"7801E",
        x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E",
        x"7801E", x"7801E", x"7801E", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"00000",

        x"00000", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"7801E", x"7801E", x"7801E",
        x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E", x"7801E",
        x"7801E", x"7801E", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E", x"0001E",
        x"0001E", x"0001E", x"0001E", x"7FFFE", x"7FFFE", x"7FFFE", x"7FFFE", x"00000"
    );

    signal data_out_reg : std_Logic := '0';

begin

    DATA_OUT <= data_out_reg;

    data_out_reg_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 
            data_out_reg <= digit_rom(conv_integer(DIGIT_ADDR))(conv_integer(SYMBOL_ADDR));
        end if;
    end process;


end digit_rom_arch;
