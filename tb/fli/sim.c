/*
  Copyright (c) 2018 Brendan Fennell <bfennell@skynet.ie>

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
*/

#include "mti.h"

#include <stdint.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include <stdbool.h>
#include <errno.h>

typedef struct {
    mtiSignalIdT clk_i;
    mtiSignalIdT sel_i;
    mtiSignalIdT nwr_i;
    mtiSignalIdT addr_i;
    mtiSignalIdT data_i;
    mtiSignalIdT ready_o;
    mtiSignalIdT data_o;
} invaders_t;

//-----------------------------------------------------------
//-- 0000-1fff : 8k ROM
//-- 2000-23ff : 1k RAM
//-- 2400-3fff : 7k Video RAM
//-- 4000- : RAM Mirror
//-----------------------------------------------------------
#define MEMORY_SIZE (1024*8+1024*1+1024*7)

static uint8_t memory[MEMORY_SIZE];

static void load_memory (uint8_t* mem, const int offset, const char* const filename)
{
    long fsize;
    FILE *f = fopen(filename, "rb");

    if (NULL != f) {
        fseek(f, 0, SEEK_END);
        fsize = ftell(f);
        fseek(f, 0, SEEK_SET);

        fsize = (fsize > MEMORY_SIZE) ? MEMORY_SIZE : fsize;

        fread(&mem[offset], fsize, 1, f);
        fclose(f);
    } else {
        fprintf (stderr, "Error: unable to open %s : %s\n", filename, strerror(errno));
        exit(-1);
    }
}

static void invaders (void* param)
{
    invaders_t* ip = (invaders_t*)param;

    bool clk  = (bool)mti_GetSignalValue(ip->clk_i);
    bool sel  = (bool)mti_GetSignalValue(ip->sel_i);
    bool nwr  = (bool)mti_GetSignalValue(ip->nwr_i);
    mtiUInt32T addr = (bool)mti_GetSignalValue(ip->addr_i);
    mtiUInt32T data = (bool)mti_GetSignalValue(ip->data_i);

    if (clk == 1 && sel == 1) {
        if (nwr == 1) { // read
            mti_ScheduleDriver (ip->data_o,  (mtiUInt32T)memory[addr], 0, MTI_INTERNAL);
            mti_ScheduleDriver (ip->ready_o, (mtiUInt32T)1,            0, MTI_INTERNAL);
        } else {       // write
            memory[addr] = (uint8_t)data;
            mti_ScheduleDriver (ip->data_o, (mtiUInt32T)memory[addr], 0, MTI_INTERNAL);
            mti_ScheduleDriver (ip->ready_o, (mtiUInt32T)1,           0, MTI_INTERNAL);
        }
    } else {
        mti_ScheduleDriver (ip->ready_o, (mtiUInt32T)0, 0, MTI_INTERNAL);
    }
}

/* extern "C" */
/* { */
    void invaders_init (mtiRegionIdT       region,     // location in the design
                        char              *parameters, // from vhdl world (not used)
                        mtiInterfaceListT *generics,   // from vhdl world (not used)
                        mtiInterfaceListT *ports)      // linked list of ports
    {
        load_memory (memory, 0x0000, "tb/invaders.rom");

        invaders_t* ip = (invaders_t*)mti_Malloc(sizeof(invaders_t));

        // map input signals from VHDL
        ip->clk_i  = mti_FindPort(ports, "clk_i");
        ip->sel_i  = mti_FindPort(ports, "sel_i");
        ip->nwr_i  = mti_FindPort(ports, "nwr_i");
        ip->addr_i = mti_FindPort(ports, "addr_i");
        ip->data_i = mti_FindPort(ports, "data_i");

        // map output signals to VHDL
        ip->data_o = mti_CreateDriver(mti_FindPort(ports, "data_o"));

        mtiProcessIdT id = mti_CreateProcess("invaders_p", invaders, ip);

        mti_Sensitize (id, ip->clk_i, MTI_EVENT);
    }

/* } */
