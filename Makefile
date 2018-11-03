#-------------------------------------------------------------------------------
#  Copyright (c) 2018 Brendan Fennell <bfennell@skynet.ie>
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in all
#  copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#  SOFTWARE.
#
#-------------------------------------------------------------------------------

.DEFAULT: all
.PHONY: all
all: cpudiag-msim

CPUDIAG_TEMP_DIR=tmp-cpudiag
CPUDIAG_TRACE_CMODEL=$(CPUDIAG_TEMP_DIR)/cmodel/state_trace_cmodel.txt
CPUDIAG_TRACE_MSIM=$(CPUDIAG_TEMP_DIR)/modelsim/state_trace_rtl.txt
CPUDIAG_TRACE_GHDL=$(CPUDIAG_TEMP_DIR)/ghdl/state_trace_rtl.txt

INVADERS_TEMP_DIR=tmp-invaders

#-------------------------------------------------------------------------------
# cmodel
#-------------------------------------------------------------------------------
cmodel/i8080:
	$(MAKE) -C cmodel all

$(CPUDIAG_TRACE_CMODEL): cmodel/i8080
	mkdir -p $(CPUDIAG_TEMP_DIR)/cmodel
	perl tools/hex2bin.pl -f tb/cpudiag_mod.hex -o $(CPUDIAG_TEMP_DIR)/cmodel/cpudiag_mod.bin
	cd $(CPUDIAG_TEMP_DIR)/cmodel && ../../cmodel/i8080 > ../../$@

#-------------------------------------------------------------------------------
# cpudiag-msim
#-------------------------------------------------------------------------------
cpudiag-msim: $(CPUDIAG_TRACE_MSIM) $(CPUDIAG_TRACE_CMODEL)
	diff $(CPUDIAG_TRACE_MSIM) $(CPUDIAG_TRACE_CMODEL)

$(CPUDIAG_TRACE_MSIM):
	mkdir -p $(CPUDIAG_TEMP_DIR)/modelsim
	ln -fs ../../tb/Makefile.cpudiag.msim $(CPUDIAG_TEMP_DIR)/modelsim/Makefile
	$(MAKE) -C $(CPUDIAG_TEMP_DIR)/modelsim cpudiag-msim

#-------------------------------------------------------------------------------
# cpudiag-ghdl
#-------------------------------------------------------------------------------
cpudiag-ghdl: $(CPUDIAG_TRACE_GHDL) $(CPUDIAG_TRACE_CMODEL)
	grep '{' $(CPUDIAG_TRACE_CMODEL) > $(CPUDIAG_TRACE_CMODEL).filtered
	diff $(CPUDIAG_TRACE_GHDL) $(CPUDIAG_TRACE_CMODEL).filtered

$(CPUDIAG_TRACE_GHDL):
	mkdir -p $(CPUDIAG_TEMP_DIR)/ghdl
	ln -fs ../../tb/Makefile.cpudiag.ghdl $(CPUDIAG_TEMP_DIR)/ghdl/Makefile
	$(MAKE) -C $(CPUDIAG_TEMP_DIR)/ghdl cpudiag-ghdl

#-------------------------------------------------------------------------------
# imageview
#-------------------------------------------------------------------------------
imageview/imageview:
	$(MAKE) -C imageview all

#-------------------------------------------------------------------------------
# invaders-msim
#-------------------------------------------------------------------------------
invaders-msim:
	mkdir -p $(INVADERS_TEMP_DIR)/modelsim
	ln -fs ../../tb/Makefile.invaders.msim $(INVADERS_TEMP_DIR)/modelsim/Makefile
	$(MAKE) -C $(INVADERS_TEMP_DIR)/modelsim invaders-msim

#-------------------------------------------------------------------------------
# invaders-msim-view
#-------------------------------------------------------------------------------
invaders-msim-view: imageview/imageview invaders-msim
	cd $(INVADERS_TEMP_DIR)/modelsim && imageview/imageview

#-------------------------------------------------------------------------------
# Clean
#-------------------------------------------------------------------------------
.PHONY: clean
clean:
	$(MAKE) -C cmodel clean
	$(MAKE) -C imageview clean
	rm -rf $(CPUDIAG_TEMP_DIR) $(INVADERS_TEMP_DIR)
