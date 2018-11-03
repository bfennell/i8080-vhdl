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

entity cpu8080_testbench is
end cpu8080_testbench;

architecture sim of cpu8080_testbench is

  component cpu8080_top
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
          port_sel_o : out std_logic_vector(7 downto 0));
  end component;

  component cpu8080_memory
    port (clk_i      : in  std_logic;
          rst_i      : in  std_logic;
          sel_i      : in  std_logic;
          nwr_i      : in  std_logic;
          addr_i     : in  std_logic_vector(15 downto 0);
          data_i     : in  std_logic_vector(7 downto 0);
          ready_o    : out std_logic;
          data_o     : out std_logic_vector(7 downto 0));
  end component;

  signal clk    : std_logic := '0';
  signal reset  : std_logic := '0';
  signal ready  : std_logic;
  signal data_i : std_logic_vector(7 downto 0);  -- in data to cpu8080
  signal sel    : std_logic;
  signal nwr    : std_logic;
  signal data_o : std_logic_vector(7 downto 0);  -- out data from cpu8080
  signal addr   : std_logic_vector(15 downto 0);
  signal inta   : std_logic;
  signal port_out : std_logic_vector(7 downto 0);
  signal port_nwr : std_logic;
  signal port_sel : std_logic_vector(7 downto 0);

begin
  clk <= not clk after 50 ns; -- 10Mhz

  process
    variable tmp : integer := 0;
  begin
    if reset = '0' and tmp = 0 then
      reset <= '1';
    end if;
    wait for 10 ns;
    tmp := 1;
    reset <= '0';
  end process;

  inst_cpu8080: cpu8080_top port map (
    clk_i      => clk,
    reset_i    => reset,
    ready_i    => ready,
    int_i      => '0',
    nnn_i      => (others => '0'),
    data_i     => data_i,
    port_i     => (others => '0'),
    port_rdy_i => '0',
    inta_o     => inta,
    sel_o      => sel,
    nwr_o      => nwr,
    addr_o     => addr,
    data_o     => data_o,
    port_o     => port_out,
    port_nwr_o => port_nwr,
    port_sel_o => port_sel
    );

  inst_mem: cpu8080_memory port map (
    clk_i   => clk,
    rst_i   => reset,
    sel_i   => sel,
    nwr_i   => nwr,
    addr_i  => addr,
    data_i  => data_o,
    ready_o => ready,
    data_o  => data_i
    );

end sim;
