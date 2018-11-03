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

entity cpu8080_top is

  port (clk_i      : in  std_logic;
        reset_i    : in  std_logic;
        ready_i    : in  std_logic;
        int_i      : in  std_logic;
        nnn_i      : in  std_logic_vector(2 downto 0);
        data_i     : in  std_logic_vector(7 downto 0);
        port_i     : in  std_logic_vector(7 downto 0);
        port_rdy_i : in  std_logic;
        inta_o     : out std_logic;
        sel_o      : out std_logic;
        nwr_o      : out std_logic;
        addr_o     : out std_logic_vector(15 downto 0);
        data_o     : out std_logic_vector(7 downto 0);
        port_o     : out std_logic_vector(7 downto 0);
        port_nwr_o : out std_logic;
        port_sel_o : out std_logic_vector(7 downto 0)
        );

end cpu8080_top;

architecture rtl of cpu8080_top is

  component cpu8080_regfile
    port (clk_i     : in  std_logic;
          reset_i   : in  std_logic;
          cmd_i     : in  regfile_cmd_t;
          sel_a_i   : in  reg_t;
          sel_b_i   : in  reg_t;
          sel_rp_i  : in  reg_pair_t;
          data_i    : in  unsigned(7 downto 0);
          reg_a_o   : out unsigned(7 downto 0);
          reg_b_o   : out unsigned(7 downto 0);
          reg_pc_o  : out unsigned(15 downto 0);
          reg_rp_o  : out unsigned(15 downto 0));
  end component;

  component cpu8080_alu
    port (alu_op_i    : in  alu_op_t;
          alu_a_i     : in  unsigned(7 downto 0);
          alu_b_i     : in  unsigned(7 downto 0);
          alu_flags_i : in  alu_flags_t;
          alu_flags_o : out alu_flags_t;
          alu_out_o   : out unsigned(7 downto 0));
  end component;

  component cpu8080_ctrlreg
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
  end component;

  component cpu8080_control
    port (clk_i         : in  std_logic;
          reset_i       : in  std_logic;
          --
          int_i         : in  std_logic;
          nnn_i         : in  std_logic_vector(2 downto 0);
          --
          alu_op_o      : out alu_op_t;
          inta_o        : out std_logic;
          --
          regfile_din_sel_o : out std_logic_vector(1 downto 0);
          regfile_sel_a_o  : out reg_t;
          regfile_sel_b_o  : out reg_t;
          regfile_sel_rp_o : out reg_pair_t;
          regfile_cmd_o    : out regfile_cmd_t;
          --
          ctrl_o        : out unsigned(7 downto 0);
          --
          ctrlreg_cmd_o       : out ctrlreg_cmd_t;
          ctrlreg_instr_i     : in unsigned(7 downto 0);
          ctrlreg_alu_flags_i : in alu_flags_t;
          ctrlreg_inten_i     : std_logic;
          --
          munit_rdy_i     : in  std_logic;
          munit_wr_o      : out std_logic;
          munit_rd_o      : out std_logic;
          munit_ain_sel_o : out std_logic;
          munit_din_sel_o : out std_logic_vector(2 downto 0);
          --
          port_rdy_i : in  std_logic;
          port_rd_o  : out std_logic;
          port_wr_o  : out std_logic
          );
  end component;

  signal munit_wr      : std_logic;
  signal munit_rd      : std_logic;
  signal munit_ain_sel : std_logic;
  signal munit_din_sel : std_logic_vector(2 downto 0);

  -- Control <=> Regfile
  signal reg_din_sel   : std_logic_vector(1 downto 0);
  signal reg_sel_a     : reg_t;
  signal reg_sel_b     : reg_t;
  signal reg_sel_rp    : reg_pair_t;
  signal reg_cmd       : regfile_cmd_t;
  signal reg_in        : unsigned(7 downto 0);
  signal reg_a         : unsigned(7 downto 0);
  signal reg_b         : unsigned(7 downto 0);
  signal reg_pc        : unsigned(15 downto 0);
  signal reg_rp        : unsigned(15 downto 0);
  signal alu_op        : alu_op_t;
  signal alu_flags_in  : alu_flags_t;
  signal alu_out       : unsigned(7 downto 0);
  signal alu_flags_out : alu_flags_t;
  --
  signal ctrlreg_cmd   : ctrlreg_cmd_t;
  signal ctrlreg_instr : unsigned(7 downto 0);
  signal ctrlreg_inten : std_logic;
  signal ctrlreg_psw   : unsigned(7 downto 0);
  --
  signal port_rd : std_logic;
  signal port_wr : std_logic;
  signal port_sel_rg : std_logic_vector(7 downto 0);
  signal port_dat_rg : std_logic_vector(7 downto 0);
  signal port_nwr_rg : std_logic;
  --
  signal ctrl_out : unsigned(7 downto 0);

begin

  inst_regfile: cpu8080_regfile port map (
    clk_i    => clk_i,
    reset_i  => reset_i,
    cmd_i    => reg_cmd,
    sel_a_i  => reg_sel_a,
    sel_b_i  => reg_sel_b,
    sel_rp_i => reg_sel_rp,
    data_i   => reg_in,
    reg_a_o  => reg_a,
    reg_b_o  => reg_b,
    reg_pc_o => reg_pc,
    reg_rp_o => reg_rp
    );

  inst_alu: cpu8080_alu port map (
    alu_op_i    => alu_op,
    alu_a_i     => reg_a,
    alu_b_i     => reg_b,
    alu_flags_i => alu_flags_in,
    alu_flags_o => alu_flags_out,
    alu_out_o   => alu_out
    );

  inst_ctrlreg: cpu8080_ctrlreg port map (
    clk_i       => clk_i,
    reset_i     => reset_i,
    cmd_i       => ctrlreg_cmd,
    instr_o     => ctrlreg_instr,
    alu_flags_i => alu_flags_out,
    alu_flags_o => alu_flags_in,
    inten_o     => ctrlreg_inten,
    psw_o       => ctrlreg_psw,
    data_i      => unsigned(data_i)
      );

  inst_ctrl: cpu8080_control port map (
    clk_i   => clk_i,
    reset_i => reset_i,
    --
    int_i => int_i,
    nnn_i => nnn_i,
    --
    alu_op_o => alu_op,
    inta_o   => inta_o,
    --
    regfile_din_sel_o => reg_din_sel,
    regfile_sel_a_o  => reg_sel_a,
    regfile_sel_b_o  => reg_sel_b,
    regfile_sel_rp_o => reg_sel_rp,
    regfile_cmd_o    => reg_cmd,
    --
    ctrl_o => ctrl_out,
    --
    ctrlreg_cmd_o       => ctrlreg_cmd,
    ctrlreg_instr_i     => ctrlreg_instr,
    ctrlreg_alu_flags_i => alu_flags_in,
    ctrlreg_inten_i     => ctrlreg_inten,
    --
    munit_rdy_i     => ready_i,
    munit_wr_o      => munit_wr,
    munit_rd_o      => munit_rd,
    munit_ain_sel_o => munit_ain_sel,
    munit_din_sel_o => munit_din_sel,
    --
    port_rdy_i => port_rdy_i,
    port_rd_o  => port_rd,
    port_wr_o  => port_wr
    );

  ----------------------------------------------------------
  port_reg: process(clk_i,reset_i)
  begin
    --
    if reset_i = '1' then
      port_sel_rg <= (others => '0');
      port_dat_rg <= (others => '0');
      port_nwr_rg <= '1';
    elsif clk_i'event and clk_i = '1' then
      --
      if (port_rd = '1' or port_wr = '1') then
        port_sel_rg <= data_i;
        port_dat_rg <= std_logic_vector(reg_a);
        --
        if (port_wr = '1') then
          port_nwr_rg <= '0';
        end if;
      end if;
      --
      if (port_rdy_i = '1') then
        port_sel_rg <= (others => '0');
        port_dat_rg <= (others => '0');
        port_nwr_rg <= '1';
      end if;
    end if;
  end process;

  --
  port_o     <= port_dat_rg;
  port_sel_o <= port_sel_rg;
  port_nwr_o <= port_nwr_rg;

  -- Memory Select
  sel_o <= (munit_rd or munit_wr);

  -- Memory Read/Write
  nwr_o <= '1' when munit_rd = '1' else
           '0' when munit_wr = '1' else
           '1';

  -- Memory Address Out
  addr_o <= std_logic_vector(reg_pc) when (munit_ain_sel = MUNIT_AIN_SEL_PC) else
            std_logic_vector(reg_rp) when (munit_ain_sel = MUNIT_AIN_SEL_RP) else
            (others => '0');

  -- Memory Data Out
  data_o <= std_logic_vector(reg_a)       when (munit_din_sel = MUNIT_DIN_SEL_REGA)  else
            std_logic_vector(reg_b)       when (munit_din_sel = MUNIT_DIN_SEL_REGB)  else
            std_logic_vector(alu_out)     when (munit_din_sel = MUNIT_DIN_SEL_ALUO)  else
            std_logic_vector(ctrl_out)    when (munit_din_sel = MUNIT_DIN_SEL_CTRLO) else
            std_logic_vector(ctrlreg_psw) when (munit_din_sel = MUNIT_DIN_SEL_PSW)   else
            (others => '0');

  -- Register File Data In
  reg_in <= unsigned(data_i) when (reg_din_sel = REGF_DIN_SEL_MDATA) else
            alu_out          when (reg_din_sel = REGF_DIN_SEL_ALUO)  else
            ctrl_out         when (reg_din_sel = REGF_DIN_SEL_CTRLO) else
            unsigned(port_i) when (reg_din_sel = REGF_DIN_SEL_PORTI) else
            (others => '0');

end rtl;
