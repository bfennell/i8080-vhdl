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
use ieee.numeric_std.all;


entity cpu8080_ctrlreg is

  port (clk_i       : in  std_logic;
        reset_i     : in  std_logic;
        cmd_i       : in  ctrlreg_cmd_t;
        instr_o     : out unsigned(7 downto 0);
        alu_flags_i : in  alu_flags_t;
        alu_flags_o : out alu_flags_t;
        inten_o     : out std_logic;
        psw_o       : out unsigned(7 downto 0);
        data_i      : in  unsigned(7 downto 0)
        );

end cpu8080_ctrlreg;

architecture rtl of cpu8080_ctrlreg is
  signal instr_rg : unsigned(7 downto 0);
  signal alu_flags_rg : alu_flags_t;
  signal alu_flags_tmp_rg : alu_flags_t;
  signal inten_rg : std_logic;

begin

  reg: process(clk_i,reset_i)
  begin
    if reset_i = '1' then
      instr_rg <= (others => '0');
      alu_flags_rg <= alu_flags_null_c;
      alu_flags_tmp_rg <= alu_flags_null_c;
      inten_rg <= '0';
    elsif clk_i'event and clk_i = '1' then
      --
      if cmd_i.instr_wr = '1' then
        instr_rg <= data_i;
      end if;

      if cmd_i.alu_flags_store = '1' then
        alu_flags_rg <= alu_flags_tmp_rg;
      end if;

      if cmd_i.alu_flags_wr = '1' then
        alu_flags_tmp_rg <= alu_flags_i;
      end if;

      if cmd_i.alu_carry_wr = '1' then
        alu_flags_tmp_rg.carry <= alu_flags_i.carry;
      end if;

      if cmd_i.alu_carry_set = '1' then
        alu_flags_tmp_rg.carry <= cmd_i.val;
      end if;

      if cmd_i.alu_psw_wr = '1' then
        alu_flags_tmp_rg.carry     <= data_i(0);
        alu_flags_tmp_rg.parity    <= data_i(2);
        alu_flags_tmp_rg.aux_carry <= data_i(4);
        alu_flags_tmp_rg.zero      <= data_i(6);
        alu_flags_tmp_rg.sign      <= data_i(7);
      end if;

      if cmd_i.inten_set = '1' then
        inten_rg <= cmd_i.val;
      end if;

    end if;
  end process;

  --
  instr_o <= instr_rg;
  --
  alu_flags_o <= alu_flags_rg;
  --
  inten_o <= inten_rg;
  --
  psw_o <= (alu_flags_rg.sign      &
            alu_flags_rg.zero      & "0" &
            alu_flags_rg.aux_carry & "0" &
            alu_flags_rg.parity    & "1" &
            alu_flags_rg.carry);
end rtl;
