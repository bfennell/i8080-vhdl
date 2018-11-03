library work;
use work.cpu8080_types.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu8080_alu is

  port (alu_op_i    : in  alu_op_t;
        alu_a_i     : in  unsigned(7 downto 0);
        alu_b_i     : in  unsigned(7 downto 0);
        alu_flags_i : in  alu_flags_t;
        alu_flags_o : out alu_flags_t;
        alu_out_o   : out unsigned(7 downto 0));

end cpu8080_alu;

architecture rtl of cpu8080_alu is
  signal alu_out : unsigned(7 downto 0);

begin
  alu_out_o <= alu_out;

  alu: process(alu_op_i,alu_a_i,alu_b_i,alu_flags_i)

    variable result : unsigned(8 downto 0);
    variable parity : std_logic;
    variable update : boolean;
  begin
    result := (others => '0');
    alu_flags_o <= alu_flags_i;
    update := true;

    case alu_op_i is
      -- nop
      when alu_op_nop =>
        alu_out <= alu_a_i;

      -- add,adi
      when alu_op_add =>
        result := (("0" & alu_a_i) + ("0" & alu_b_i));
        alu_out <= result(7 downto 0);
        alu_flags_o.carry <= result(8);
        alu_flags_o.aux_carry <= (result(4) xor alu_a_i(4) xor alu_b_i(4));

      -- adc,aci
      when alu_op_adc =>
        result := (("0" & alu_a_i) + ("0" & alu_b_i) + ("0000000" & alu_flags_i.carry));
        alu_out <= result(7 downto 0);
        alu_flags_o.carry <= result(8);
        alu_flags_o.aux_carry <= (result(4) xor alu_a_i(4) xor alu_b_i(4));

      when alu_op_sub =>
        result := (("0" & alu_a_i) - ("0" & alu_b_i));
        alu_out <=  result(7 downto 0);
        alu_flags_o.carry <= result(8);
        alu_flags_o.aux_carry <= (result(4) xor alu_a_i(4) xor alu_b_i(4));

      when alu_op_sbb =>
        result := (("0" & alu_a_i) - ("0" & alu_b_i) - ("00000000" & alu_flags_i.carry));
        alu_out <=  result(7 downto 0);
        alu_flags_o.carry <= result(8);
        alu_flags_o.aux_carry <= (result(4) xor alu_a_i(4) xor alu_b_i(4));

      -- ana,anm
      when alu_op_and =>
        result := ("0" & (alu_a_i and alu_b_i));
        alu_out   <= result(7 downto 0);
        alu_flags_o.carry <= '0';
        alu_flags_o.aux_carry <= result(4) xor (alu_a_i(4) xor alu_b_i(4));

      -- ani
      when alu_op_ani =>
        result := ("0" & (alu_a_i and alu_b_i));
        alu_out   <= result(7 downto 0);
        alu_flags_o.carry <= '0';
        alu_flags_o.aux_carry <= '0';

      -- xra,xri
      when alu_op_xor =>
        result := ("0" & (alu_a_i xor alu_b_i));
        alu_out   <= result(7 downto 0);
        alu_flags_o.carry <= '0';
        alu_flags_o.aux_carry <= '0';

      -- ora,ori
      when alu_op_or =>
        result := ("0" & (alu_a_i or alu_b_i));
        alu_out   <= result(7 downto 0);
        alu_flags_o.carry <= '0';
        alu_flags_o.aux_carry <= '0';

      -- rlc
      when alu_op_rlc =>
        alu_out  <= (alu_a_i(6 downto 0) & alu_a_i(7));
        alu_flags_o.carry <= alu_a_i(7);
        update := false;

      -- rrc
      when alu_op_rrc =>
        alu_out  <= (alu_a_i(0) & alu_a_i(7 downto 1));
        alu_flags_o.carry <= alu_a_i(0);
        update := false;

      -- ral
      when alu_op_ral =>
        alu_out  <= (alu_a_i(6 downto 0)) & alu_flags_i.carry;
        alu_flags_o.carry <= alu_a_i(7);
        update := false;

      -- rar
      when alu_op_rar =>
        alu_out  <= alu_flags_i.carry & alu_a_i(7 downto 1);
        alu_flags_o.carry <= alu_a_i(0);
        update := false;

      -- cma
      when alu_op_cma =>
        alu_out <= not alu_a_i;
        update := false;

      -- daa
      --
      -- if (((a & 0xf) > 9) || (aux_carry == 1)) {
      --     a = a + 6;
      --     aux_carry = 1;
      -- } else {
      --     aux_carry = 0;
      -- }
      -- if (((a > 0x9f) || (carry == 1)) {
      --     a = a + 0x60;
      --     carry = 1;
      -- } else {
      --     carry = 0;
      -- }
      --
      when alu_op_daa =>
        result := ("0" & alu_a_i);
        if (alu_a_i(3 downto 0) > 9) or (alu_flags_i.aux_carry = '1') then
          result := "0" & (alu_a_i + x"06");
          alu_flags_o.aux_carry <= '1';
        else
          alu_flags_o.aux_carry <= '0';
        end if;
        if (result(7 downto 4) > 9) or (alu_flags_i.carry = '1') then
          result := result + x"60";
          alu_flags_o.carry <= '1';
        else
          alu_flags_o.carry <= '0';
        end if;
        alu_out <= result(7 downto 0);

      -- cmp
      when alu_op_cmp =>
        result := (("0" & alu_a_i) - ("0" & alu_b_i));
        alu_out <=  result(7 downto 0);
        alu_flags_o.aux_carry <= (result(4) xor alu_a_i(4) xor alu_b_i(4));
        if alu_a_i < alu_b_i then
           alu_flags_o.carry <= '1';
        else
           alu_flags_o.carry <= '0';
        end if;

      -- dcr
      when alu_op_dcr =>
        result := (("0" & alu_a_i) - ("0" & x"01"));
        alu_out <=  result(7 downto 0);
        alu_flags_o.carry <= alu_flags_i.carry;
        alu_flags_o.aux_carry <= (result(4) xor alu_a_i(4));

      -- incr
      when alu_op_inr =>
        result := (("0" & alu_a_i) + ("0" & x"01"));
        alu_out <=  result(7 downto 0);
        alu_flags_o.carry <= alu_flags_i.carry;
        alu_flags_o.aux_carry <= (result(4) xor alu_a_i(4));

      when others =>
        alu_out <= alu_a_i;
    end case;

    if update then
      -- update Parity
      parity := '1';
      for i in 7 downto 0 loop
        parity := parity xor result(i);
      end loop;
      alu_flags_o.parity <= parity;

      -- update Zero
      if result(7 downto 0) = "00000000" then
        alu_flags_o.zero <= '1';
      else
        alu_flags_o.zero <= '0';
      end if;

      -- update Sign
      alu_flags_o.sign <= result(7);
    end if;

  end process;
end rtl;
