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

entity cpu8080_control is

  port (clk_i        : in  std_logic;
        reset_i      : in  std_logic;
        --
        int_i        : in  std_logic;
        nnn_i        : in  std_logic_vector(2 downto 0);
        --
        alu_op_o     : out alu_op_t;
        inta_o       : out std_logic;
        --
        regfile_din_sel_o : out std_logic_vector(1 downto 0);
        regfile_sel_a_o   : out reg_t;
        regfile_sel_b_o   : out reg_t;
        regfile_sel_rp_o  : out reg_pair_t;
        regfile_cmd_o     : out regfile_cmd_t;
        --
        ctrl_o : out unsigned(7 downto 0);
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
end cpu8080_control;

architecture rtl of cpu8080_control is

  component cpu8080_decode is
    port (instr_i      : in unsigned(7 downto 0);
          opcode_o     : out opcode_t;
          alu_op_o     : out alu_op_t;
          alu_only_o   : out std_logic;
          regfile_sel_a_o  : out reg_t;
          regfile_sel_b_o  : out reg_t;
          regfile_sel_rp_o : out reg_pair_t);
  end component;

  signal decode_opcode     : opcode_t;
  signal decode_alu_op     : alu_op_t;
  signal decode_alu_only   : std_logic;
  signal decode_reg_sel_a  : reg_t;
  signal decode_reg_sel_b  : reg_t;
  signal decode_reg_sel_rp : reg_pair_t;

  -- CPU state
  type cpu_state is (reset,fetch_1,fetch_2,
                     execute,reg2mem_1,reg2mem_2,
                     mem2accum_1,mem2accum_2,
                     pcmem2alu2accum_1,pcmem2alu2accum_2,
                     pcmem2alu2flags_1,pcmem2alu2flags_2,
                     hlmem2alu2accum_1,hlmem2alu2accum_2,
                     hlmem2alu2flags_1,hlmem2alu2flags_2,
                     pcmem2reg,
                     hlmem2reg,
                     mem2alu2mem_1,mem2alu2mem_2,mem2alu2mem_3,
                     pcmem2mem_1,pcmem2mem_2,pcmem2mem_3,
                     lda_1,lda_2,lda_3,lda_4,lda_5,
                     lhld_1,lhld_2,lhld_3,lhld_4,lhld_5,lhld_6,
                     lhld_7,lhld_8,
                     dad_1,dad_2,
                     stax_1,stax_2,
                     lxi_1,lxi_2,lxi_3,
                     jmp_1,jmp_2,jmp_3,jmp_4,jmp_5,
                     call_1,call_2,call_3,call_4,call_5,call_6,
                     call_7,call_8,call_9,
                     ret_1,ret_2,ret_3,ret_4,ret_5,ret_6,
                     pop_1,pop_2,pop_3,pop_4,pop_5,
                     pop_psw_1,pop_psw_2,pop_psw_3,pop_psw_4,pop_psw_5,
                     skip_jmp_1,skip_jmp_2,
                     sphl_1,
                     pchl_1,
                     push_1,push_2,push_3,push_4,
                     push_psw_1,push_psw_2,push_psw_3,push_psw_4,
                     shld_1,shld_2,shld_3,shld_4,shld_5,shld_6,shld_7,shld_8,
                     sta_1,sta_2,sta_3,sta_4,sta_5,
                     rst_1,rst_2,rst_3,rst_4,rst_5,rst_6,
                     xthl_1,xthl_2,xthl_3,xthl_4,xthl_5,xthl_6,xthl_7,xthl_8,
                     xthl_9,
                     inport_1,inport_2,outport_1,outport_2,
                     wait_1,hlt_1);

  signal curstate, nxtstate : cpu_state;

  signal reg_sel_rp_s    : reg_pair_t;
  signal reg_sel_a_s     : reg_t;
  signal reg_sel_b_s     : reg_t;
  signal alu_op_s        : alu_op_t;
  signal munit_wr_s      : std_logic;
  signal munit_rd_s      : std_logic;
  signal munit_ain_sel_s : std_logic;
  signal munit_din_sel_s : std_logic_vector(2 downto 0);

  -- Memory read/write registers
  signal reg_sel_rp_rg    : reg_pair_t;
  signal reg_sel_a_rg     : reg_t;
  signal reg_sel_b_rg     : reg_t;
  signal alu_op_rg        : alu_op_t;
  signal munit_access_rg  : std_logic;
  signal munit_wr_rg      : std_logic;
  signal munit_rd_rg      : std_logic;
  signal munit_ain_sel_rg : std_logic;
  signal munit_din_sel_rg : std_logic_vector(2 downto 0);

begin

  inst_decode: cpu8080_decode port map (
    instr_i          => ctrlreg_instr_i,
    opcode_o         => decode_opcode,
    alu_op_o         => decode_alu_op,
    alu_only_o       => decode_alu_only,
    regfile_sel_a_o  => decode_reg_sel_a,
    regfile_sel_b_o  => decode_reg_sel_b,
    regfile_sel_rp_o => decode_reg_sel_rp
    );

  regfile_sel_rp_o <= reg_sel_rp_rg when (munit_access_rg = '1') else reg_sel_rp_s;
  regfile_sel_a_o  <= reg_sel_a_rg  when (munit_access_rg = '1') else reg_sel_a_s;
  regfile_sel_b_o  <= reg_sel_b_rg  when (munit_access_rg = '1') else reg_sel_b_s;
  alu_op_o         <= alu_op_rg     when (munit_access_rg = '1') else alu_op_s;
  munit_wr_o       <= munit_wr_rg;
  munit_rd_o       <= munit_rd_rg;
  munit_ain_sel_o  <= munit_ain_sel_rg;
  munit_din_sel_o  <= munit_din_sel_rg;

  ----------------------------------------------------------
  mem_reg: process(clk_i,reset_i)
  begin
    --
    if reset_i = '1' then
      reg_sel_rp_rg    <= REG_HL;
      reg_sel_a_rg     <= REG_A;
      reg_sel_b_rg     <= REG_A;
      alu_op_rg        <= alu_op_nop;
      munit_access_rg  <= '0';
      munit_wr_rg      <= '0';
      munit_rd_rg      <= '0';
      munit_ain_sel_rg <= '0';
      munit_din_sel_rg <= (others => '0');

    elsif clk_i'event and clk_i = '1' then
      --
      if (munit_rdy_i = '1') then
        munit_access_rg  <= '0';
        munit_wr_rg      <= munit_wr_s;
        munit_rd_rg      <= munit_rd_s;
      end if;
      --
      if (munit_rd_s = '1' or munit_wr_s = '1') then
        munit_access_rg  <= '1';
        reg_sel_rp_rg    <= reg_sel_rp_s;
        reg_sel_a_rg     <= reg_sel_a_s;
        reg_sel_b_rg     <= reg_sel_b_s;
        alu_op_rg        <= alu_op_s;
        munit_wr_rg      <= munit_wr_s;
        munit_rd_rg      <= munit_rd_s;
        munit_ain_sel_rg <= munit_ain_sel_s;
        munit_din_sel_rg <= munit_din_sel_s;
      end if;
    end if;
  end process;

  ----------------------------------------------------------
  ctrl: process(clk_i,reset_i)
  begin
    if reset_i = '1' then
      curstate <= reset;
    elsif clk_i'event and clk_i = '1' then
      curstate <= nxtstate;
    end if;
  end process;

  ----------------------------------------------------------
  state: process(curstate,ctrlreg_alu_flags_i,
                 int_i,nnn_i,ctrlreg_inten_i,
                 decode_reg_sel_rp,port_rdy_i,munit_rdy_i,
                 decode_opcode,decode_alu_op,decode_alu_only,decode_reg_sel_a,decode_reg_sel_b)
  begin
    -- defaults
    ctrlreg_cmd_o <= ctrlreg_cmd_null_c;
    regfile_cmd_o <= regfile_cmd_null_c;
    alu_op_s      <= alu_op_nop;
    reg_sel_rp_s  <= REG_HL;
    reg_sel_a_s   <= REG_A;
    reg_sel_b_s   <= REG_A;
    inta_o        <= '0';
    --
    munit_wr_s      <= '0';
    munit_rd_s      <= '0';
    munit_ain_sel_s <= '0';
    munit_din_sel_s <= (others => '0');
    --
    regfile_din_sel_o   <= (others => '0');
    --
    port_rd_o  <= '0';
    port_wr_o  <= '0';
    --
    ctrl_o <= (others => '0');

    case curstate is
      ------------------------------------------------------
      -- Reset
      ------------------------------------------------------
      when reset =>
        nxtstate <= fetch_1;

      ------------------------------------------------------
      -- Fetch
      ------------------------------------------------------
      when fetch_1 =>
        -- ALU flags modified by an instruction are stored in a holding
        -- register: move the holding register to the flags register
        ctrlreg_cmd_o.alu_flags_store <= '1';

        -- Check if an interrupt is being asserted
        if ctrlreg_inten_i = '1' and int_i = '1' then
          -- acknowledge the interrupt
          inta_o <= '1';
          -- store NNN*8 in the "tmp" register
          reg_sel_a_s <= REG_TMP;
          regfile_cmd_o.wr <= '1';
          regfile_cmd_o.reg_a <= REG_TMP;
          regfile_din_sel_o <= REGF_DIN_SEL_CTRLO;
          ctrl_o <= ("00" & unsigned(nnn_i(2 downto 0)) & "000"); -- NNN*8
          ctrlreg_cmd_o.inten_set <= '1';
          ctrlreg_cmd_o.val <= '0';
          nxtstate <= rst_1;
        else
          -- fetch byte at (pc)
          munit_rd_s      <= '1';
          munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
          nxtstate <= fetch_2;
        end if;

      when fetch_2 =>
        if munit_rdy_i = '1' then
          ctrlreg_cmd_o.instr_wr <= '1'; -- Load instruction register
          regfile_cmd_o.incpc <= '1';        -- PC++
          nxtstate <= execute;
        else
          nxtstate <= fetch_2;
        end if;

      ------------------------------------------------------
      -- Intermediate states
      ------------------------------------------------------

      --
      -- PC memory => tmp => alu => register (accumulator)
      --
      when pcmem2alu2accum_1 =>
        if munit_rdy_i = '1' then
          -- (pc) -> tmp, pc++
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_TMP;
          regfile_cmd_o.incpc <= '1';
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= pcmem2alu2accum_2;
        else
          nxtstate <= pcmem2alu2accum_1;
        end if;

      when pcmem2alu2accum_2 =>
        alu_op_s <= decode_alu_op;
        reg_sel_a_s <= REG_A;
        reg_sel_b_s <= REG_TMP;
        regfile_cmd_o.wr <= '1';
        regfile_cmd_o.reg_a <= REG_A;
        regfile_din_sel_o <= REGF_DIN_SEL_ALUO;
        ctrlreg_cmd_o.alu_flags_wr <= '1';
        nxtstate <= fetch_1;

      --
      -- PC memory => tmp => alu => flags
      --
      when pcmem2alu2flags_1 =>
        if munit_rdy_i = '1' then
          -- (pc) -> tmp, pc++
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_TMP;
          regfile_cmd_o.incpc <= '1';
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= pcmem2alu2flags_2;
        else
          nxtstate <= pcmem2alu2flags_1;
        end if;

      when pcmem2alu2flags_2 =>
        alu_op_s <= decode_alu_op;
        reg_sel_a_s <= REG_A;
        reg_sel_b_s <= REG_TMP;
        ctrlreg_cmd_o.alu_flags_wr <= '1';
        nxtstate <= fetch_1;

      --
      -- HL memory => tmp => alu => register (accumulator)
      --
      when hlmem2alu2accum_1 =>
        if munit_rdy_i = '1' then
          -- tmp = mem(hl)
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_TMP;
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= hlmem2alu2accum_2;
        else
          nxtstate <= hlmem2alu2accum_1;
        end if;

      when hlmem2alu2accum_2 =>
        alu_op_s <= decode_alu_op;
        reg_sel_a_s <= REG_A;
        reg_sel_b_s <= REG_TMP;
        regfile_cmd_o.wr <= '1';
        regfile_cmd_o.reg_a <= REG_A;
        regfile_din_sel_o <= REGF_DIN_SEL_ALUO;
        ctrlreg_cmd_o.alu_flags_wr <= '1';
        nxtstate <= fetch_1;

      --
      -- HL memory => tmp => alu => flags
      --
      when hlmem2alu2flags_1 =>
        if munit_rdy_i = '1' then
          -- (hl) -> tmp
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_TMP;
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= hlmem2alu2flags_2;
        else
          nxtstate <= hlmem2alu2flags_1;
        end if;

      when hlmem2alu2flags_2 =>
        alu_op_s <= decode_alu_op;
        reg_sel_a_s <= REG_A;
        reg_sel_b_s <= REG_TMP;
        ctrlreg_cmd_o.alu_flags_wr <= '1';
        nxtstate <= fetch_1;

      --
      -- HL memory => register
      --
      when hlmem2reg =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= decode_reg_sel_a;
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= fetch_1;
        else
          nxtstate <= hlmem2reg;
        end if;

      --
      -- PC memory => register
      --
      when pcmem2reg =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= decode_reg_sel_a;
          regfile_cmd_o.incpc <= '1';
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= fetch_1;
        else
          nxtstate <= pcmem2reg;
        end if;

      --
      -- PC memory => memory
      --
      when pcmem2mem_1 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_TMP;
          regfile_cmd_o.incpc <= '1';
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= pcmem2mem_2;
        else
          nxtstate <= pcmem2mem_1;
        end if;

      when pcmem2mem_2 =>
        reg_sel_rp_s    <= REG_HL;
        reg_sel_a_s     <= REG_TMP;
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_REGA;
        nxtstate <= pcmem2mem_3;

      when pcmem2mem_3 =>
        if munit_rdy_i = '1' then
          nxtstate <= fetch_1;
        else
          nxtstate <= pcmem2mem_3;
        end if;
      --
      -- Memory => reg
      --
      when mem2accum_1 =>
        reg_sel_rp_s    <= decode_reg_sel_rp;
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        nxtstate <= mem2accum_2;

      when mem2accum_2 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr <= '1';
          regfile_cmd_o.reg_a <= REG_A;
          regfile_din_sel_o <= REGF_DIN_SEL_MDATA;
          nxtstate <= fetch_1;
        else
          nxtstate <= mem2accum_2;
        end if;

      --
      -- Reg => Memory
      --
      when reg2mem_1 =>
        reg_sel_rp_s    <= decode_reg_sel_rp;
        reg_sel_a_s     <= decode_reg_sel_b;
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_REGA;
        nxtstate <= reg2mem_2;

      when reg2mem_2 =>
        if munit_rdy_i = '1' then
          nxtstate <= fetch_1;
        else
          nxtstate <= reg2mem_2;
        end if;

      --
      -- DCR M/INR M: Memory => tmp => alu => Memory
      --
      when mem2alu2mem_1 =>
        if munit_rdy_i = '1' then
          -- (hl) -> tmp
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_TMP;
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= mem2alu2mem_2;
        else
          nxtstate <= mem2alu2mem_1;
        end if;

      when mem2alu2mem_2 =>
        alu_op_s        <= decode_alu_op;
        reg_sel_a_s     <= REG_TMP;
        reg_sel_rp_s    <= REG_HL;
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_ALUO;
        ctrlreg_cmd_o.alu_flags_wr <= '1';
        nxtstate <= mem2alu2mem_3;

      when mem2alu2mem_3 =>
        if munit_rdy_i = '1' then
          nxtstate <= fetch_1;
        else
          nxtstate <= mem2alu2mem_3;
        end if;

      --
      -- shld
      --
      when shld_1 =>
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
        nxtstate <= shld_2;

      when shld_2 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_Z;
          regfile_cmd_o.incpc <= '1'; -- pc++
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= shld_3;
        else
          nxtstate <= shld_2;
        end if;

      when shld_3 =>
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
        nxtstate <= shld_4;

      when shld_4 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_W;
          regfile_cmd_o.incpc <= '1'; -- pc++
          regfile_din_sel_o <= REGF_DIN_SEL_MDATA;
          nxtstate <= shld_5;
        else
          nxtstate <= shld_4;
        end if;

      when shld_5 =>
        reg_sel_rp_s    <= REG_WZ;
        reg_sel_a_s     <= REG_L;
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_REGA;
        nxtstate <= shld_6;

      when shld_6 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.reg_a <= REG_W;
          regfile_cmd_o.reg_b <= REG_Z;
          regfile_cmd_o.incrp <= '1'; -- wz++
          nxtstate <= shld_7;
        else
          nxtstate <= shld_6;
        end if;

      when shld_7 =>
        reg_sel_rp_s    <= REG_WZ;
        reg_sel_a_s     <= REG_H;
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_REGA;
        nxtstate <= shld_8;

      when shld_8 =>
        if munit_rdy_i = '1' then
          nxtstate <= fetch_1;
        else
          nxtstate <= shld_8;
        end if;

      --
      -- sta
      --
      when sta_1 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_Z;
          regfile_cmd_o.incpc <= '1'; -- pc++
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= sta_2;
        else
          nxtstate <= sta_1;
        end if;

      when sta_2 =>
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
        nxtstate <= sta_3;

      when sta_3 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_W;
          regfile_cmd_o.incpc <= '1'; -- pc++
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= sta_4;
        else
          nxtstate <= sta_3;
        end if;

      when sta_4 =>
        reg_sel_rp_s    <= REG_WZ;
        reg_sel_a_s     <= REG_A;
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_REGA;
        nxtstate <= sta_5;

      when sta_5 =>
        if munit_rdy_i = '1' then
          nxtstate <= fetch_1;
        else
          nxtstate <= sta_5;
        end if;

      --
      -- Memory => z, Memory => w, (wz) => accumulator
      --
      when lda_1 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.incpc <= '1';
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_Z;
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= lda_2;
        else
          nxtstate <= lda_1;
        end if;

      when lda_2 =>
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
        nxtstate <= lda_3;

      when lda_3 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.incpc <= '1';
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_W;
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= lda_4;
        else
          nxtstate <= lda_3;
        end if;

      when lda_4 =>
        reg_sel_rp_s    <= REG_WZ;
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        nxtstate <= lda_5;

      when lda_5 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_A;
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= fetch_1;
        else
          nxtstate <= lda_5;
        end if;

      --
      -- LHLD
      --
      when lhld_1 => -- (pc) => z, pc++
        if munit_rdy_i = '1' then
          regfile_cmd_o.incpc <= '1';
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_Z;
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= lhld_2;
        else
          nxtstate <= lhld_1;
        end if;

      when lhld_2 => -- mem[pc]
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
        nxtstate <= lhld_3;

      when lhld_3 => -- (pc) => z, pc++
        if munit_rdy_i = '1' then
          regfile_cmd_o.incpc <= '1';
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_W;
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= lhld_4;
        else
          nxtstate <= lhld_3;
        end if;

      when lhld_4 => -- mem[wz]
        reg_sel_rp_s    <= REG_WZ;
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        nxtstate <= lhld_5;

      when lhld_5 => -- (wz) => l
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_L;
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= lhld_6;
        else
          nxtstate <= lhld_5;
        end if;

      when lhld_6 => -- wz++
        regfile_cmd_o.reg_a <= REG_W;
        regfile_cmd_o.reg_b <= REG_Z;
        regfile_cmd_o.incrp <= '1'; -- wz++
        nxtstate <= lhld_7;

      when lhld_7 => -- mem[wz]
        reg_sel_rp_s    <= REG_WZ;
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        nxtstate <= lhld_8;

      when lhld_8 => -- (wz) => h
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_H;
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= fetch_1;
        else
          nxtstate <= lhld_8;
        end if;

      --
      -- DAD : HL <- HL + {SP,BC,DE,HL}
      --
      when dad_1 =>
        ctrlreg_cmd_o.alu_flags_store <= '1';
        nxtstate <= dad_2;

      when dad_2 =>
        -- h <- ALU, CY <- ALU.CY
        alu_op_s <= alu_op_adc;
        reg_sel_a_s <= REG_H;
        reg_sel_b_s <= decode_reg_sel_a;
        ctrlreg_cmd_o.alu_carry_wr <= '1';
        regfile_cmd_o.wr <= '1';
        regfile_cmd_o.reg_a <= REG_H;
        regfile_din_sel_o <= REGF_DIN_SEL_ALUO;
        nxtstate <= fetch_1;

      --
      -- Memory => reg, Memory => reg
      --
      when lxi_1 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= decode_reg_sel_b;
          regfile_cmd_o.incpc <= '1';
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= lxi_2;
        else
          nxtstate <= lxi_1;
        end if;

      when lxi_2 =>
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
        nxtstate <= lxi_3;

      when lxi_3 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= decode_reg_sel_a;
          regfile_cmd_o.incpc <= '1';
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= fetch_1;
        else
          nxtstate <= lxi_3;
        end if;

      ------------------------------------------------------
      -- Skip next two bytes after PC (conditional jmp/call)
      ------------------------------------------------------
      when skip_jmp_1 =>
        regfile_cmd_o.incpc <= '1';
        nxtstate <= skip_jmp_2;

      when skip_jmp_2 =>
        regfile_cmd_o.incpc <= '1';
        nxtstate <= fetch_1;

      ------------------------------------------------------
      -- First store the destination address in WZ
      ------------------------------------------------------
      when jmp_1 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_Z; -- Z <= (PC)
          regfile_cmd_o.incpc <= '1';
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= jmp_2;
        else
          nxtstate <= jmp_1;
        end if;

      when jmp_2 =>
        -- w <= (pc)
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
        nxtstate <= jmp_3;

      when jmp_3 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.incpc <= '1';
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_W; -- W <= (PC)
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= jmp_4;
        else
          nxtstate <= jmp_3;
        end if;

      ------------------------------------------------------
      -- Finally set the PC = WZ
      ------------------------------------------------------
      when jmp_4 =>
        regfile_cmd_o.reg_a <= REG_PCL;
        regfile_cmd_o.reg_b <= REG_Z;
        regfile_cmd_o.mov <= '1';
        nxtstate <= jmp_5;

      when jmp_5 =>
        regfile_cmd_o.reg_a <= REG_PCH;
        regfile_cmd_o.reg_b <= REG_W;
        regfile_cmd_o.mov <= '1';
        nxtstate <= fetch_1;

      --
      -- PC <- HL
      --
      when pchl_1 =>
        regfile_cmd_o.reg_a <= REG_PCL;
        regfile_cmd_o.reg_b <= REG_L;
        regfile_cmd_o.mov <= '1';
        nxtstate <= fetch_1;

      --
      -- Call
      --
      -- (sp - 1) <= pch
      -- (sp - 2) <= pcl
      -- sp = sp - 2
      -- pcl = (pc)
      -- pch = (pc+1)
      --
      --

      ------------------------------------------------------
      -- First store the destination address in WZ and
      -- increment the PC, PC = PC + 2
      ------------------------------------------------------
      when call_1 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.incpc <= '1';
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_Z; -- Z <= (PC)
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= call_2;
        else
          nxtstate <= call_1;
        end if;

      when call_2 =>
        -- w <= (pc)
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
        nxtstate <= call_3;

      when call_3 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.incpc <= '1';
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_W; -- W <= (PC)
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= call_4;
        else
          nxtstate <= call_3;
        end if;

      ------------------------------------------------------
      -- Next store the next instruction address at the SP
      -- and decrement the SP, SP = SP - 2
      ------------------------------------------------------
      when call_4 =>
        -- sp = sp - 1
        regfile_cmd_o.decrp <= '1';
        regfile_cmd_o.reg_a <= REG_SPH;
        regfile_cmd_o.reg_b <= REG_SPL;
        nxtstate <= call_5;

      when call_5 =>
        -- (sp) <= pch
        reg_sel_rp_s    <= REG_SP;
        reg_sel_a_s     <= REG_PCH;
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_REGA;
        nxtstate <= call_6;

      when call_6 =>
        if munit_rdy_i = '1' then
          -- sp = sp - 1
          regfile_cmd_o.decrp <= '1';
          regfile_cmd_o.reg_a <= REG_SPH;
          regfile_cmd_o.reg_b <= REG_SPL;
          regfile_cmd_o.decrp <= '1';
          nxtstate <= call_7;
        else
          nxtstate <= call_6;
        end if;

      when call_7 =>
        -- (sp) <= pcl
        reg_sel_rp_s    <= REG_SP;
        reg_sel_a_s     <= REG_PCL;
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_REGA;
        nxtstate <= call_8;

      ------------------------------------------------------
      -- Finally set the PC = WZ
      ------------------------------------------------------
      when call_8 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.reg_a <= REG_PCL;
          regfile_cmd_o.reg_b <= REG_Z;
          regfile_cmd_o.mov <= '1';
          nxtstate <= call_9;
        else
          nxtstate <= call_8;
        end if;

      when call_9 =>
        regfile_cmd_o.reg_a <= REG_PCH;
        regfile_cmd_o.reg_b <= REG_W;
        regfile_cmd_o.mov <= '1';
        nxtstate <= fetch_1;

      --
      -- ret
      --
      when ret_1 =>
        reg_sel_rp_s    <= REG_SP;
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        nxtstate <= ret_2;

      when ret_2 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_PCL; -- PCL <= (SP)
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= ret_3;
        else
          nxtstate <= ret_2;
        end if;

      when ret_3 =>
        regfile_cmd_o.reg_a <= REG_SPH;
        regfile_cmd_o.reg_b <= REG_SPL;
        regfile_cmd_o.incrp <= '1'; -- SP = SP + 1
        nxtstate <= ret_4;

      when ret_4 =>
        reg_sel_rp_s    <= REG_SP;
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        nxtstate <= ret_5;

      when ret_5 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_PCH; -- PCH <= (SP)
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= ret_6;
        else
          nxtstate <= ret_5;
        end if;

      when ret_6 =>
        regfile_cmd_o.reg_a <= REG_SPH;
        regfile_cmd_o.reg_b <= REG_SPL;
        regfile_cmd_o.incrp <= '1'; -- SP = SP + 1
        nxtstate <= fetch_1;


      ------------------------------------------------------
      -- RST
      --
      -- Store the next instruction address at the SP
      -- and decrement the SP, SP = SP - 2
      ------------------------------------------------------
      when rst_1 =>
        -- sp = sp - 1
        regfile_cmd_o.decrp <= '1';
        regfile_cmd_o.reg_a <= REG_SPH;
        regfile_cmd_o.reg_b <= REG_SPL;
        nxtstate <= rst_2;

      when rst_2 =>
        -- (sp) <= pch
        reg_sel_rp_s    <= REG_SP;
        reg_sel_a_s     <= REG_PCH;
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_REGA;
        nxtstate <= rst_3;

      when rst_3 =>
        if munit_rdy_i = '1' then
          -- sp = sp - 1
          regfile_cmd_o.decrp <= '1';
          regfile_cmd_o.reg_a <= REG_SPH;
          regfile_cmd_o.reg_b <= REG_SPL;
          regfile_cmd_o.decrp <= '1';
          nxtstate <= rst_4;
        else
          nxtstate <= rst_3;
        end if;

      when rst_4 =>
        -- (sp) <= pcl
        reg_sel_rp_s    <= REG_SP;
        reg_sel_a_s     <= REG_PCL;
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_REGA;
        nxtstate <= rst_5;

      when rst_5 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.mov <= '1';
          regfile_cmd_o.reg_a <= REG_PCL;
          regfile_cmd_o.reg_b <= REG_TMP;
          nxtstate <= rst_6;
        else
          nxtstate <= rst_5;
        end if;

      when rst_6 =>
        regfile_cmd_o.wr <= '1';
        regfile_cmd_o.reg_a <= REG_PCH;
        regfile_din_sel_o <= REGF_DIN_SEL_CTRLO;
        ctrl_o <= (others => '0');
        nxtstate <= fetch_1;

      --
      -- SP <= HL
      --
      when sphl_1 =>
        regfile_cmd_o.reg_a <= REG_SPH;
        regfile_cmd_o.reg_b <= REG_H;
        regfile_cmd_o.mov <= '1';
        nxtstate <= fetch_1;

      --
      -- pop
      --
      when pop_1 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= decode_reg_sel_b; -- RPL <= (SP)
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= pop_2;
        else
          nxtstate <= pop_1;
        end if;

      when pop_2 =>
        regfile_cmd_o.reg_a <= REG_SPH;
        regfile_cmd_o.reg_b <= REG_SPL;
        regfile_cmd_o.incrp <= '1'; -- SP = SP + 1
        nxtstate <= pop_3;

      when pop_3 =>
        reg_sel_rp_s    <= REG_SP;
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        nxtstate <= pop_4;

      when pop_4 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= decode_reg_sel_a; -- RPH <= (SP)
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= pop_5;
        else
          nxtstate <= pop_4;
        end if;

      when pop_5 =>
        regfile_cmd_o.reg_a <= REG_SPH;
        regfile_cmd_o.reg_b <= REG_SPL;
        regfile_cmd_o.incrp <= '1'; -- SP = SP + 1
        nxtstate <= fetch_1;

      --
      -- pop_psw
      --
      when pop_psw_1 =>
        if munit_rdy_i = '1' then
          ctrlreg_cmd_o.alu_psw_wr <= '1';
          nxtstate <= pop_psw_2;
        else
          nxtstate <= pop_psw_1;
        end if;

      when pop_psw_2 =>
        regfile_cmd_o.reg_a <= REG_SPH;
        regfile_cmd_o.reg_b <= REG_SPL;
        regfile_cmd_o.incrp <= '1'; -- SP = SP + 1
        nxtstate <= pop_psw_3;

      when pop_psw_3 =>
        reg_sel_rp_s    <= REG_SP;
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        nxtstate <= pop_psw_4;

      when pop_psw_4 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_A; -- a <= (SP)
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= pop_psw_5;
        else
          nxtstate <= pop_psw_4;
        end if;

      when pop_psw_5 =>
        regfile_cmd_o.reg_a <= REG_SPH;
        regfile_cmd_o.reg_b <= REG_SPL;
        regfile_cmd_o.incrp <= '1'; -- SP = SP + 1
        nxtstate <= fetch_1;

      --
      -- push
      --
      when push_1 =>
        -- (sp) <= rph
        reg_sel_rp_s    <= REG_SP;
        reg_sel_a_s     <= decode_reg_sel_a;
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_REGA;
        nxtstate <= push_2;

      when push_2 =>
        if munit_rdy_i = '1' then
          -- sp = sp - 1
          regfile_cmd_o.decrp <= '1';
          regfile_cmd_o.reg_a <= REG_SPH;
          regfile_cmd_o.reg_b <= REG_SPL;
          regfile_cmd_o.decrp <= '1';
          nxtstate <= push_3;
        else
          nxtstate <= push_2;
        end if;

      when push_3 =>
        -- (sp) <= pcl
        reg_sel_rp_s    <= REG_SP;
        reg_sel_b_s     <= decode_reg_sel_b;
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_REGB;
        nxtstate <= push_4;

      when push_4 =>
        if munit_rdy_i = '1' then
          nxtstate <= fetch_1;
        else
          nxtstate <= push_4;
        end if;

      --
      -- push_psw
      --
      when push_psw_1 =>
        -- (sp) <= a
        reg_sel_rp_s    <= REG_SP;
        reg_sel_a_s     <= REG_A;
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_REGA;
        nxtstate <= push_psw_2;

      when push_psw_2 =>
        if munit_rdy_i = '1' then
          -- sp = sp - 1
          regfile_cmd_o.decrp <= '1';
          regfile_cmd_o.reg_a <= REG_SPH;
          regfile_cmd_o.reg_b <= REG_SPL;
          nxtstate <= push_psw_3;
        else
          nxtstate <= push_psw_2;
        end if;

      when push_psw_3 =>
        -- (sp) <= (cy,1,p,0,ac,0,z,s)
        reg_sel_rp_s    <= REG_SP;
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_PSW;
        nxtstate <= push_psw_4;

      when push_psw_4 =>
        if munit_rdy_i = '1' then
          nxtstate <= fetch_1;
        else
          nxtstate <= push_psw_4;
        end if;

      --
      -- stax
      --
      when stax_1 =>
        reg_sel_rp_s    <= decode_reg_sel_rp;
        reg_sel_a_s     <= REG_A;
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_REGA;
        nxtstate <= stax_2;

      when stax_2 =>
        if munit_rdy_i = '1' then
          nxtstate <= fetch_1;
        else
          nxtstate <= stax_2;
        end if;

      --
      -- xthl (l) <-> (sp), (h) <-> (sp+1)
      --
      when xthl_1 =>
        -- w <= sph
        regfile_cmd_o.reg_a <= REG_W;
        regfile_cmd_o.reg_b <= REG_SPH;
        regfile_cmd_o.mov <= '1';
        nxtstate <= xthl_2;

      when xthl_2 =>
        -- tmp <= l
        regfile_cmd_o.reg_a <= REG_TMP;
        regfile_cmd_o.reg_b <= REG_L;
        regfile_cmd_o.mov <= '1';
        -- Read from WZ (SP)
        reg_sel_rp_s    <= REG_WZ;
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        nxtstate <= xthl_3;

      when xthl_3 =>
        if munit_rdy_i = '1' then
          -- L <= (SP)
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_L;
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= xthl_4;
        else
          nxtstate <= xthl_3;
        end if;

      when xthl_4 =>
        -- (SP) <= L
        reg_sel_rp_s    <= REG_SP;
        reg_sel_a_s     <= REG_TMP; -- select tmp (L)
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_REGA;
        nxtstate <= xthl_5;

      when xthl_5 =>
        if munit_rdy_i = '1' then
          -- WZ++ (SP = SP + 1)
          regfile_cmd_o.reg_a <= REG_W;
          regfile_cmd_o.reg_b <= REG_Z;
          regfile_cmd_o.incrp <= '1';
          nxtstate <= xthl_6;
        else
          nxtstate <= xthl_5;
        end if;

      when xthl_6 =>
        -- tmp <= h
        regfile_cmd_o.reg_a <= REG_TMP;
        regfile_cmd_o.reg_b <= REG_H;
        regfile_cmd_o.mov <= '1';
        -- Read from WZ++ (SP+1)
        reg_sel_rp_s    <= REG_WZ;
        munit_rd_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        nxtstate <= xthl_7;

      when xthl_7 =>
        if munit_rdy_i = '1' then
          -- H <= (SP+1)
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_H;
          regfile_din_sel_o   <= REGF_DIN_SEL_MDATA;
          nxtstate <= xthl_8;
        else
          nxtstate <= xthl_7;
        end if;

      when xthl_8 =>
        -- (SP+1) <= H
        reg_sel_rp_s    <= REG_WZ;
        reg_sel_a_s     <= REG_TMP; -- select tmp (H)
        munit_wr_s      <= '1';
        munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
        munit_din_sel_s <= MUNIT_DIN_SEL_REGA;
        nxtstate <= xthl_9;

      when xthl_9 =>
        if munit_rdy_i = '1' then
          nxtstate <= fetch_1;
        else
          nxtstate <= xthl_9;
        end if;

      --
      -- IN port
      --
      when inport_1 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.incpc <= '1'; -- PC++
          port_rd_o <= '1';
          nxtstate <= inport_2;
        else
          nxtstate <= inport_1;
        end if;

      when inport_2 =>
        if port_rdy_i = '1' then
          regfile_cmd_o.wr    <= '1';
          regfile_cmd_o.reg_a <= REG_A;
          regfile_din_sel_o   <= REGF_DIN_SEL_PORTI;
          nxtstate <= fetch_1;
        else
          nxtstate <= inport_2;
        end if;

      --
      -- OUT port
      --
      when outport_1 =>
        if munit_rdy_i = '1' then
          regfile_cmd_o.incpc <= '1'; -- PC++
          reg_sel_a_s <= REG_A;
          port_wr_o   <= '1';
          nxtstate <= outport_2;
        else
          nxtstate <= outport_1;
        end if;

      when outport_2 =>
        if port_rdy_i = '1' then
          nxtstate <= fetch_1;
        else
          nxtstate <= outport_2;
        end if;

      --
      -- Delay
      when wait_1 =>
        nxtstate <= fetch_1;

      --
      -- HLT
      when hlt_1 =>
        nxtstate <= hlt_1;

      --
      ------------------------------------------------------
      -- Execute
      ------------------------------------------------------
      when execute =>

        if decode_alu_only = '1' then
          -- alu: rlc,rrc,ral,daa,cma,add,addc,sub,sbb,ana,xra,ora
          --    : *** Z,S,P,CY,AC ***
          alu_op_s <= decode_alu_op;
          reg_sel_a_s <= decode_reg_sel_a;
          reg_sel_b_s <= decode_reg_sel_b;
          regfile_cmd_o.wr <= '1';
          regfile_cmd_o.reg_a <= REG_A;
          regfile_din_sel_o <= REGF_DIN_SEL_ALUO;
          ctrlreg_cmd_o.alu_flags_wr <= '1';
          nxtstate <= fetch_1;

        else
          if decode_opcode = aci then
            -- aci : A <- A + (pc) + Carry
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= pcmem2alu2accum_1;

          -- adc: alu

          elsif decode_opcode = adcm then
            -- adc m : A <- A + (hl) + Carry
            reg_sel_rp_s <= REG_HL;
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
            nxtstate <= hlmem2alu2accum_1;

          -- add: alu

          elsif decode_opcode = addm then
            -- add m : A <- A + (hl)
            reg_sel_rp_s <= REG_HL;
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
            nxtstate <= hlmem2alu2accum_1;

          elsif decode_opcode = adi then
            -- adi : A <- A + (pc)
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= pcmem2alu2accum_1;

          -- ana: alu

          elsif decode_opcode = anam then
            reg_sel_rp_s <= REG_HL;
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
            nxtstate <= hlmem2alu2accum_1;

          elsif decode_opcode = ani then
            -- ani : A <- A and (pc)
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= pcmem2alu2accum_1;

          -- call : Call unconditional
          elsif decode_opcode = call then
            -- z <= (pc)
            reg_sel_rp_s    <= REG_PC;
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= call_1;

          -- cc : Call on Carry
          elsif decode_opcode = cc then
            if ctrlreg_alu_flags_i.carry = '1' then
              -- z <= (pc)
              reg_sel_rp_s    <= REG_PC;
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= call_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          -- cm : Call on Minus
          elsif decode_opcode = cm then
            if ctrlreg_alu_flags_i.sign = '1' then
              -- z <= (pc)
              reg_sel_rp_s    <= REG_PC;
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= call_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          -- cma: alu

          -- cmc
          elsif decode_opcode = cmc then
            if ctrlreg_alu_flags_i.carry = '0' then
              ctrlreg_cmd_o.alu_carry_set <= '1';
              ctrlreg_cmd_o.val <= '1';
            else
              ctrlreg_cmd_o.alu_carry_set <= '1';
              ctrlreg_cmd_o.val <= '0';
            end if;
            nxtstate <= fetch_1;

          elsif decode_opcode = cmp then
            -- cmp : A - R -> flags
            alu_op_s <= alu_op_cmp;
            reg_sel_a_s <= decode_reg_sel_a;
            reg_sel_b_s <= decode_reg_sel_b;
            ctrlreg_cmd_o.alu_flags_wr <= '1';
            nxtstate <= fetch_1;


          elsif decode_opcode = cmpm then
            -- cmpm : A - (hl) -> flags
            reg_sel_rp_s    <= REG_HL;
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
            nxtstate <= hlmem2alu2flags_1;

          -- cnc : Call on no Carry
          elsif decode_opcode = cnc then
            if ctrlreg_alu_flags_i.carry = '0' then
              -- z <= (pc)
              reg_sel_rp_s    <= REG_PC;
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= call_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          -- cnz : Call on no Zero
          elsif decode_opcode = cnz then
            if ctrlreg_alu_flags_i.zero = '0' then
              -- z <= (pc)
              reg_sel_rp_s    <= REG_PC;
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= call_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          -- cp : Call on Positive
          elsif decode_opcode = cp then
            if ctrlreg_alu_flags_i.sign = '0' then
              -- z <= (pc)
              reg_sel_rp_s    <= REG_PC;
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= call_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          -- cpe : Call on Parity Even
          elsif decode_opcode = cpe then
            if ctrlreg_alu_flags_i.parity = '1' then
              -- z <= (pc)
              reg_sel_rp_s    <= REG_PC;
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= call_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          -- cpi : Compare Immediate with A
          elsif decode_opcode = cpi then
            -- cpi : A - byte -> flags
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= pcmem2alu2flags_1;

          -- cpo : Call on Parity Odd
          elsif decode_opcode = cpo then
            if ctrlreg_alu_flags_i.parity = '0' then
              -- z <= (pc)
              reg_sel_rp_s    <= REG_PC;
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= call_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          -- cz : Call on Zero
          elsif decode_opcode = cz then
            if ctrlreg_alu_flags_i.zero = '1' then
              -- z <= (pc)
              reg_sel_rp_s    <= REG_PC;
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= call_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          -- daa: alu

          elsif decode_opcode = dad then
            -- dad : *** CY *** => Z,S,P,AC not updated ***
            -- l <- ALU, CY <- ALU.CY
            alu_op_s <= alu_op_add;
            reg_sel_a_s <= REG_L;
            reg_sel_b_s <= decode_reg_sel_b;

            ctrlreg_cmd_o.alu_carry_wr <= '1';

            regfile_cmd_o.wr <= '1';
            regfile_cmd_o.reg_a <= REG_L;
            regfile_din_sel_o <= REGF_DIN_SEL_ALUO;
            nxtstate <= dad_1;

          elsif decode_opcode = dcr then
            -- dcr : alu
            alu_op_s <= alu_op_dcr;
            reg_sel_a_s <= decode_reg_sel_a;
            regfile_cmd_o.wr <= '1';
            regfile_cmd_o.reg_a <= decode_reg_sel_a;
            regfile_din_sel_o <= REGF_DIN_SEL_ALUO;
            ctrlreg_cmd_o.alu_flags_wr <= '1';
            nxtstate <= fetch_1;

          elsif decode_opcode = dcrm then
            -- dcrm : *** Z,S,P,AC *** => CY not updated ***
            reg_sel_rp_s    <= REG_HL;
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
            nxtstate <= mem2alu2mem_1;

          elsif decode_opcode = dcx then
            -- dcx
            regfile_cmd_o.decrp <= '1';
            regfile_cmd_o.reg_a <= decode_reg_sel_a;
            regfile_cmd_o.reg_b <= decode_reg_sel_b;
            nxtstate <= fetch_1;

          elsif decode_opcode = di then
            -- di : Disable Interrupts
            ctrlreg_cmd_o.inten_set <= '1';
            ctrlreg_cmd_o.val <= '0';
            nxtstate <= wait_1;

          elsif decode_opcode = ei then
            -- ei : Enable Interrupts
            ctrlreg_cmd_o.inten_set <= '1';
            ctrlreg_cmd_o.val <= '1';
            nxtstate <= wait_1;

          elsif decode_opcode = hlt then
            -- hlt
            nxtstate <= hlt_1;

          elsif decode_opcode = inr then
            -- inr : *** Z,S,P,AC *** => CY not updated ***
            alu_op_s <= alu_op_inr;
            reg_sel_a_s <= decode_reg_sel_a;
            regfile_cmd_o.wr <= '1';
            regfile_cmd_o.reg_a <= decode_reg_sel_a;
            regfile_din_sel_o <= REGF_DIN_SEL_ALUO;
            ctrlreg_cmd_o.alu_flags_wr <= '1';
            nxtstate <= fetch_1;

          elsif decode_opcode = inrm then
            -- inrm : *** Z,S,P,AC *** => CY not updated ***
            reg_sel_rp_s    <= REG_HL;
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
            nxtstate <= mem2alu2mem_1;

          elsif decode_opcode = inx then
            -- inx
            regfile_cmd_o.incrp <= '1';
            regfile_cmd_o.reg_a <= decode_reg_sel_a;
            regfile_cmd_o.reg_b <= decode_reg_sel_b;
            nxtstate <= wait_1;

          -- jc : Jump on Carry
          elsif decode_opcode = jc then
            if ctrlreg_alu_flags_i.carry = '1' then
              -- z <= (pc)
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= jmp_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          -- jm : Jump on Minus
          elsif decode_opcode = jm then
            if ctrlreg_alu_flags_i.sign = '1' then
              -- z <= (pc)
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= jmp_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          -- jmp : Jump Unconditional
          elsif decode_opcode = jmp then
            -- z <= (pc)
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= jmp_1;

          -- jnc : Jump on not Carry
          elsif decode_opcode = jnc then
            if ctrlreg_alu_flags_i.carry = '0' then
              -- z <= (pc)
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= jmp_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          -- jnz : Jump on not Zero
          elsif decode_opcode = jnz then
            if ctrlreg_alu_flags_i.zero = '0' then
              -- z <= (pc)
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= jmp_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          -- jp : Jump on Positive
          elsif decode_opcode = jp then
            if ctrlreg_alu_flags_i.sign = '0' then
              -- z <= (pc)
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= jmp_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          -- jpe : Jump on Parity Even
          elsif decode_opcode = jpe then
            if ctrlreg_alu_flags_i.parity = '1' then
              -- z <= (pc)
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= jmp_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          -- jpo : Jump on Parity Odd
          elsif decode_opcode = jpo then
            if ctrlreg_alu_flags_i.parity = '0' then
              -- z <= (pc)
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= jmp_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          -- jz : Jump on Zero
          elsif decode_opcode = jz then
            if ctrlreg_alu_flags_i.zero = '1' then
              -- z <= (pc)
              munit_rd_s      <= '1';
              munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
              nxtstate <= jmp_1;
            else
              nxtstate <= skip_jmp_1;
            end if;

          elsif decode_opcode = lda then
            -- lda
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= lda_1;

          elsif decode_opcode = ldax then
            -- ldax
            nxtstate <= mem2accum_1;

          elsif decode_opcode = lhld then
            -- lhld
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= lhld_1;

          -- lxi
          elsif decode_opcode = lxi then
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= lxi_1;

          elsif decode_opcode = movr2r then
            -- movr2r
            regfile_cmd_o.mov   <= '1';
            regfile_cmd_o.reg_a <= decode_reg_sel_a;
            regfile_cmd_o.reg_b <= decode_reg_sel_b;
            nxtstate <= fetch_1;

          -- movr2m
          elsif decode_opcode = movr2m then
            nxtstate <= reg2mem_1;

          -- movm2r
          elsif decode_opcode = movm2r then
            reg_sel_rp_s <= REG_HL;
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
            nxtstate <= hlmem2reg;

          -- mvi2r
          elsif decode_opcode = mvi2r then
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= pcmem2reg;

          -- mvi2m
          elsif decode_opcode = mvi2m then
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= pcmem2mem_1;

          -- nop
          elsif decode_opcode = nop then
            nxtstate <= fetch_1;

          -- ora: alu

          -- oram
          elsif decode_opcode = oram then
            reg_sel_rp_s <= REG_HL;
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
            nxtstate <= hlmem2alu2accum_1;

          -- ori
          elsif decode_opcode = ori then
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= pcmem2alu2accum_1;

          -- pchl : PC <- HL
          elsif decode_opcode = pchl then
            regfile_cmd_o.reg_a <= REG_PCH;
            regfile_cmd_o.reg_b <= REG_H;
            regfile_cmd_o.mov <= '1';
            nxtstate <= pchl_1;

          -- pop : rpl <- (sp), rph <- (sp+1)
          elsif decode_opcode = pop then
            reg_sel_rp_s    <= REG_SP;
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
            nxtstate <= pop_1;

          -- poppsw
          elsif decode_opcode = poppsw then
            reg_sel_rp_s    <= REG_SP;
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
            nxtstate <= pop_psw_1;

          -- push : (sp-1) <- rph, (sp-2) <- rpl
          elsif decode_opcode = push then
            -- sp = sp - 1
            regfile_cmd_o.decrp <= '1';
            regfile_cmd_o.reg_a <= REG_SPH;
            regfile_cmd_o.reg_b <= REG_SPL;
            nxtstate <= push_1;

          -- pushpsw
          elsif decode_opcode = pushpsw then
            -- sp = sp - 1
            regfile_cmd_o.decrp <= '1';
            regfile_cmd_o.reg_a <= REG_SPH;
            regfile_cmd_o.reg_b <= REG_SPL;
            reg_sel_a_s <= REG_A;
            nxtstate <= push_psw_1;

          -- ral: alu
          -- rar: alu

          -- rc : Return on Carry
          elsif decode_opcode = rc then
            if ctrlreg_alu_flags_i.carry = '1' then
              nxtstate <= ret_1;
            else
              nxtstate <= fetch_1;
            end if;

          -- ret
          elsif decode_opcode = ret then
            nxtstate <= ret_1;

          -- rlc: alu

          -- rm : Return on Minus
          elsif decode_opcode = rm then
            if ctrlreg_alu_flags_i.sign = '1' then
              nxtstate <= ret_1;
            else
              nxtstate <= fetch_1;
            end if;

          -- rnc : Return no Carry
          elsif decode_opcode = rnc then
            if ctrlreg_alu_flags_i.carry = '0' then
              nxtstate <= ret_1;
            else
              nxtstate <= fetch_1;
            end if;

          -- rnz : Return not Zero
          elsif decode_opcode = rnz then
            if ctrlreg_alu_flags_i.zero = '0' then
              nxtstate <= ret_1;
            else
              nxtstate <= fetch_1;
            end if;

          -- rp : Return on Positive
          elsif decode_opcode = rp then
            if ctrlreg_alu_flags_i.sign = '0' then
              nxtstate <= ret_1;
            else
              nxtstate <= fetch_1;
            end if;

          -- rpe : Return Parity Even
          elsif decode_opcode = rpe then
            if ctrlreg_alu_flags_i.parity = '1' then
              nxtstate <= ret_1;
            else
              nxtstate <= fetch_1;
            end if;

          -- rpo : Return Parity Odd
          elsif decode_opcode = rpo then
            if ctrlreg_alu_flags_i.parity = '0' then
              nxtstate <= ret_1;
            else
              nxtstate <= fetch_1;
            end if;

          -- rrc: alu

          -- rst0
          elsif decode_opcode = rst0 then
            reg_sel_a_s <= REG_TMP;
            regfile_cmd_o.wr <= '1';
            regfile_cmd_o.reg_a <= REG_TMP;
            regfile_din_sel_o <= REGF_DIN_SEL_CTRLO;
            ctrl_o <= x"00";
            nxtstate <= rst_1;

          -- rst1
          elsif decode_opcode = rst1 then
            reg_sel_a_s <= REG_TMP;
            regfile_cmd_o.wr <= '1';
            regfile_cmd_o.reg_a <= REG_TMP;
            regfile_din_sel_o <= REGF_DIN_SEL_CTRLO;
            ctrl_o <= x"08";
            nxtstate <= rst_1;

          -- rst2
          elsif decode_opcode = rst2 then
            reg_sel_a_s <= REG_TMP;
            regfile_cmd_o.wr <= '1';
            regfile_cmd_o.reg_a <= REG_TMP;
            regfile_din_sel_o <= REGF_DIN_SEL_CTRLO;
            ctrl_o <= x"10";
            nxtstate <= rst_1;

          -- rst3
          elsif decode_opcode = rst3 then
            reg_sel_a_s <= REG_TMP;
            regfile_cmd_o.wr <= '1';
            regfile_cmd_o.reg_a <= REG_TMP;
            regfile_din_sel_o <= REGF_DIN_SEL_CTRLO;
            ctrl_o <= x"18";
            nxtstate <= rst_1;

          -- rst4
          elsif decode_opcode = rst4 then
            reg_sel_a_s <= REG_TMP;
            regfile_cmd_o.wr <= '1';
            regfile_cmd_o.reg_a <= REG_TMP;
            regfile_din_sel_o <= REGF_DIN_SEL_CTRLO;
            ctrl_o <= x"20";
            nxtstate <= rst_1;

          -- rst5
          elsif decode_opcode = rst5 then
            reg_sel_a_s <= REG_TMP;
            regfile_cmd_o.wr <= '1';
            regfile_cmd_o.reg_a <= REG_TMP;
            regfile_din_sel_o <= REGF_DIN_SEL_CTRLO;
            ctrl_o <= x"28";
            nxtstate <= rst_1;

          -- rst6
          elsif decode_opcode = rst6 then
            reg_sel_a_s <= REG_TMP;
            regfile_cmd_o.wr <= '1';
            regfile_cmd_o.reg_a <= REG_TMP;
            regfile_din_sel_o <= REGF_DIN_SEL_CTRLO;
            ctrl_o <= x"30";
            nxtstate <= rst_1;

          -- rst7
          elsif decode_opcode = rst7 then
            reg_sel_a_s <= REG_TMP;
            regfile_cmd_o.wr <= '1';
            regfile_cmd_o.reg_a <= REG_TMP;
            regfile_din_sel_o <= REGF_DIN_SEL_CTRLO;
            ctrl_o <= x"38";
            nxtstate <= rst_1;

          -- rz : Return if Zero
          elsif decode_opcode = rz then
            if ctrlreg_alu_flags_i.zero = '1' then
              nxtstate <= ret_1;
            else
              nxtstate <= fetch_1;
            end if;

          -- sbb: alu

          -- sbbm
          elsif decode_opcode = sbbm then
            reg_sel_rp_s <= REG_HL;
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
            nxtstate <= hlmem2alu2accum_1;

          -- sbi
          elsif decode_opcode = sbi then
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= pcmem2alu2accum_1;

          -- shld
          elsif decode_opcode = shld then
            reg_sel_a_s <= REG_W;
            reg_sel_b_s <= REG_Z;
            nxtstate <= shld_1;

          -- sphl
          elsif decode_opcode = sphl then
            regfile_cmd_o.reg_a <= REG_SPL;
            regfile_cmd_o.reg_b <= REG_L;
            regfile_cmd_o.mov <= '1';
            nxtstate <= sphl_1;

          -- sta
          elsif decode_opcode = sta then
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= sta_1;

          -- stax
          elsif decode_opcode = stax then
            nxtstate <= stax_1;

          -- stc
          elsif decode_opcode = stc then
            ctrlreg_cmd_o.alu_carry_set <= '1';
            ctrlreg_cmd_o.val <= '1';
            nxtstate <= fetch_1;

          -- sub: alu

          -- subm
          elsif decode_opcode = subm then
            reg_sel_rp_s <= REG_HL;
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
            nxtstate <= hlmem2alu2accum_1;

          -- sui
          elsif decode_opcode = sui then
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= pcmem2alu2accum_1;

          -- xchg
          elsif decode_opcode = xchg then
            regfile_cmd_o.xchg <= '1';
            nxtstate <= fetch_1;

          -- xra: alu

          -- xram
          elsif decode_opcode = xram then
            reg_sel_rp_s <= REG_HL;
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_RP;
            nxtstate <= hlmem2alu2accum_1;

          -- xri
          elsif decode_opcode = xri then
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= pcmem2alu2accum_1;

          -- xthl
          elsif decode_opcode = xthl then
            -- z <= spl
            regfile_cmd_o.reg_a <= REG_Z;
            regfile_cmd_o.reg_b <= REG_SPL;
            regfile_cmd_o.mov <= '1';
            nxtstate <= xthl_1;

          -- und
          elsif decode_opcode = und then
            -- undefined is a nop
            nxtstate <= fetch_1;

          -- IN port
          elsif decode_opcode = inport then
            -- Read port number from PC
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= inport_1;

          -- OUT port
          elsif decode_opcode = outport then
            -- Read port number from PC
            munit_rd_s      <= '1';
            munit_ain_sel_s <= MUNIT_AIN_SEL_PC;
            nxtstate <= outport_1;

          else
            nxtstate <= fetch_1;
          end if;
        end if;

    end case;
  end process;

end rtl;
