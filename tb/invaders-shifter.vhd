-- Copyright (c) 2018 Brendan Fennell <bfennell@skynet.ie>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity invaders_shifter is
  port( clk_i   : in std_logic;
        rst_i   : in std_logic;
        nwr_i   : in std_logic;
        sel_i   : in std_logic_vector(7 downto 0);
        data_i  : in std_logic_vector(7 downto 0);
        rdy_o   : out std_logic;
        data_o  : out std_logic_vector(7 downto 0)
      );
end invaders_shifter;

architecture beh of invaders_shifter is
  signal shift_rg  : std_logic_vector(15 downto 0);
  signal amount_rg : std_logic_vector(2 downto 0);
  signal rdy_rg    : std_logic;
  signal en_s      : std_logic;
begin

  shifter: process(clk_i) is
  begin
    if (clk_i'event and clk_i = '1') then
      if rst_i = '1' then
        shift_rg <= (others => '0');
        amount_rg <= (others => '0');
        rdy_rg <= '0';
      else
        -- OUT Port 2: Write: set shift amount
        if en_s = '1' and sel_i = x"02" and nwr_i = '0' then
          amount_rg <= data_i(2 downto 0);
          rdy_rg <= '1';

        -- OUT Port 4: Write: shift in
        elsif en_s = '1' and sel_i = x"04" and nwr_i = '0' then
          shift_rg <= (data_i & shift_rg(15 downto 8));
          rdy_rg <= '1';

        -- IN Port 3: Read: shifted value
        elsif en_s = '1' and sel_i = x"03" and nwr_i = '1' then
          rdy_rg <= '1';
        end if;

        --
        if rdy_rg = '1' then
          rdy_rg <= '0';
        end if;

      end if;
    end if;
  end process;

  en_s <= (not rdy_rg);

  rdy_o <= rdy_rg;

  data_o <= shift_rg(15 downto 8) when amount_rg = "000" else
            shift_rg(14 downto 7) when amount_rg = "001" else
            shift_rg(13 downto 6) when amount_rg = "010" else
            shift_rg(12 downto 5) when amount_rg = "011" else
            shift_rg(11 downto 4) when amount_rg = "100" else
            shift_rg(10 downto 3) when amount_rg = "101" else
            shift_rg(9  downto 2) when amount_rg = "110" else
            shift_rg(8  downto 1) when amount_rg = "111" else
            (others => '0');
end beh;
