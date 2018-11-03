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

entity invaders_inputs is
  port( clk_i   : in std_logic;
        rst_i   : in std_logic;
        nwr_i   : in std_logic;
        sel_i   : in std_logic_vector(7 downto 0);
        data_i  : in std_logic_vector(7 downto 0);
        rdy_o   : out std_logic;
        data_o  : out std_logic_vector(7 downto 0)
      );
end invaders_inputs;

architecture beh of invaders_inputs is
  -- IN Port 1
  signal cred_rg : std_logic;
  signal p2_rg   : std_logic;
  signal p1_rg   : std_logic;
  signal bit13   : std_logic;
  signal p1s_rg  : std_logic; -- p1 Shot
  signal p1l_rg  : std_logic; -- p1 Left
  signal p1r_rg  : std_logic; -- p1 Right
  signal bit17   : std_logic;

  -- IN Port 2
  signal dip3   : std_logic;
  signal dip5   : std_logic;
  signal tilt   : std_logic;
  signal dip6   : std_logic;
  signal p2s_rg : std_logic; -- p2 Shot
  signal p2l_rg : std_logic; -- p2 Left
  signal p2r_rg : std_logic; -- p2 Right
  signal dip7   : std_logic;

  --
  signal sel_rg : std_logic_vector(1 downto 0);
  signal rdy_rg : std_logic;
begin

  shifter: process(clk_i) is
  begin
    if (clk_i'event and clk_i = '1') then
      if rst_i = '1' then
        cred_rg <= '0';
        p2_rg   <= '0';
        p1_rg   <= '0';
        bit13   <= '0';
        p1s_rg  <= '0';
        p1l_rg  <= '0';
        p1r_rg  <= '0';
        bit17   <= '0';
        dip3    <= '1';
        dip5    <= '1';
        tilt    <= '0';
        dip6    <= '1';
        p2s_rg  <= '0';
        p2l_rg  <= '0';
        p2r_rg  <= '0';
        dip7    <= '0';
        --
        sel_rg  <= "00";
        rdy_rg  <= '0';
      else
        -- IN Port 1
        if sel_i = x"01" and nwr_i = '1' then
          sel_rg <= "01";
          rdy_rg <= '1';

        -- IN Port 2
        elsif sel_i = x"02" and nwr_i = '1' then
          sel_rg <= "10";
          rdy_rg <= '1';

        end if;

        --
        if rdy_rg = '1' then
          sel_rg <= "00";
          rdy_rg <= '0';
        end if;

      end if;
    end if;
  end process;

  --
  data_o <= (bit17 & p1r_rg & p1l_rg & p1s_rg & bit13 & p1_rg & p2_rg & cred_rg) when sel_rg = "01" else
            (dip7 & p2r_rg & p2l_rg & p2s_rg & dip6 & tilt & dip5 & dip3)        when sel_rg = "10" else
            (others => '0');

  rdy_o <= rdy_rg;
end beh;
