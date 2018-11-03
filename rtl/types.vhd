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

package cpu8080_types is
  -- Register Selection
  subtype reg_t is unsigned(3 downto 0);
  constant REG_B   : reg_t := x"0";
  constant REG_C   : reg_t := x"1";
  constant REG_D   : reg_t := x"2";
  constant REG_E   : reg_t := x"3";
  constant REG_H   : reg_t := x"4";
  constant REG_L   : reg_t := x"5";
  constant REG_M   : reg_t := x"6";
  constant REG_A   : reg_t := x"7";
  constant REG_W   : reg_t := x"8";
  constant REG_Z   : reg_t := x"9";
  constant REG_ACT : reg_t := x"a";
  constant REG_TMP : reg_t := x"b";
  constant REG_SPH : reg_t := x"c";
  constant REG_SPL : reg_t := x"d";
  constant REG_PCH : reg_t := x"e";
  constant REG_PCL : reg_t := x"f";

  -- Register pair selection
  subtype reg_pair_t is unsigned(2 downto 0);
  constant REG_PC : reg_pair_t := "000";
  constant REG_SP : reg_pair_t := "001";
  constant REG_BC : reg_pair_t := "010";
  constant REG_DE : reg_pair_t := "011";
  constant REG_HL : reg_pair_t := "100";
  constant REG_WZ : reg_pair_t := "101";

  type regfile_cmd_t is
  record
    wr    : std_logic;
    rd    : std_logic;
    incpc : std_logic;
    incrp : std_logic;
    decrp : std_logic;
    mov   : std_logic;
    xchg  : std_logic;
    reg_a : reg_t;
    reg_b : reg_t;
  end record;

  constant regfile_cmd_null_c : regfile_cmd_t := (
    wr    => '0',
    rd    => '0',
    incpc => '0',
    incrp => '0',
    decrp => '0',
    mov   => '0',
    xchg  => '0',
    reg_a => REG_A,
    reg_b => REG_B
    );

  -- ALU flags
  type alu_flags_t is
  record
    carry     : std_logic;
    aux_carry : std_logic;
    zero      : std_logic;
    parity    : std_logic;
    sign      : std_logic;
  end record;

  constant alu_flags_null_c : alu_flags_t := (
    carry     => '0',
    aux_carry => '0',
    zero      => '0',
    parity    => '0',
    sign      => '0'
    );

  type ctrlreg_cmd_t is
  record
    instr_wr         : std_logic;
    alu_flags_wr     : std_logic;
    alu_carry_wr     : std_logic;
    alu_carry_set    : std_logic;
    alu_psw_wr       : std_logic;
    alu_flags_store  : std_logic;
    inten_set        : std_logic;
    val              : std_logic;
  end record;

  constant ctrlreg_cmd_null_c : ctrlreg_cmd_t := (
    instr_wr         => '0',
    alu_flags_wr     => '0',
    alu_carry_wr     => '0',
    alu_carry_set    => '0',
    alu_psw_wr       => '0',
    alu_flags_store  => '0',
    inten_set        => '0',
    val              => '0'
    );

  -- REGFILE: data in select
  constant REGF_DIN_SEL_MDATA : std_logic_vector(1 downto 0) := "00";
  constant REGF_DIN_SEL_ALUO  : std_logic_vector(1 downto 0) := "01";
  constant REGF_DIN_SEL_CTRLO : std_logic_vector(1 downto 0) := "10";
  constant REGF_DIN_SEL_PORTI : std_logic_vector(1 downto 0) := "11";

  -- MUNIT: address in select
  constant MUNIT_AIN_SEL_PC : std_logic := '0';
  constant MUNIT_AIN_SEL_RP : std_logic := '1';

  -- MUNIT: data in select
  constant MUNIT_DIN_SEL_REGA  : std_logic_vector(2 downto 0) := "001";
  constant MUNIT_DIN_SEL_REGB  : std_logic_vector(2 downto 0) := "010";
  constant MUNIT_DIN_SEL_ALUO  : std_logic_vector(2 downto 0) := "011";
  constant MUNIT_DIN_SEL_CTRLO : std_logic_vector(2 downto 0) := "100";
  constant MUNIT_DIN_SEL_PSW   : std_logic_vector(2 downto 0) := "101";

  -- ALU ops
  subtype alu_op_t is unsigned(4 downto 0);

  constant alu_op_nop : alu_op_t := "00000";
  constant alu_op_add : alu_op_t := "00001";
  constant alu_op_adc : alu_op_t := "00010";
  constant alu_op_sub : alu_op_t := "00011";
  constant alu_op_sbb : alu_op_t := "00100";
  constant alu_op_and : alu_op_t := "00101";
  constant alu_op_xor : alu_op_t := "00110";
  constant alu_op_or  : alu_op_t := "00111";
  constant alu_op_rlc : alu_op_t := "01000";
  constant alu_op_rrc : alu_op_t := "01001";
  constant alu_op_ral : alu_op_t := "01010";
  constant alu_op_rar : alu_op_t := "01011";
  constant alu_op_cma : alu_op_t := "01100";
  constant alu_op_daa : alu_op_t := "01101";
  constant alu_op_cmp : alu_op_t := "01110";
  constant alu_op_dcr : alu_op_t := "01111";
  constant alu_op_inr : alu_op_t := "10000";
  constant alu_op_ani : alu_op_t := "10001";

  type opcode_t is (aci,
                    adc,
                    adcm,
                    add,
                    addm,
                    adi,
                    ana,
                    anam,
                    ani,
                    call,
                    cc,
                    cm,
                    cma,
                    cmc,
                    cmp,
                    cmpm,
                    cnc,
                    cnz,
                    cp,
                    cpe,
                    cpi,
                    cpo,
                    cz,
                    daa,
                    dad,
                    dcr,
                    dcrm,
                    dcx,
                    di,
                    ei,
                    hlt,
                    inport,
                    inr,
                    inrm,
                    inx,
                    jc,
                    jm,
                    jmp,
                    jnc,
                    jnz,
                    jp,
                    jpe,
                    jpo,
                    jz,
                    lda,
                    ldax,
                    lhld,
                    lxi,
                    movr2r,
                    movr2m,
                    movm2r,
                    mvi2r,
                    mvi2m,
                    nop,
                    ora,
                    oram,
                    ori,
                    outport,
                    pchl,
                    pop,
                    poppsw,
                    push,
                    pushpsw,
                    ral,
                    rar,
                    rc,
                    ret,
                    rlc,
                    rm,
                    rnc,
                    rnz,
                    rp,
                    rpe,
                    rpo,
                    rrc,
                    rst0,
                    rst1,
                    rst2,
                    rst3,
                    rst4,
                    rst5,
                    rst6,
                    rst7,
                    rz,
                    sbb,
                    sbbm,
                    sbi,
                    shld,
                    sphl,
                    sta,
                    stax,
                    stc,
                    sub,
                    subm,
                    sui,
                    xchg,
                    xra,
                    xram,
                    xri,
                    xthl,
                    und
                    );

end cpu8080_types;

package body cpu8080_types is
end cpu8080_types;
