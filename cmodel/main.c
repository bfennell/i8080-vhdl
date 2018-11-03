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

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include "i8080.h"

static int instr_handler (struct i8080_state* state)
{
    if (state->pc == 0x5) { /* BDOS entry point */
        switch (state->c) {
            case 0x2: { /* BDOS: C_WRITE */
                /* e = char to write */
                putchar (state->e);
                break;
            }
            case 0x9: { /* BDOS: C_WRITESTR */
                /* de = address of string */
                uint16_t de = (((uint8_t)state->d << 8 ) | ((uint8_t)state->e << 0));
                while (state->mem[de] != '$') {
                    putchar (state->mem[de]);
                    de++;
                }
                putchar('\n');
                break;
            }
            default: {
                fprintf (stderr, "Error: unknown BDOS function 0x%02x\n", state->c);
                exit (-1);
                break;
            }
        }

        state->pc++;
        return 0;
    }

    return -1;
}

int main ()
{
    uint8_t* ram = (uint8_t*)malloc (0x10000 /* 64kiB */);
    struct i8080_state* state = i8080_create (ram, 0x10000 /* 64kiB */);

    i8080_load_memory (state, 0x0000, "cpudiag_mod.bin");
    i8080_set_pc (state, 0x0000);
    i8080_set_instr_handler (state, instr_handler);

    while (!i8080_exec (state)) {
    }

    return 0;
}
