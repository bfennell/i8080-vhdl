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


------------------------------------------------------------
-- Register File
--
--  0: b     1:c
--  2: d     3:e
--  4: h     5:l
--  6: m     7:a
--  8: w     9:z
-- 10: act  11:tmp
-- 12: sph  13:spl => stack pointer
-- 14: pch  15:pcl => program counter
------------------------------------------------------------

entity cpu8080_regfile is

  port (clk_i    : in  std_logic;
        reset_i  : in  std_logic;
        cmd_i    : in  regfile_cmd_t;
        sel_a_i  : in  reg_t;
        sel_b_i  : in  reg_t;
        sel_rp_i : in  reg_pair_t;
        data_i   : in  unsigned(7 downto 0);
        reg_a_o  : out unsigned(7 downto 0);
        reg_b_o  : out unsigned(7 downto 0);
        reg_pc_o : out unsigned(15 downto 0);
        reg_rp_o : out unsigned(15 downto 0)
        );

end cpu8080_regfile;

architecture rtl of cpu8080_regfile is
  constant REGI_B   : integer := to_integer(REG_B);
  constant REGI_C   : integer := to_integer(REG_C);
  constant REGI_D   : integer := to_integer(REG_D);
  constant REGI_E   : integer := to_integer(REG_E);
  constant REGI_H   : integer := to_integer(REG_H);
  constant REGI_L   : integer := to_integer(REG_L);
  constant REGI_A   : integer := to_integer(REG_A);
  constant REGI_W   : integer := to_integer(REG_W);
  constant REGI_Z   : integer := to_integer(REG_Z);
  constant REGI_SPH : integer := to_integer(REG_SPH);
  constant REGI_SPL : integer := to_integer(REG_SPL);
  constant REGI_PCH : integer := to_integer(REG_PCH);
  constant REGI_PCL : integer := to_integer(REG_PCL);

  constant nr_regs : integer := 16;
  type regfile_t is array(0 to nr_regs-1) of unsigned(7 downto 0);
  signal regfile : regfile_t;

  -- debug signals
  signal regb_s   : unsigned(7 downto 0);
  signal regc_s   : unsigned(7 downto 0);
  signal regd_s   : unsigned(7 downto 0);
  signal rege_s   : unsigned(7 downto 0);
  signal regh_s   : unsigned(7 downto 0);
  signal regl_s   : unsigned(7 downto 0);
  signal rega_s   : unsigned(7 downto 0);
  signal regsph_s : unsigned(7 downto 0);
  signal regspl_s : unsigned(7 downto 0);
  signal regpch_s : unsigned(7 downto 0);
  signal regpcl_s : unsigned(7 downto 0);

begin

  control: process(clk_i,reset_i)
    variable cmd_reg_a : integer range 0 to nr_regs-1;
    variable cmd_reg_b : integer range 0 to nr_regs-1;

    variable inc_val : unsigned(15 downto 0);
    variable inc_b   : unsigned(15 downto 0);
  begin
    if reset_i = '1' then
      regfile  <= (others=> (others=>'0'));
    elsif clk_i'event and clk_i = '1' then
      cmd_reg_a := to_integer(cmd_i.reg_a);
      cmd_reg_b := to_integer(cmd_i.reg_b);

      -- write
      if cmd_i.wr = '1' then
        regfile(cmd_reg_a) <= data_i;
      -- mov
      elsif cmd_i.mov = '1' then
        regfile(cmd_reg_a) <= regfile(cmd_reg_b);
      -- XCHG
      elsif cmd_i.xchg = '1' then
        regfile(REGI_D) <= regfile(REGI_H);
        regfile(REGI_E) <= regfile(REGI_L);
        regfile(REGI_H) <= regfile(REGI_D);
        regfile(REGI_L) <= regfile(REGI_E);
      end if;

      -- inc/dec
      if cmd_i.decrp = '1' then
        inc_b := x"ffff";
      else
        inc_b := x"0001";
      end if;

      if cmd_i.incpc = '1' then
        inc_val := ((regfile(REGI_PCH) & regfile(REGI_PCL)) + inc_b);
        regfile(REGI_PCH) <= inc_val(15 downto 8);
        regfile(REGI_PCL) <= inc_val(7 downto 0);
      elsif cmd_i.incrp = '1' or cmd_i.decrp = '1' then
        inc_val := ((regfile(cmd_reg_a) & regfile(cmd_reg_b)) + inc_b);
        regfile(cmd_reg_a) <= inc_val(15 downto 8);
        regfile(cmd_reg_b) <= inc_val(7 downto 0);
      end if;

    end if;
  end process;

  -- portA, portB output
  reg_a_o <= regfile(to_integer(sel_a_i));
  reg_b_o <= regfile(to_integer(sel_b_i));

  -- PC output
  reg_pc_o <= (regfile(REGI_PCH) & regfile(REGI_PCL));

  -- PC,SP,BC,DE,HL output
  with sel_rp_i select reg_rp_o <=
    (regfile(REGI_PCH) & regfile(REGI_PCL)) when REG_PC,
    (regfile(REGI_SPH) & regfile(REGI_SPL)) when REG_SP,
    (regfile(REGI_B)   & regfile(REGI_C))   when REG_BC,
    (regfile(REGI_D)   & regfile(REGI_E))   when REG_DE,
    (regfile(REGI_H)   & regfile(REGI_L))   when REG_HL,
    (regfile(REGI_W)   & regfile(REGI_Z))   when REG_WZ,
    (regfile(REGI_H)   & regfile(REGI_L))   when others;

  -- debug signals
  regb_s   <= regfile(REGI_B);
  regc_s   <= regfile(REGI_C);
  regd_s   <= regfile(REGI_D);
  rege_s   <= regfile(REGI_E);
  regh_s   <= regfile(REGI_H);
  regl_s   <= regfile(REGI_L);
  rega_s   <= regfile(REGI_A);
  regsph_s <= regfile(REGI_SPH);
  regspl_s <= regfile(REGI_SPL);
  regpch_s <= regfile(REGI_PCH);
  regpcl_s <= regfile(REGI_PCL);

end rtl;
