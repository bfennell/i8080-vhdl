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

set pc      top.cpu8080_testbench.inst_cpu8080.reg_pc
set cy      top.cpu8080_testbench.inst_cpu8080.inst_ctrlreg.alu_flags_tmp_rg.carry
set ac      top.cpu8080_testbench.inst_cpu8080.inst_ctrlreg.alu_flags_tmp_rg.aux_carry
set zero    top.cpu8080_testbench.inst_cpu8080.inst_ctrlreg.alu_flags_tmp_rg.zero
set parity  top.cpu8080_testbench.inst_cpu8080.inst_ctrlreg.alu_flags_tmp_rg.parity
set sign    top.cpu8080_testbench.inst_cpu8080.inst_ctrlreg.alu_flags_tmp_rg.sign
set state   top.cpu8080_testbench.inst_cpu8080.inst_ctrl.curstate
set reg_b   {top.cpu8080_testbench.inst_cpu8080.inst_regfile.regb_s}
set reg_c   {top.cpu8080_testbench.inst_cpu8080.inst_regfile.regc_s}
set reg_d   {top.cpu8080_testbench.inst_cpu8080.inst_regfile.regd_s}
set reg_e   {top.cpu8080_testbench.inst_cpu8080.inst_regfile.rege_s}
set reg_h   {top.cpu8080_testbench.inst_cpu8080.inst_regfile.regh_s}
set reg_l   {top.cpu8080_testbench.inst_cpu8080.inst_regfile.regl_s}
set reg_a   {top.cpu8080_testbench.inst_cpu8080.inst_regfile.rega_s}
set reg_sph {top.cpu8080_testbench.inst_cpu8080.inst_regfile.regsph_s}
set reg_spl {top.cpu8080_testbench.inst_cpu8080.inst_regfile.regspl_s}
set reg_pch {top.cpu8080_testbench.inst_cpu8080.inst_regfile.regpch_s}
set reg_pcl {top.cpu8080_testbench.inst_cpu8080.inst_regfile.regpcl_s}

set fp [open "state_trace_rtl.txt" w]
foreach {time state_val} [gtkwave::signalChangeList $state] {
    if {$state_val eq "0bfetch_2"} {
        lassign [gtkwave::signalChangeList $pc      -start_time $time -max 1] dont_care pc_val
        lassign [gtkwave::signalChangeList $cy      -start_time $time -max 1] dont_care cy_val
        lassign [gtkwave::signalChangeList $ac      -start_time $time -max 1] dont_care ac_val
        lassign [gtkwave::signalChangeList $zero    -start_time $time -max 1] dont_care zero_val
        lassign [gtkwave::signalChangeList $parity  -start_time $time -max 1] dont_care parity_val
        lassign [gtkwave::signalChangeList $sign    -start_time $time -max 1] dont_care sign_val x
        lassign [gtkwave::signalChangeList $reg_b   -start_time $time -max 1] dont_care reg_b_val
        lassign [gtkwave::signalChangeList $reg_c   -start_time $time -max 1] dont_care reg_c_val
        lassign [gtkwave::signalChangeList $reg_d   -start_time $time -max 1] dont_care reg_d_val
        lassign [gtkwave::signalChangeList $reg_e   -start_time $time -max 1] dont_care reg_e_val
        lassign [gtkwave::signalChangeList $reg_h   -start_time $time -max 1] dont_care reg_h_val
        lassign [gtkwave::signalChangeList $reg_l   -start_time $time -max 1] dont_care reg_l_val
        lassign [gtkwave::signalChangeList $reg_a   -start_time $time -max 1] dont_care reg_a_val
        lassign [gtkwave::signalChangeList $reg_sph -start_time $time -max 1] dont_care reg_sph_val
        lassign [gtkwave::signalChangeList $reg_spl -start_time $time -max 1] dont_care reg_spl_val
        lassign [gtkwave::signalChangeList $reg_pch -start_time $time -max 1] dont_care reg_pch_val
        lassign [gtkwave::signalChangeList $reg_pcl -start_time $time -max 1] dont_care reg_pcl_val

        set pc0 [format "%02x" [expr ($pc_val >> 0) & 0xff]]
        set pc1 [format "%02x" [expr ($pc_val >> 8) & 0xff]]
        set b   [format "%02x" $reg_b_val]
        set c   [format "%02x" $reg_c_val]
        set d   [format "%02x" $reg_d_val]
        set e   [format "%02x" $reg_e_val]
        set h   [format "%02x" $reg_h_val]
        set l   [format "%02x" $reg_l_val]
        set a   [format "%02x" $reg_a_val]
        set sph [format "%02x" $reg_sph_val]
        set spl [format "%02x" $reg_spl_val]
        set pch [format "%02x" $reg_pch_val]
        set pcl [format "%02x" $reg_pcl_val]
        puts $fp "{$cy_val $ac_val $zero_val $parity_val $sign_val} $b $c $d $e $h $l $a $sph $spl $pc1 $pc0"
    }
}
close $fp

gtkwave::/File/Quit
