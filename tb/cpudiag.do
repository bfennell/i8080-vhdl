# Copyright (c) 2018 Brendan Fennell <bfennell@skynet.ie>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

vsim work.cpu8080_testbench

set BASE     sim:/cpu8080_testbench
set REG_FILE $BASE/inst_cpu8080/inst_regfile

set REG_B   [expr 0]
set REG_C   [expr 1]
set REG_D   [expr 2]
set REG_E   [expr 3]
set REG_H   [expr 4]
set REG_L   [expr 5]
set REG_M   [expr 6]
set REG_A   [expr 7]
set REG_W   [expr 8]
set REG_Z   [expr 9]
set REG_ACT [expr 10]
set REG_TMP [expr 11]
set REG_SPH [expr 12]
set REG_SPL [expr 13]
set REG_PCH [expr 14]
set REG_PCL [expr 15]

set OPCODE sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/inst_decode

proc add_waves { } {
    add wave -radix hex sim:/cpu8080_testbench/*
    add wave -radix hex sim:/cpu8080_testbench/inst_mem/*
    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/*
    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_regfile/*
    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_alu/*
    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrlreg/*
    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/*
    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/inst_decode/*
}

proc reset_cpu { } {
    force -freeze sim:/cpu8080_testbench/reset 1 0
    run 50000
    force -freeze sim:/cpu8080_testbench/reset 0 0
}

proc write_reg { idx value } {
    global REG_FILE
    force -deposit $REG_FILE/regfile($idx) 16#$value 0
}

proc read_reg { idx } {
    global REG_FILE
    return [expr [format "0x%s" [examine -hex $REG_FILE/regfile($idx)]]]
}

proc show_flags { } {
    global BASE
    examine $BASE/inst_cpu8080/inst_ctrlreg/alu_flags_tmp_rg
}

proc show_rom { addr } {
    global BASE
    set adr [expr $addr]
    set val [examine -hex $BASE/inst_mem/rom($adr)]
    echo [format "rom:%d %s" $adr $val]
}

proc show_ram { addr } {
    global BASE
    set adr [expr $addr]
    set val [examine -hex $BASE/inst_mem/ram($adr)]
    echo [format "ram:%d %s" $adr $val]
}

proc show_vram { addr } {
    global BASE
    set adr [expr $addr]
    set val [examine -hex $BASE/inst_mem/vram($adr)]
    echo [format "vram:%d %s" $adr $val]
}

proc write_ram { addr value } {
    global BASE
    force -deposit $BASE/inst_mem/ram($addr) 16#$value 0
}

proc read_mem { addr } {
    global BASE
    if {$addr >= 0 && $addr < (1024*8)} {
        set addr [expr $addr - (1024*0)]
        return [expr [format "0x%s" [examine -hex $BASE/inst_mem/rom($addr)]]]
    } elseif {$addr >= (1024*8) && $addr < (1024*9)} {
        set addr [expr $addr - (1024*8)]
        return [expr [format "0x%s" [examine -hex $BASE/inst_mem/ram($addr)]]]
    } elseif {$addr >= (1024*9) && $addr < (1024*16)} {
        set addr [expr $addr - (1024*9)]
        return [expr [format "0x%s" [examine -hex $BASE/inst_mem/vram($addr)]]]
    } else {
        puts "Error: invalid memory address $addr"
    }
}

proc show_regs { } {
    global REG_FILE
    global REG_B REG_C REG_D REG_E REG_H REG_L REG_M REG_A
    global REG_W REG_Z REG_ACT REG_TMP REG_SPH REG_SPL REG_PCH REG_PCL

    set b   [examine -hex $REG_FILE/regfile($REG_B)]
    set c   [examine -hex $REG_FILE/regfile($REG_C)]
    set d   [examine -hex $REG_FILE/regfile($REG_D)]
    set e   [examine -hex $REG_FILE/regfile($REG_E)]
    set h   [examine -hex $REG_FILE/regfile($REG_H)]
    set l   [examine -hex $REG_FILE/regfile($REG_L)]
    set m   [examine -hex $REG_FILE/regfile($REG_M)]
    set a   [examine -hex $REG_FILE/regfile($REG_A)]
    set w   [examine -hex $REG_FILE/regfile($REG_W)]
    set z   [examine -hex $REG_FILE/regfile($REG_Z)]
    set act [examine -hex $REG_FILE/regfile($REG_ACT)]
    set tmp [examine -hex $REG_FILE/regfile($REG_TMP)]
    set sph [examine -hex $REG_FILE/regfile($REG_SPH)]
    set spl [examine -hex $REG_FILE/regfile($REG_SPL)]
    set pch [examine -hex $REG_FILE/regfile($REG_PCH)]
    set pcl [examine -hex $REG_FILE/regfile($REG_PCL)]

    echo "---------------"
    echo [format "b   %s   c   %s" $b $c]
    echo [format "d   %s   e   %s" $d $e]
    echo [format "h   %s   l   %s" $h $l]
    echo [format "m   %s   a   %s" $m $a]
    echo [format "w   %s   z   %s" $w $z]
    echo [format "act %s   tmp %s" $act $tmp]
    echo [format "sph %s   spl %s" $sph $spl]
    echo [format "pch %s   pcl %s" $pch $pcl]
    echo "---------------"
}

#-----------------------------------------------------------
# Opcode Tracing
#
when -label pctrace "$OPCODE/opcode_o'event" {
    set str [examine $OPCODE/opcode_o]
    echo "$str"
}


array set cycleCount { }
set lastClk [expr 0]
set currClk [expr 0]

when -label clk_count "$BASE/clk'event and $BASE/clk=1" {
    incr currClk
}

set state_fp [open "state_trace_rtl.txt" w]
when -label state_trace "$BASE/clk'event and $BASE/clk=1 and $BASE/inst_cpu8080/inst_ctrl/curstate = fetch_1" {
    #-----------------------------------------------------------
    # State Tracing
    #
    set str ""
    append str [examine $BASE/inst_cpu8080/inst_ctrlreg/alu_flags_tmp_rg]
    append str " " [format "%02x" [read_reg $REG_B]]
    append str " " [format "%02x" [read_reg $REG_C]]
    append str " " [format "%02x" [read_reg $REG_D]]
    append str " " [format "%02x" [read_reg $REG_E]]
    append str " " [format "%02x" [read_reg $REG_H]]
    append str " " [format "%02x" [read_reg $REG_L]]
    append str " " [format "%02x" [read_reg $REG_A]]
    append str " " [format "%02x" [read_reg $REG_SPH]]
    append str " " [format "%02x" [read_reg $REG_SPL]]
    append str " " [format "%02x" [read_reg $REG_PCH]]
    append str " " [format "%02x" [read_reg $REG_PCL]]
    puts $state_fp "$str"

    #-----------------------------------------------------------
    # BDOS System Calls
    #
    if {[read_reg $REG_PCH] == 0 && [read_reg $REG_PCL] == 5} {
        set count [expr 0]
        set addr [expr (([read_reg $REG_D] << 8) | [read_reg $REG_E])]
        set char [format "%c" [read_mem $addr]]
        set str ""
        while {$char ne "$" && $count < 100} {
            append str "$char"
            set addr [expr $addr + 1]
            set count [expr $count + 1]
            set char [format "%c" [read_mem $addr]]
        }
        puts $state_fp "$str"
    }

    #-----------------------------------------------------------
    # Cycle Counting
    #
    set opcode [examine $OPCODE/opcode_o]
    if { $lastClk > 0 } {
        set diff [expr $currClk - $lastClk]
        if { "" eq [array names cycleCount -exact $opcode] } {
            set cycleCount($opcode,max) $diff
            set cycleCount($opcode,min) $diff
        } else {
            if { $diff > $cycleCount($opcode,max) } {
                set cycleCount($opcode,max) $diff
            }
            if { $diff < $cycleCount($opcode,min) } {
                set cycleCount($opcode,min) $diff
            }
        }
    }
    set lastClk $currClk
}


#-----------------------------------------------------------
add_waves
#reset_cpu
run 50000
#write_reg $REG_PCL 1
#quietly write_ram 4 00
#quietly write_ram 5 20
#quietly write_ram 6 bf
#quietly write_ram 7 fb
#write_reg $REG_B 0xaa
run [expr 10000 * 100000]
quietly show_regs
quietly show_ram 0x00
quietly show_ram 0x01
quietly show_ram 0x02
quietly show_ram 0x03
quietly show_ram 0x04
quietly show_ram 0x05
quietly show_ram 0x06
quietly show_ram 0x07
quietly show_ram 0x08
quietly show_ram 0x09
quietly show_ram 0x0a
quietly show_ram 0x0b

close $state_fp

#-----------------------------------------------------------
# Write out the cycle counts
#
set cycleCount_fp [open "cycle_counts_rtl.txt" w]
foreach opcode [lsort [array names cycleCount]] {
    puts $cycleCount_fp [format "%10s : %d" $opcode $cycleCount($opcode)]
}
close $cycleCount_fp

if {[batch_mode] == 1} {
    quit
}
