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

entity invaders_counter is
  port( clk_i : in std_logic;
        rst_i : in std_logic;
        int_o : out std_logic
      );
end invaders_counter;

architecture beh of invaders_counter is
  constant HZ60DIV2 : integer := 83333;
  signal cnt_rg : integer;
  signal int_rg : std_logic;
begin
  counter: process(clk_i) is
  begin
    if (clk_i'event and clk_i = '1') then
      --
      if rst_i = '1' then
        cnt_rg <= 0;
        int_rg <= '0';
      else
        --
        if cnt_rg = HZ60DIV2 then
          int_rg <= '1';
          cnt_rg <= 0;
        else
          cnt_rg <= cnt_rg + 1;
        end if;
        --
        if int_rg = '1' then
          int_rg <= '0';
        end if;
      end if;
    end if;
  end process;
  --
  int_o <= int_rg;
end beh;
