library ieee;
use ieee.std_logic_1164.all;

entity invaders is

  port (clk_i      : in  std_logic;
        sel_i      : in  std_logic;
        nwr_i      : in  std_logic;
        addr_i     : in  std_logic_vector(15 downto 0);
        data_i     : in  std_logic_vector(7 downto 0);
        ready_o    : out std_logic;
        data_o     : out std_logic_vector(7 downto 0));

end invaders;

architecture cmodel of invaders is
  attribute foreign : string;
  attribute foreign of cmodel : architecture is "invaders_init tb/invaders.so";

begin

end cmodel;
