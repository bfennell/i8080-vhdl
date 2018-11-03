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

library work;
use work.cpu8080_types.all;

library ieee;
use ieee.std_logic_1164.all;

entity invaders_timer is

  port (clk_i  : in  std_logic;
        rst_i  : in  std_logic;
        inta_i : in  std_logic;
        int_o  : out std_logic;
        nnn_o  : out std_logic_vector(2 downto 0));

end invaders_timer;

architecture beh of invaders_timer is

  component invaders_counter
    port( clk_i : in std_logic;
          rst_i : in std_logic;
          int_o : out std_logic);
  end component;

  signal sel_s  : std_logic;
  signal int_s  : std_logic;
  signal int_rg : std_logic;
  signal nnn_rg : std_logic_vector(2 downto 0);

begin

  inst_counter: invaders_counter port map (
    clk_i => clk_i,
    rst_i => rst_i,
    int_o => int_s
    );

  timer_p: process(clk_i)
  begin
    if clk_i'event and clk_i = '1' then
      if rst_i = '1' then
        int_rg <= '0';
        nnn_rg <= (others => '0');
        sel_s  <= '0';
      else
        --
        if int_s = '1' then
          int_rg <= '1';
        end if;
        --
        if int_rg = '1' and inta_i = '1' then
          int_rg <= '0';
          sel_s <= not sel_s;
        end if;
      end if;
    end if;
  end process;

  --
  int_o <= int_rg;

  nnn_o <= "001" when int_rg = '1' and sel_s = '0' else
           "010" when int_rg = '1' and sel_s = '1' else
           (others => '0');
end beh;
