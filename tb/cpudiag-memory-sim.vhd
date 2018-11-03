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
use std.textio.all;

-----------------------------------------------------------
-- 0000-1fff : 8k ROM
-- 2000-23ff : 1k RAM
-- 2400-3fff : 7k Video RAM
-- 4000- : RAM Mirror
-----------------------------------------------------------

entity cpu8080_memory is

  port (clk_i      : in  std_logic;
        rst_i      : in  std_logic;
        sel_i      : in  std_logic;
        nwr_i      : in  std_logic;
        addr_i     : in  std_logic_vector(15 downto 0);
        data_i     : in  std_logic_vector(7 downto 0);
        ready_o    : out std_logic;
        data_o     : out std_logic_vector(7 downto 0));

end cpu8080_memory;

architecture beh of cpu8080_memory is
  constant ROM_SIZE  : integer := ((1024*8)-1);
  constant RAM_SIZE  : integer := ((1024*1)-1);
  constant VRAM_SIZE : integer := ((1024*7)-1);
  type rom_t  is array(0 to ROM_SIZE)  of std_logic_vector(7 downto 0);
  type ram_t  is array(0 to RAM_SIZE)  of std_logic_vector(7 downto 0);
  type vram_t is array(0 to VRAM_SIZE) of std_logic_vector(7 downto 0);

  procedure hread(L : inout line; value : out std_logic_vector(3 downto 0)) is
    variable ival : character;
  begin
    read(L,ival);
    case ival is
      when '0' => value := x"0";
      when '1' => value := x"1";
      when '2' => value := x"2";
      when '3' => value := x"3";
      when '4' => value := x"4";
      when '5' => value := x"5";
      when '6' => value := x"6";
      when '7' => value := x"7";
      when '8' => value := x"8";
      when '9' => value := x"9";
      when 'a' => value := x"a";
      when 'b' => value := x"b";
      when 'c' => value := x"c";
      when 'd' => value := x"d";
      when 'e' => value := x"e";
      when 'f' => value := x"f";
      when others => value := "1010";
    end case;
  end procedure;

  -- read an ascii text file into a 'rom_t'
  impure function read_hexfile (filename : STRING) return rom_t is
    file filehandle : text open read_mode is filename;
    variable curr   : line;
    variable hi     : std_logic_vector(3 downto 0);
    variable lo     : std_logic_vector(3 downto 0);
    variable temp   : std_logic_vector(7 downto 0);
    variable result : rom_t := (others => (others => '0'));
  begin
    for i in 0 to ROM_SIZE loop
      exit when endfile(filehandle);
      readline(filehandle, curr);
      hread(curr, hi);
      hread(curr, lo);
      temp := hi & lo;
      result(i) := temp;
    end loop;
    return result;
  end function;

  signal rom  : rom_t  := read_hexfile (filename => "tb/cpudiag_mod.hex");
  signal ram  : ram_t  := (others => (others => '0'));
  signal vram : vram_t := (others => (others => '0'));
begin
  memory: process(clk_i,addr_i,rst_i,sel_i,nwr_i,rom,ram,vram,data_i)
    variable addr : integer;
    variable rom_addr : integer;
    variable ram_addr : integer;
    variable vram_addr : integer;
  begin
    addr      := to_integer(unsigned(addr_i(15 downto 0)));
    rom_addr  := (to_integer(unsigned(addr_i(15 downto 0))) - (1024*0));
    ram_addr  := (to_integer(unsigned(addr_i(15 downto 0))) - (1024*8));
    vram_addr := (to_integer(unsigned(addr_i(15 downto 0))) - (1024*9));

    if clk_i'event and clk_i = '1' then
      if rst_i = '1' then
        data_o <= (others => '0');
        ready_o <= '0';
      elsif sel_i = '1' then
        if nwr_i = '1' then -- write
          -- rom 0k ... 8k
          if addr >= 0 and addr < (1024*8) then
            data_o <= rom(rom_addr);
            ready_o <= '1';
          -- ram 8k ... 9k
          elsif addr >= (1024*8) and addr < (1024*9) then
            data_o <= ram(ram_addr);
            ready_o <= '1';
          -- vram 9k ... 16k
          elsif addr >= (1024*9) and addr < (1024*16) then
            data_o <= vram(vram_addr);
            ready_o <= '1';
          else
            assert false report "****** read: invalid address: " & integer'image(addr) severity warning;
          end if;
        else -- read
          -- rom 0k ... 8k
          if addr >= 0 and addr < (1024*8) then
            rom(rom_addr) <= data_i;
            ready_o <= '1';
          -- ram 8k ... 9k
          elsif addr >= (1024*8) and addr < (1024*9) then
            ram(ram_addr) <= data_i;
            ready_o <= '1';
          -- vram 9k ... 16k
          elsif addr >= (1024*9) and addr < (1024*16) then
            vram(vram_addr) <= data_i;
            ready_o <= '1';
          else
            assert false report "****** write: invalid address: " & integer'image(addr) severity warning;
          end if;
        end if;
      else
        ready_o <= '0';
      end if;
    end if;
  end process;
end beh;
