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

entity cpu8080_decode is

  port (instr_i      : in unsigned(7 downto 0);
        opcode_o     : out opcode_t;
        alu_op_o     : out alu_op_t;
        alu_only_o   : out std_logic;
        regfile_sel_a_o  : out reg_t;
        regfile_sel_b_o  : out reg_t;
        regfile_sel_rp_o : out reg_pair_t
        );

end cpu8080_decode;

architecture rtl of cpu8080_decode is

begin

  decode: process(instr_i)
    variable sss : reg_t; -- source reg     : 00000sss
    variable ddd : reg_t; -- destination    : 00ddd000
    variable aaa : reg_t; -- first of pair  : 00aaa000
    variable bbb : reg_t; -- second of pair : aaa + 1
  begin
    -- defaults
    opcode_o     <= nop;
    alu_op_o     <= alu_op_nop;
    alu_only_o   <= '0';
    regfile_sel_a_o  <= REG_A;
    regfile_sel_b_o  <= REG_A;
    regfile_sel_rp_o <= REG_HL;

    -- source and dest for ALU
    sss := ("0" & instr_i(2 downto 0));
    ddd := ("0" & instr_i(5 downto 3));

    -- register pairs
    aaa := ("0" & instr_i(5 downto 4) & "0");
    bbb := ("0" & instr_i(5 downto 4) & "1");

    if instr_i(7 downto 6) = "00" then
      if instr_i(2 downto 0) = "000" then
        -- 00 "00000000" | NOP | No Operation
        opcode_o <= nop;
      elsif instr_i(2 downto 0) = "001" then
        if instr_i(3) = '1' then
          if instr_i(5 downto 3) = "111" then
            -- 39 "00111001" | DAD   SP | HL <- HL + SP
            opcode_o    <= dad;
            regfile_sel_a_o <= REG_SPH;
            regfile_sel_b_o <= REG_SPL;
          else
            -- 09 "00001001" | DAD   B  | HL <- HL + BC
            -- 19 "00011001" | DAD   D  | HL <- HL + DE
            -- 29 "00101001" | DAD   H  | HL <- HL + HL
            opcode_o    <= dad;
            regfile_sel_a_o <= aaa;
            regfile_sel_b_o <= bbb;
          end if;
        else
          if instr_i(5 downto 3) = "110" then
            -- 31word "00110001" | LXI SP,word | SP <- word
            opcode_o    <= lxi;
            regfile_sel_a_o <= REG_SPH;
            regfile_sel_b_o <= REG_SPL;
          else
            -- 01word "00000001" | LXI B,word  | BC <- word
            -- 11word "00010001" | LXI D,word  | DE <- word
            -- 21word "00100001" | LXI H,word  | HL <- word
            opcode_o    <= lxi;
            regfile_sel_a_o <= aaa;
            regfile_sel_b_o <= bbb;
          end if;
        end if;
      elsif instr_i(2 downto 0) = "010" then
        if instr_i(5 downto 3) = "000" then
          -- 02 "00000010" | STAX  B | (BC) <- A
          opcode_o    <= stax;
          regfile_sel_rp_o <= REG_BC;
        elsif instr_i(5 downto 3) = "001" then
          -- 0A "00001010" | LDAX  B | A <- (BC)
          opcode_o    <= ldax;
          regfile_sel_rp_o <= REG_BC;
        elsif instr_i(5 downto 3) = "010" then
          -- 12 "00010010" | STAX  D       | (DE) <- A
          opcode_o    <= stax;
          regfile_sel_rp_o <= REG_DE;
        elsif instr_i(5 downto 3) = "011" then
          -- 1A "00011010" | LDAX  D       | A <- (DE)
          opcode_o    <= ldax;
          regfile_sel_rp_o <= REG_DE;
        elsif instr_i(5 downto 3) = "100" then
          -- 22word "00100010" | SHLD  word    | (word) <- HL
          opcode_o    <= shld;
          regfile_sel_rp_o <= REG_HL;
        elsif instr_i(5 downto 3) = "101" then
          -- 2Aword "00101010" | LHLD  word    | HL <- (word)
          opcode_o    <= lhld;
          regfile_sel_rp_o <= REG_HL;
        elsif instr_i(5 downto 3) = "110" then
          -- 32word "00110010" | STA   word    | (word) <- A
          opcode_o <= sta;
        else -- "111"
          -- 3Aword "00111010" | LDA   word    | A <- (word)
          opcode_o <= lda;
        end if;
      elsif instr_i(2 downto 0) = "011" then
        if instr_i(3) = '1' then
          if instr_i(5 downto 3) = "111" then
            -- 3B "00111011" | DCX   SP | SP <- SP - 1
            opcode_o    <= dcx;
            regfile_sel_a_o <= REG_SPH;
            regfile_sel_b_o <= REG_SPL;
          else
            -- 0B "00001011" | DCX   B | BC <- BC - 1
            -- 1B "00011011" | DCX   D | DE <- DE - 1
            -- 2B "00101011" | DCX   H | HL <- HL - 1
            opcode_o    <= dcx;
            regfile_sel_a_o <= aaa;
            regfile_sel_b_o <= bbb;
          end if;
        else
          if instr_i(5 downto 3) = "110" then
            -- 33 "00110011" | INX   SP | SP <- SP + 1
            opcode_o    <= inx;
            regfile_sel_a_o <= REG_SPH;
            regfile_sel_b_o <= REG_SPL;
          else
            -- 03 "00000011" | INX   B | BC <- BC + 1
            -- 13 "00010011" | INX   D | DE <- DE + 1
            -- 23 "00100011" | INX   H | HL <- HL + 1
            opcode_o    <= inx;
            regfile_sel_a_o <= aaa;
            regfile_sel_b_o <= bbb;
          end if;
        end if;
      elsif instr_i(2 downto 0) = "100" then
        if instr_i(5 downto 3) = "110" then
          -- 34 "00110100" | INR   M | (HL) <- (HL) + 1
          opcode_o <= inrm;
          alu_op_o <= alu_op_inr;
        else
          -- xx "00ddd100" | INR {b,c,d,e,h,l,a} | R <- R + 1
          opcode_o    <= inr;
          regfile_sel_a_o <= ddd;
          alu_op_o    <= alu_op_inr;
        end if;
      elsif instr_i(2 downto 0) = "101" then
        if instr_i(5 downto 3) = "110" then
          -- 35 "00110101" | DCR   M | (HL) <- (HL) - 1
          opcode_o <= dcrm;
          alu_op_o <= alu_op_dcr;
        else
          -- xx "00ddd101" | DCR {b,c,d,e,h,l,a} | R <- R - 1
          opcode_o    <= dcr;
          regfile_sel_a_o <= ddd;
          alu_op_o    <= alu_op_dcr;
        end if;
      elsif instr_i(2 downto 0) = "110" then
        if instr_i(5 downto 3) = "110" then
          -- 36byte "00110110" | MVI   M,byte  | (HL) <- byte
          opcode_o <= mvi2m;
        else
          -- 06byte "00000110" | MVI   B,byte  | B <- byte
          -- 0Ebyte "00001110" | MVI   C,byte  | C <- byte
          -- 16byte "00010110" | MVI   D,byte  | D <- byte
          -- 1Ebyte "00011110" | MVI   E,byte  | E <- byte
          -- 26byte "00100110" | MVI   H,byte  | H <- byte
          -- 2Ebyte "00101110" | MVI   L,byte  | L <- byte
          -- 3Ebyte "00111110" | MVI   A,byte  | A <- byte
          opcode_o    <= mvi2r;
          regfile_sel_a_o <= ddd;
        end if;
      else -- "111"
        if instr_i(5 downto 3) = "000" then
          -- 07 "00000111" | RLC
          opcode_o <= rlc;
          alu_op_o <= alu_op_rlc;
          alu_only_o <= '1';
        elsif instr_i(5 downto 3) = "001" then
          -- 0F "00001111" | RRC
          opcode_o <= rrc;
          alu_op_o <= alu_op_rrc;
          alu_only_o <= '1';
        elsif instr_i(5 downto 3) = "010" then
          -- 17 "00010111" | RAL
          opcode_o <= ral;
          alu_op_o <= alu_op_ral;
          alu_only_o <= '1';
        elsif instr_i(5 downto 3) = "011" then
          -- 1F "00011111" | RAR
          opcode_o <= rar;
          alu_op_o <= alu_op_rar;
          alu_only_o <= '1';
        elsif instr_i(5 downto 3) = "100" then
          -- 27 "00100111" | DAA
          opcode_o <= daa;
          alu_op_o <= alu_op_daa;
          alu_only_o <= '1';
        elsif instr_i(5 downto 3) = "101" then
          -- 2F "00101111" | CMA | A <- NOT A
          opcode_o <= cma;
          alu_op_o <= alu_op_cma;
          alu_only_o <= '1';
        elsif instr_i(5 downto 3) = "110" then
          -- 37 "00110111" | STC | CF (Carry Flag) <- 1
          opcode_o <= stc;
        else -- "111"
          -- 3F "00111111" | CMC | CF (Carry Flag) <- NOT CF
          opcode_o <= cmc;
        end if;
      end if;
    ------------------------------------------------
    elsif instr_i(7 downto 6) = "01" then
      if instr_i(5 downto 3) = "110" then
        if instr_i(2 downto 0) = "110" then
          -- 76 "01110110" | HLT | NOP;PC <- PC-1
          opcode_o <= hlt;
        else
          -- 70 "01110000" | MOV   M,B     | (HL) <- B
          -- 71 "01110001" | MOV   M,C     | (HL) <- C
          -- 72 "01110010" | MOV   M,D     | (HL) <- D
          -- 73 "01110011" | MOV   M,E     | (HL) <- E
          -- 74 "01110100" | MOV   M,H     | (HL) <- H
          -- 75 "01110101" | MOV   M,L     | (HL) <- L
          -- 77 "01110111" | MOV   M,A     | (HL) <- A
          opcode_o    <= movr2m;
          regfile_sel_b_o <= sss;
        end if;
      else
        if instr_i(2 downto 0) = "110" then
          -- 46 "01000110" | MOV   B,M     | B <- (HL)
          -- 4E "01001110" | MOV   C,M     | C <- (HL)
          -- 56 "01010110" | MOV   D,M     | D <- (HL)
          -- 5E "01011110" | MOV   E,M     | E <- (HL)
          -- 66 "01100110" | MOV   H,M     | H <- (HL)
          -- 6E "01101110" | MOV   L,M     | L <- (HL)
          -- 7E "01111110" | MOV   A,M     | A <- (HL)
          opcode_o    <= movm2r;
          regfile_sel_a_o <= ddd;
        else
          -- xx "01dddsss" | MOV {b,c,d,e,h,l,a}, {b,c,d,e,h,l,a} | R <- R
          opcode_o    <= movr2r;
          regfile_sel_a_o <= ddd;
          regfile_sel_b_o <= sss;
        end if;
      end if;
    ------------------------------------------------
    elsif instr_i(7 downto 6) = "10" then
      if instr_i(5 downto 3) = "000" then
        if instr_i(2 downto 0) = "110" then
          -- 86 "10000110" | ADD   M | A <- A + (HL)
          opcode_o <= addm;
          alu_op_o <= alu_op_add;
        else
          -- xx "10000sss" | ADD {b,c,d,e,h,l,a} | A <- A + R
          opcode_o    <= add;
          alu_op_o    <= alu_op_add;
          alu_only_o  <= '1';
          regfile_sel_a_o <= REG_A;
          regfile_sel_b_o <= sss;
        end if;
      elsif instr_i(5 downto 3) = "001" then
        if instr_i(2 downto 0) = "110" then
          -- 8E "10001110" | ADC   M | A <- A + (HL) + Carry
          opcode_o <= adcm;
          alu_op_o <= alu_op_adc;
        else
          -- xx "10001sss" | ADC {b,c,d,e,h,l,a} | A <- A + R + Carry
          opcode_o    <= adc;
          alu_op_o    <= alu_op_adc;
          alu_only_o  <= '1';
          regfile_sel_a_o <= REG_A;
          regfile_sel_b_o <= sss;
        end if;
      elsif instr_i(5 downto 3) = "010" then
        if instr_i(2 downto 0) = "110" then
          -- 96 "10010110" | SUB   M | A <- A - (HL)
          opcode_o <= subm;
          alu_op_o <= alu_op_sub;
        else
          -- xx "10010sss" | SUB {b,c,d,e,h,l,a} | A <- A - R
          opcode_o    <= sub;
          alu_op_o    <= alu_op_sub;
          alu_only_o  <= '1';
          regfile_sel_a_o <= REG_A;
          regfile_sel_b_o <= sss;
        end if;
      elsif instr_i(5 downto 3) = "011" then
        if instr_i(2 downto 0) = "110" then
          -- 9E "10011110" | SBB   M | A <- A - (HL) - Carry
          opcode_o <= sbbm;
          alu_op_o <= alu_op_sbb;
        else
          -- xx "10011sss" | SBB {b,c,d,e,h,l,a} | A <- A - R - Carry
          opcode_o    <= sbb;
          alu_op_o    <= alu_op_sbb;
          alu_only_o  <= '1';
          regfile_sel_a_o <= REG_A;
          regfile_sel_b_o <= sss;
        end if;
      elsif instr_i(5 downto 3) = "100" then
        if instr_i(2 downto 0) = "110" then
          -- A6 "10100110" | ANA   M | A <- A AND (HL)
          opcode_o <= anam;
          alu_op_o <= alu_op_and;
        else
          -- xx "10100sss" | AND {b,c,d,e,h,l,a} | A <- A AND R
          opcode_o    <= ana;
          alu_op_o    <= alu_op_and;
          alu_only_o  <= '1';
          regfile_sel_a_o <= REG_A;
          regfile_sel_b_o <= sss;
        end if;
      elsif instr_i(5 downto 3) = "101" then
        if instr_i(2 downto 0) = "110" then
          -- AE "10101110" | XRA   M | A <- A XOR (HL)
          opcode_o <= xram;
          alu_op_o <= alu_op_xor;
        else
          -- xx "10101sss" | XOR {b,c,d,e,h,l,a}
          opcode_o    <= xra;
          alu_op_o    <= alu_op_xor;
          alu_only_o  <= '1';
          regfile_sel_a_o <= REG_A;
          regfile_sel_b_o <= sss;
        end if;
      elsif instr_i(5 downto 3) = "110" then
        if instr_i(2 downto 0) = "110" then
          -- B6 "10110110" | ORA   M | A <- A OR (HL)
          opcode_o <= oram;
          alu_op_o <= alu_op_or;
        else
          -- xx "10111sss" | ORA {b,c,d,e,h,l,a} | A <- A OR R
          opcode_o    <= ora;
          alu_op_o    <= alu_op_or;
          alu_only_o  <= '1';
          regfile_sel_a_o <= REG_A;
          regfile_sel_b_o <= sss;
        end if;
      elsif instr_i(5 downto 3) = "111" then
        if instr_i(2 downto 0) = "110" then
          -- BE "10111110" | CMP   M       | A - (HL)
          opcode_o <= cmpm;
        else
          -- B8 "10111000" | CMP   B       | A - B
          -- B9 "10111001" | CMP   C       | A - C
          -- BA "10111010" | CMP   D       | A - D
          -- BB "10111011" | CMP   E       | A - E
          -- BC "10111100" | CMP   H       | A - H
          -- BD "10111101" | CMP   L       | A - L
          -- BF "10111111" | CMP   A       | A - A
          opcode_o <= cmp;
          regfile_sel_a_o <= REG_A;
          regfile_sel_b_o <= sss;
        end if;
      end if;
    ------------------------------------------------
    elsif instr_i(7 downto 6) = "11" then
      case instr_i(5 downto 0) is
        when "000000" =>   -- C0 "11000000" | RNZ | If NZ, RET
          opcode_o <= rnz;
        when "000001" =>   -- C1 "11000001" | POP B | B <- (SP+1); C <- (SP); SP <- SP + 2
          opcode_o <= pop;
          regfile_sel_a_o <= REG_B;
          regfile_sel_b_o <= REG_C;
        when "000010" =>   -- C2address "11000010" | JNZ   address | If NZ, PC <- address
          opcode_o <= jnz;
        when "000011" =>   -- C3address "11000011" | JMP   address | PC <- address
          opcode_o <= jmp;
        when "000100" =>   -- C4address "11000100" | CNZ   address | If NZ, CALL address
          opcode_o <= cnz;
        when "000101" =>   -- C5 "11000101" | PUSH  B       | (SP-2) <- C; (SP-1) <- B; SP <- SP - 2
          opcode_o <= push;
          regfile_sel_a_o <= REG_B;
          regfile_sel_b_o <= REG_C;
        when "000110" =>   -- C6byte "11000110" | ADI   byte    | A <- A + byte
          opcode_o <= adi;
          alu_op_o <= alu_op_add;
        when "000111" =>   -- C7 "11000111" | RST   0       | CALL 0
          opcode_o <= rst0;
        when "001000" =>   -- C8 "11001000" | RZ            | If Z, RET
          opcode_o <= rz;
        when "001001" =>   -- C9 "11001001" | RET           | PCl <- (SP);PCh <- (SP+1); SP <- (SP+2)
          opcode_o <= ret;
        when "001010" =>   -- CAaddress "11001010" | JZ    address | If Z, PC <- address
          opcode_o <= jz;
        when "001011" =>   -- cb "11001011" | ************  | UNDEFINED
          opcode_o <= und;
        when "001100" =>   -- CCaddress "11001100" | CZ    address | If Z, CALL address
          opcode_o <= cz;
        when "001101" =>   -- CDaddress "11001101" | CALL  address | <- PCl; SP <- SP - 2;PC <- address
          opcode_o <= call;
        when "001110" =>   -- CEbyte "11001110" | ACI   byte    | A <- A + byte + Carry
          opcode_o <= aci;
          alu_op_o <= alu_op_adc;
        when "001111" =>   -- CF "11001111" | RST   1       | CALL 8
          opcode_o <= rst1;
        when "010000" =>   -- D0 "11010000" | RNC           | If NC, RET
          opcode_o <= rnc;
        when "010001" =>   -- D1 "11010001" | POP   D       | D <- (SP+1); E <- (SP); SP <- SP + 2
          opcode_o <= pop;
          regfile_sel_a_o <= REG_D;
          regfile_sel_b_o <= REG_E;
        when "010010" =>   -- D2address "11010010" | JNC   address | If NC, PC <- address
          opcode_o <= jnc;
        when "010011" =>   -- d3 "11010011" | OUT port  | port(data) <- A
          opcode_o <= outport;
        when "010100" =>   -- D4address "11010100" | CNC   address | If NC, CALL address
          opcode_o <= cnc;
        when "010101" =>   -- D5 "11010101" | PUSH  D       | (SP-2) <- E; (SP-1) <- D; SP <- SP - 2
          opcode_o <= push;
          regfile_sel_a_o <= REG_D;
          regfile_sel_b_o <= REG_E;
        when "010110" =>   -- D6byte "11010110" | SUI   byte    | A <- A - byte
          opcode_o <= sui;
          alu_op_o <= alu_op_sub;
        when "010111" =>   -- D7 "11010111" | RST   2       | CALL 10H
          opcode_o <= rst2;
        when "011000" =>   -- D8 "11011000" | RC            | If C, RET
          opcode_o <= rc;
        when "011001" =>   -- d9 "11011001" | ************  | UNDEFINED
          opcode_o <= und;
        when "011010" =>   -- DAaddress "11011010" | JC    address | If C, PC <- address
          opcode_o <= jc;
        when "011011" =>   -- db "11011011" | IN port  | A <- port(data)
          opcode_o <= inport;
        when "011100" =>   -- DCaddress "11011100" | CC    address | If C, CALL address
          opcode_o <= cc;
        when "011101" =>   -- dd        | ******* "11011101" *****  | UNDEFINED
          opcode_o <= und;
        when "011110" =>   -- DEbyte "11011110" | SBI   byte    | A <- A - byte - Carry
          opcode_o <= sbi;
          alu_op_o <= alu_op_sbb;
        when "011111" =>   -- DF "11011111" | RST   3       | CALL 18H
          opcode_o <= rst3;
        when "100000" =>   -- E0 "11100000" | RPO           | If PO, RET
          opcode_o <= rpo;
        when "100001" =>   -- E1 "11100001" | POP   H       | H <- (SP+1); L <- (SP); SP <- SP + 2
          opcode_o <= pop;
          regfile_sel_a_o <= REG_H;
          regfile_sel_b_o <= REG_L;
        when "100010" =>   -- E2address "11100010" | JPO   address | If PO, PC <- address
          opcode_o <= jpo;
        when "100011" =>   -- E3 "11100011" | XTHL          | H <-> (SP+1); L <-> (SP)
          opcode_o <= xthl;
        when "100100" =>   -- E4address "11100100" | CPO   address | If PO, CALL address
          opcode_o <= cpo;
        when "100101" =>   -- E5 "11100101" | PUSH H | (SP-2) <- L; (SP-1) <- H; SP <- SP - 2 (SP-2) <- Flags;
          opcode_o <= push;
          regfile_sel_a_o <= REG_H;
          regfile_sel_b_o <= REG_L;
        when "100110" =>   -- E6byte "11100110" | ANI   byte    | A <- A AND byte
          opcode_o <= ani;
          alu_op_o <= alu_op_ani;
        when "100111" =>   -- E7 "11100111" | RST   4       | CALL 20H
          opcode_o <= rst4;
        when "101000" =>   -- E8 "11101000" | RPE           | If PE, RET
          opcode_o <= rpe;
        when "101001" =>   -- E9 "11101001" | PCHL          | PC <- HL
          opcode_o <= pchl;
        when "101010" =>   -- EAaddress "11101010" | JPE   address | If PE, PC <- address
          opcode_o <= jpe;
        when "101011" =>   -- EB        | XCHG "11101011" | HL <-> DE
          opcode_o <= xchg;
        when "101100" =>   -- ECaddress "11101100" | CPE   address | If PE, CALL address
          opcode_o <= cpe;
        when "101101" =>   -- ed "11101101" | ************  | UNDEFINED
          opcode_o <= und;
        when "101110" =>   -- EEbyte "11101110" | XRI   byte    | A <- A XOR byte
          opcode_o <= xri;
          alu_op_o <= alu_op_xor;
        when "101111" =>   -- EF "11101111" | RST   5       | CALL 28H
          opcode_o <= rst5;
        when "110000" =>   -- F0 "11110000" | RP            | If P, RET
          opcode_o <= rp;
        when "110001" =>   -- F1 "11110001" | POP   PSW     | A <- (SP+1); Flags <- (SP); SP <- SP + 2
          opcode_o <= poppsw;
        when "110010" =>   -- F2address "11110010" | JP    address | If P, PC <- address
          opcode_o <= jp;
        when "110011" =>   -- F3 "11110011" | DI            | IFF <- 0
          opcode_o <= di;
        when "110100" =>   -- F4address "11110100" | CP    address | If P, CALL address
          opcode_o <= cp;
        when "110101" =>   -- F5 "11110101" | PUSH  PSW     | (SP-1) <- A; SP <- SP - 2
          opcode_o <= pushpsw;
        when "110110" =>   -- F6byte "11110110" | ORI   byte    | A <- A OR byte
          opcode_o <= ori;
          alu_op_o <= alu_op_or;
        when "110111" =>   -- F7 "11110111" | RST   6       | CALL 30H
          opcode_o <= rst6;
        when "111000" =>   -- F8 "11111000" | RM            | If M, RET
          opcode_o <= rm;
        when "111001" =>   -- F9        | "11111001" SPHL          | SP <- HL
          opcode_o <= sphl;
        when "111010" =>   -- FAaddress "11111010" | JM    address | If M, PC <- address
          opcode_o <= jm;
        when "111011" =>   -- FB "11111011" | EI            | IFF <- 1
          opcode_o <= ei;
        when "111100" =>   -- FCaddress "11111100" | CM    address | If M, CALL address
          opcode_o <= cm;
        when "111101" =>   -- fd "11111101" | ************  | UNDEFINED
          opcode_o <= und;
        when "111110" =>   -- FEbyte "11111110" | CPI   byte    | A - byte
          opcode_o <= cpi;
          alu_op_o <= alu_op_cmp;
        when "111111" =>   -- FF "11111111" | RST   7       | CALL 38H
          opcode_o <= rst7;
        when others =>
          opcode_o <= nop;
      end case; -- "11"
    else
      opcode_o <= nop;
    end if;
  end process;
end rtl;
