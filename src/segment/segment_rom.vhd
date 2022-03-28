library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use ieee.std_Logic_unsigned.all;
    use ieee.std_Logic_arith.all;


entity segment_rom is
    port(
        CLK         :   in      std_logic                               ;
        ADDRESS     :   in      std_logic_vector (  4 downto 0 )        ;
        START_PTR_X :   out     std_Logic_vector (  7 downto 0 )        ;
        END_PTR_X   :   out     std_Logic_vector (  7 downto 0 )        ;
        START_PTR_Y :   out     std_Logic_vector (  7 downto 0 )        ;
        END_PTR_Y   :   out     std_Logic_vector (  7 downto 0 )         
    );
end segment_rom;



architecture segment_rom_arch of segment_rom is
              
    type segment_rom_type is array ( 0 to 27 ) of std_logic_Vector ( 31 downto 0 );

    signal  segment_rom : segment_rom_type := (
        x"02110101", x"03100202", x"040F0303", x"050E0404",
        x"01010212", x"02020312", x"03030411", x"04040510",
        x"0f0f0510", x"10100411", x"11110312", x"12120212",
        x"040f1212", x"03101313", x"03101414", x"040f1515",
        x"01011525", x"02021524", x"03031623", x"04041722",
        x"0f0f1722", x"10101623", x"11111524", x"12121525",
        x"050e2323", x"040F2424", x"03102525", x"02112626"
    );

    signal data_out_reg : std_Logic_vector ( 31 downto 0 );

begin


    START_PTR_X <= data_out_reg( 31 downto 24);
    END_PTR_X   <= data_out_reg( 23 downto 16);
    START_PTR_Y <= data_out_reg( 15 downto  8);
    END_PTR_Y   <= data_out_reg(  7 downto  0);

    data_out_reg_processing : process(CLK)
    begin 
        if CLK'event AND CLK = '1' then 
            data_out_reg <= segment_rom(conv_integer(ADDRESS));
        end if;
    end process;


end segment_rom_arch;
