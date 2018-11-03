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
    # add wave -radix hex sim:/cpu8080_testbench/clk
    # add wave -radix hex sim:/cpu8080_testbench/reset
#    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_regfile/reg_pc_o
#    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/curstate
#    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/nxtstate
#    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/inst_decode/opcode_o
#    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrlreg/inten_rg
#    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/int_i
#    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/inta_o
#    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/reg_data_o
#    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/port_i
#    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/port_rdy_i
#    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/port_sel_o
#    add wave -radix hex sim:/cpu8080_testbench/inst_timer/int_o
#    add wave -radix hex sim:/cpu8080_testbench/inst_timer/nnn_o
#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/sel_i
#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/nwr_i
#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/data_i
#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/rdy_o
#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/data_o
#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/shift_rg
#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/amount_rg
#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/rdy_rg
#    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_regfile/regfile
#    add wave -radix hex sim:/cpu8080_testbench/inst_mem/ram(192)
#    add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/reg_cmd_o
    #add wave -radix hex sim:/cpu8080_testbench/*
    #add wave -radix hex sim:/cpu8080_testbench/inst_mem/rom
    #add wave -radix hex sim:/cpu8080_testbench/inst_mem/ram
    #add wave -radix hex sim:/cpu8080_testbench/inst_mem/vram
    #add wave -radix hex sim:/cpu8080_testbench/inst_timer/*
    #add wave -radix hex sim:/cpu8080_testbench/inst_timer/inst_counter/*
    #add wave -radix hex sim:/cpu8080_testbench/inst_shifter/*
    #add wave -radix hex sim:/cpu8080_testbench/inst_inputs/*
    #add wave -radix hex sim:/cpu8080_testbench/inst_mem/*
    #add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/*
    #add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_regfile/*
    #add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_alu/*
    #add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrlreg/*
    #add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/*
    #add wave -radix hex sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/inst_decode/*
}

proc reset_cpu { } {
    force -freeze sim:/cpu8080_testbench/reset 1 0
    run [expr 50 * 1000 * 10]
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

if { 1 == 1 } {
set fileCount [expr 0]
when -label image_trace "$BASE/inst_cpu8080/inst_ctrl/inta_o'event and $BASE/inst_cpu8080/inst_ctrl/inta_o = 1" {
    set fp [open [format "image_%d.hex" $fileCount] w]
    for { set i 0 } { $i < (1024*7) } { incr i } {
        set str [examine -hex $BASE/inst_mem/vram($i)]
        puts $fp "$str"
    }
    close $fp
    incr fileCount
}
}

if { 0 == 1 } {
set str ""
set state_fp [open "state_trace_invaders_rtl.txt" w]
when -label state_trace "$BASE/clk'event and $BASE/clk=1 and $BASE/inst_cpu8080/inst_ctrl/curstate = fetch_1" {
    #-----------------------------------------------------------
    # State Tracing
    #
    set inti [expr [examine -decimal sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/int_i]]
    set inte [expr [examine -decimal sim:/cpu8080_testbench/inst_cpu8080/inst_ctrlreg/inten_rg]]
    set nnni [examine sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/nnn_i]

    set str ""

    if {$inti == 1 && $inte == 1} {
        append str "interrupt: $nnni"
        append str " " [examine $BASE/inst_cpu8080/inst_ctrlreg/alu_flags_tmp_rg]
        append str " " [format "%02x" [read_reg $REG_PCH]]
        append str " " [format "%02x" [read_reg $REG_PCL]]
        puts $state_fp "$str"
        flush $state_fp
    } else {
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
        flush $state_fp
    }
}
}

#-------set str ""
#-------set shifter_fp [open "shifter_trace_invaders_rtl.txt" w]
#-------when -label shifter_trace "sim:/cpu8080_testbench/inst_shifter/rdy_o'event and sim:/cpu8080_testbench/inst_shifter/rdy_o=1" {
#-------    set str ""
#-------    append str     [format "%02x" [expr [examine -decimal sim:/cpu8080_testbench/inst_shifter/sel_i] & 0xff]]
#-------    append str " " [format "%02x" [expr [examine -decimal sim:/cpu8080_testbench/inst_shifter/nwr_i] & 0xff]]
#-------    append str " " [format "%02x" [expr [examine -decimal sim:/cpu8080_testbench/inst_shifter/data_i] & 0xff]]
#-------    append str " " [format "%02x" [expr [examine -decimal sim:/cpu8080_testbench/inst_shifter/data_o] & 0xff]]
#-------    append str " " [format "%04x" [expr [examine -decimal sim:/cpu8080_testbench/inst_shifter/shift_rg] & 0xffff]]
#-------    append str " " [format "%02x" [expr [examine -decimal sim:/cpu8080_testbench/inst_shifter/amount_rg]& 0xff]]
#-------    puts $shifter_fp "$str"
#-------    flush $shifter_fp
#-------}

#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/sel_i
#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/nwr_i
#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/data_i
#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/rdy_o
#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/data_o
#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/shift_rg
#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/amount_rg
#    add wave -radix hex sim:/cpu8080_testbench/inst_shifter/rdy_rg

if { 0 == 1 } {
#-------set mem_fp [open "mem_trace_rtl.txt" w]
set mem_fp $state_fp
when -label mem_trace "$BASE/clk'event and $BASE/clk=1 and sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/munit_access_rg=1 and sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/munit_rdy_i=1" {
    set rdy [expr [examine -decimal sim:/cpu8080_testbench/inst_cpu8080/inst_ctrl/munit_rdy_i]]
    set wr [expr [examine -decimal sim:/cpu8080_testbench/inst_cpu8080/munit_wr]]
    set rd [expr [examine -decimal sim:/cpu8080_testbench/inst_cpu8080/munit_rd]]
    set nwr  [expr [examine -decimal sim:/cpu8080_testbench/inst_mem/nwr_i]]
    set adrx [expr [examine -decimal sim:/cpu8080_testbench/inst_mem/addr_i]]
    set adr  $adrx
    set din  [expr [examine -decimal sim:/cpu8080_testbench/inst_mem/data_i]]
    set ram ""
    set rdval [expr 0]
    set wrval [expr 0]
    set extra ""
    set cont [expr 1]

    if {$rdy == 1 && ($rd == 1 || $wr == 1)} {
        if {$adr >= 0 && $adr < (1024*8)} {
            set ram "sim:/cpu8080_testbench/inst_mem/rom";
            if {$adr <= 0x1a90} {
                set cont [expr 0]
            }
        } elseif {$adr >= (1024*8) && $adr < (1024*9)} {
            set ram "sim:/cpu8080_testbench/inst_mem/ram";
            set adr [expr $adr - (1024*8)]
        } elseif {$adr >= (1024*9) && $adr < (1024*16)} {
            set ram "sim:/cpu8080_testbench/inst_mem/vram";
            set adr [expr $adr - (1024*9)]
        } else {
            set ram "sim:/cpu8080_testbench/inst_mem/ram";
            set adr [expr $adr - (1024*16)]
            set extra " -- *** invalid address ***"
        }

        if {$cont == 1} {
            set rdval [expr [examine -decimal "$ram\($adr\)"] & 0xff]
            set wrval [expr $din & 0xff]
            set padx "--------------------------------------------"
            if {$nwr == 1} {
                puts $mem_fp [format "%s : read  %04x %02x%s" $padx $adrx $rdval $extra]
            } else {
                puts $mem_fp [format "%s : write %04x %02x%s" $padx $adrx $wrval $extra]
            }
            flush $mem_fp
        }
    }
}
}

#-----------------------------------------------------------
add_waves
reset_cpu

run 1000000

if {[batch_mode] == 1} {
    run 5000ms
    quit
}
