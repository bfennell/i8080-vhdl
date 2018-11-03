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
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include <stdbool.h>
#include <errno.h>

#include "i8080.h"

#if defined(TRACE_I8080)
#define i8080_TRACE(x) x; fprintf (state->log, "%s\n", s2str(state));
#else
#define i8080_TRACE(x)
#endif

struct i8080_state* i8080_create (uint8_t* ram, const int sizeb)
{
    struct i8080_state* state;

    state = malloc (sizeof(struct i8080_state));

    if (state != NULL)
        memset (state, 0, sizeof(struct i8080_state));
    state->mem = ram;
    state->mem_sizeb = sizeb;
    memset (state->mem, 0, sizeb);

    state->log = stdout;
    return state;
}

void i8080_destroy (struct i8080_state* state)
{
    free (state);
};

void i8080_set_pc (struct i8080_state* state, uint16_t pc)
{
    state->pc = pc;
}

void i8080_set_io_handler (struct i8080_state* state, i8080_io_fn_t io_func)
{
    state->io_handler = io_func;
}

void i8080_set_instr_handler (struct i8080_state* state, i8080_instr_fn_t instr_func)
{
    state->instr_func = instr_func;
}

static inline int i8080_parity (int8_t val)
{
    int i;
    int parity = 0;
    for (i = 0; i < 8; i++)
        parity += (val >> i);
    parity = ((parity & 1) == 0) ? 1 : 0;
    return parity;
}

static inline void i8080_update_flags (struct i8080_state* state, uint16_t result, int8_t dst, int8_t src)
{
    state->f.ac = ((dst ^ result ^ src) & 0x10) ? 1 : 0;
    state->f.s =  ((result & 0x80) == 0) ? 0 : 1;
    state->f.z =  ((result & 0xff) == 0) ? 1 : 0;
    state->f.p = i8080_parity (result & 0xff);
    state->f.cy =  ((result & 0x100) == 0) ? 0 : 1;
}

#if defined(TRACE_I8080)
static char pbuf[2048];

static char* s2str (struct i8080_state* state)
{
    sprintf (pbuf, "\t\t\t%02x %02x %02x %02x %02x %02x %02x %04x   %d,%d,%d,%d,%d (s,z,p,cy,ac) {0x%02x,0x%02x,0x%02x,0x%02x ...}",
             state->a&0xff,state->b&0xff,state->c&0xff,state->d&0xff,state->e&0xff,state->h&0xff,state->l&0xff,
             state->sp, state->f.s,state->f.z,state->f.p,state->f.cy,state->f.ac,
             state->mem[state->sp], state->mem[state->sp + 1], state->mem[state->sp + 2], state->mem[state->sp + 3]);
    return pbuf;
}
#endif
static inline const char* reg2str (struct i8080_state* state, int8_t reg)
{
    switch (reg) {
        case 0: return "b";
        case 1: return "c";
        case 2: return "d";
        case 3: return "e";
        case 4: return "h";
        case 5: return "l";
        case 7: return "a";
        default: {
            fprintf (state->log, "Error: invalid register %02x\n", reg);
            exit (-1);
        }
    }
}

static inline uint8_t* reg_ptr (struct i8080_state* state, uint8_t reg)
{
    switch (reg) {
        case 0: return &state->b;
        case 1: return &state->c;
        case 2: return &state->d;
        case 3: return &state->e;
        case 4: return &state->h;
        case 5: return &state->l;
        case 7: return &state->a;
        default: {
            fprintf (state->log, "Error: invalid register %d\n", reg);
            exit (-1);
        }
    }
}

static inline void movr2r (struct i8080_state* state)
{
    const uint8_t opcode = state->mem[state->pc];
    const uint8_t src_nr = (opcode & 0x7);
    const uint8_t dst_nr = ((opcode & 0x38) >> 3);
    uint8_t* src = reg_ptr (state, src_nr);
    uint8_t* dst = reg_ptr (state, dst_nr);

    i8080_TRACE(fprintf (state->log, "0x%04x: mov %s,%s", state->pc, reg2str(state, dst_nr), reg2str(state, src_nr)));
    *dst = *src;
    state->pc++;
}

static inline void movr2m (struct i8080_state* state, const uint16_t hl)
{
    const uint8_t opcode = state->mem[state->pc];
    const uint8_t src_nr = (opcode & 0x7);
    uint8_t* src = reg_ptr (state, src_nr);

    i8080_TRACE(fprintf (state->log, "0x%04x: mov m(0x%04x),%s", state->pc, hl, reg2str(state, src_nr)));

    state->mem[hl] = *src;
    state->pc++;
}

static inline void movm2r (struct i8080_state* state, const uint16_t hl)
{
    const uint8_t opcode = state->mem[state->pc];
    const uint8_t dst_nr = ((opcode & 0x38) >> 3);
    uint8_t* dst = reg_ptr (state, dst_nr);

    i8080_TRACE(fprintf (state->log, "0x%04x: mov %s,m(0x%04x)", state->pc, reg2str(state, dst_nr), hl));

    *dst = state->mem[hl];
    state->pc++;
}

static inline void mvi (struct i8080_state* state)
{
    const uint8_t opcode = state->mem[state->pc];
    const uint8_t dst_nr = ((opcode & 0x38) >> 3);
    const uint8_t byte = state->mem[state->pc+1];
    uint8_t* dst = reg_ptr (state, dst_nr);

    i8080_TRACE(fprintf (state->log, "0x%04x: mvi %s,0x%02x", state->pc, reg2str(state, dst_nr), byte));

    *dst = byte;
    state->pc += 2;
}

static inline void add (struct i8080_state* state)
{
    const uint8_t opcode = state->mem[state->pc];
    const uint8_t src_nr = (opcode & 0x7);
    uint8_t* src = reg_ptr (state, src_nr);
    uint16_t result;

    i8080_TRACE(fprintf (state->log, "0x%04x: add %s", state->pc, reg2str(state, src_nr)));
    result = state->a + *src;
    i8080_update_flags (state, result, state->a, *src);
    state->a = (result & 0xff);
    state->pc++;
}

static inline void adc (struct i8080_state* state)
{
    const uint8_t opcode = state->mem[state->pc];
    const uint8_t src_nr = (opcode & 0x7);
    uint8_t* src = reg_ptr (state, src_nr);
    uint16_t result;

    i8080_TRACE(fprintf (state->log, "0x%04x: adc %s", state->pc, reg2str(state, src_nr)));
    result = state->a + *src + state->f.cy;
    i8080_update_flags (state, result, state->a, (*src+state->f.cy));
    state->a = (result & 0xff);
    state->pc++;
}

static inline void sub (struct i8080_state* state)
{
    const uint8_t opcode = state->mem[state->pc];
    const uint8_t src_nr = (opcode & 0x7);
    uint8_t* src = reg_ptr (state, src_nr);
    uint16_t result;

    i8080_TRACE(fprintf (state->log, "0x%04x: sub %s", state->pc, reg2str(state, src_nr)));
    result = state->a - *src;
    i8080_update_flags (state, result, state->a, *src);
    state->a = (result & 0xff);
    state->pc++;
}

static inline void cmp (struct i8080_state* state)
{
    const uint8_t opcode = state->mem[state->pc];
    const uint8_t src_nr = (opcode & 0x7);
    uint8_t* src = reg_ptr (state, src_nr);
    uint16_t result;

    i8080_TRACE(fprintf (state->log, "0x%04x: cmp %s", state->pc, reg2str(state, src_nr)));
    result = state->a - *src;
    i8080_update_flags (state, result, state->a, *src);
    state->pc++;
}

static inline void sbb (struct i8080_state* state)
{
    const uint8_t opcode = state->mem[state->pc];
    const uint8_t src_nr = (opcode & 0x7);
    uint8_t* src = reg_ptr (state, src_nr);
    uint16_t result;

    i8080_TRACE(fprintf (state->log, "0x%04x: sbb %s", state->pc, reg2str(state, src_nr)));
    result = state->a - *src - state->f.cy;
    i8080_update_flags (state, result, state->a, (*src + state->f.cy));
    state->a = (result & 0xff);
    state->pc++;
}

static inline void inr (struct i8080_state* state)
{
    const uint8_t opcode = state->mem[state->pc];
    const uint8_t dst_nr = ((opcode & 0x38) >> 3);
    uint8_t* dst = reg_ptr (state, dst_nr);
    uint8_t cy = state->f.cy;
    uint16_t result;

    i8080_TRACE(fprintf (state->log, "0x%04x: inr %s", state->pc, reg2str(state, dst_nr)));
    result = *dst + 1;
    i8080_update_flags (state, result, *dst, 1);
    state->f.cy = cy;
    *dst = (result & 0xff);
    state->pc++;
}

static inline void dcr (struct i8080_state* state)
{
    const uint8_t opcode = state->mem[state->pc];
    const uint8_t dst_nr = ((opcode & 0x38) >> 3);
    uint8_t* dst = reg_ptr (state, dst_nr);
    uint8_t cy = state->f.cy;
    uint16_t result;

    i8080_TRACE(fprintf (state->log, "0x%04x: dcr %s", state->pc, reg2str(state, dst_nr)));
    result = *dst - 1;
    i8080_update_flags (state, result, *dst, 1);
    state->f.cy = cy;
    *dst = (result & 0xff);
    state->pc++;
}

static inline void call (struct i8080_state* state, uint16_t address)
{
    state->mem[state->sp - 1] = (((state->pc + 3) & 0xff00 ) >> 8);
    state->mem[state->sp - 2] = (((state->pc + 3) & 0x00ff ) >> 0);
    state->sp -= 2;
    state->pc = address;
}

static inline void rst (struct i8080_state* state)
{
    uint8_t nnn = ((state->mem[state->pc] >> 3) & 0x7);

    i8080_TRACE(fprintf (state->log, "0x%04x: rst %d", state->pc, nnn));

    state->mem[state->sp - 1] = (((state->pc + 1) & 0xff00 ) >> 8);
    state->mem[state->sp - 2] = (((state->pc + 1) & 0x00ff ) >> 0);
    state->sp -= 2;
    state->pc = (nnn * 8);
}

static inline void ret (struct i8080_state* state)
{
    state->pc = ((state->mem[state->sp + 1] << 8) | state->mem[state->sp]);
    state->sp += 2;
}

static inline void ana (struct i8080_state* state)
{
    const uint8_t opcode = state->mem[state->pc];
    const uint8_t src_nr = (opcode & 0x7);
    uint8_t* src = reg_ptr (state, src_nr);
    uint16_t result;

    i8080_TRACE(fprintf (state->log, "0x%04x: ana %s", state->pc, reg2str(state, src_nr)));
    result = state->a & *src;
    i8080_update_flags (state, result, state->a, *src);
    state->a = (result & 0xff);
    state->f.cy = 0;
    state->pc++;
}

static inline void xra (struct i8080_state* state)
{
    const uint8_t opcode = state->mem[state->pc];
    const uint8_t src_nr = (opcode & 0x7);
    uint8_t* src = reg_ptr (state, src_nr);
    uint16_t result;

    i8080_TRACE(fprintf (state->log, "0x%04x: xra %s", state->pc, reg2str(state, src_nr)));
    result = state->a ^ *src;
    i8080_update_flags (state, result, state->a, *src);
    state->a = (result & 0xff);
    state->f.cy = 0;
    state->f.ac = 0;
    state->pc++;
}

static inline void ora (struct i8080_state* state)
{
    const uint8_t opcode = state->mem[state->pc];
    const uint8_t src_nr = (opcode & 0x7);
    uint8_t* src = reg_ptr (state, src_nr);
    uint16_t result;

    i8080_TRACE(fprintf (state->log, "0x%04x: ora %s", state->pc, reg2str(state, src_nr)));
    result = state->a | *src;
    i8080_update_flags (state, result, state->a, *src);
    state->a = (result & 0xff);
    state->f.cy = 0;
    state->f.ac = 0;
    state->pc++;
}

#define TRACE_I8080_STATE
#if defined(TRACE_I8080_STATE)
static void state_trace (struct i8080_state* state)
{
    printf ("{%d %d %d %d %d} ", state->f.cy,state->f.ac,state->f.z,state->f.p,state->f.s);
    printf ("%02x %02x %02x %02x %02x %02x ",state->b,state->c,state->d,state->e,state->h,state->l);
    printf ("%02x ",state->a);
    printf ("%02x %02x ",(state->sp >> 8)&0xff, (state->sp >> 0)&0xff);
    printf ("%02x %02x\n",(state->pc >> 8)&0xff, (state->pc >> 0)&0xff);
}
#endif

int i8080_exec (struct i8080_state* state)
{
    uint16_t bc = ((uint8_t)state->b << 8 | (uint8_t)state->c);
    uint16_t de = ((uint8_t)state->d << 8 | (uint8_t)state->e);
    uint16_t hl = ((uint8_t)state->h << 8 | (uint8_t)state->l);

#if defined(TRACE_I8080_STATE)
    state_trace (state);
#endif

    if (state->pc >= (state->mem_sizeb - 1))
        return -1;

    /* check for special handling of this PC value */
    if (state->instr_func && !state->instr_func (state))
        return 0;

    switch (state->mem[state->pc]) {
        case 0x7f: case 0x78: case 0x79:
        case 0x7a: case 0x7b: case 0x7c:
        case 0x7d: {
            movr2r (state);
            break;
        }
        case 0x7e: movm2r (state, hl); break;
        case 0x0a: {
            i8080_TRACE(fprintf (state->log, "0x%04x: ldax b(%04x)", state->pc, bc));
            state->a = state->mem[bc];
            state->pc++;
            break;
        }
        case 0x07: {
            uint8_t b7 = state->a >> 7;
            i8080_TRACE(fprintf (state->log, "0x%04x: rlc", state->pc));
            state->a <<= 1;
            state->a |= b7;
            state->f.cy = b7;
            state->pc++;
            break;
        }
        case 0x0f: {
            uint8_t b0 = state->a & 1;
            i8080_TRACE(fprintf (state->log, "0x%04x: rrc", state->pc));
            state->a >>= 1;
            state->a |= (b0 << 7);
            state->f.cy = b0;
            state->pc++;
            break;
        }
        case 0x17: {
            uint8_t b7 = state->a >> 7;
            i8080_TRACE(fprintf (state->log, "0x%04x: ral", state->pc));
            state->a <<= 1;
            state->a |= state->f.cy;
            state->f.cy = b7;
            state->pc++;
            break;
        }
        case 0x1f: {
            uint8_t b0 = state->a & 1;
            i8080_TRACE(fprintf (state->log, "0x%04x: rar", state->pc));
            state->a >>= 1;
            state->a |= (state->f.cy << 7);
            state->f.cy = b0;
            state->pc++;
            break;
        }
        case 0x1a: {
            i8080_TRACE(fprintf (state->log, "0x%04x: ldax d(%04x)", state->pc, de));
            state->a = state->mem[de];
            state->pc++;
            break;
        }
        case 0x3a: {
            uint16_t word = (state->mem[state->pc+1] | state->mem[state->pc+2]<<8);
            i8080_TRACE(fprintf (state->log, "0x%04x: lda 0x%04x", state->pc, word));
            state->a = state->mem[word];
            state->pc += 3;
            break;
        }
        case 0x47: case 0x40: case 0x41:
        case 0x42: case 0x43: case 0x44:
        case 0x45: {
            movr2r (state);
            break;
        }
        case 0x46: movm2r (state, hl); break;
        case 0x4f: case 0x48: case 0x49:
        case 0x4a: case 0x4b: case 0x4c:
        case 0x4d: {
            movr2r (state);
            break;
        }
        case 0x4e: movm2r (state, hl); break;
        case 0x57: case 0x50: case 0x51:
        case 0x52: case 0x53: case 0x54:
        case 0x55: {
            movr2r (state);
            break;
        }
        case 0x56: movm2r (state, hl); break;
        case 0x5f: case 0x58: case 0x59:
        case 0x5a: case 0x5b: case 0x5c:
        case 0x5d: {
            movr2r (state);
            break;
        }
        case 0x5e: movm2r (state, hl); break;
        case 0x67: case 0x60: case 0x61:
        case 0x62: case 0x63: case 0x64:
        case 0x65: {
            movr2r (state);
            break;
        }
        case 0x66: movm2r (state, hl); break;
        case 0x6f: case 0x68: case 0x69:
        case 0x6a: case 0x6b: case 0x6c:
        case 0x6d: {
            movr2r (state);
            break;
        }
        case 0x6e: movm2r (state, hl); break;
        case 0x77: case 0x70: case 0x71:
        case 0x72: case 0x73: case 0x74:
        case 0x75: {
            movr2m (state, hl);
            break;
        }
        case 0x3e: case 0x06: case 0x0e:
        case 0x16: case 0x1e: case 0x26:
        case 0x2e: {
            mvi (state);
            break;
        }
        case 0x36: {
            uint8_t byte = state->mem[state->pc+1];
            i8080_TRACE(fprintf (state->log, "0x%04x: mvi m,0x%02x", state->pc, byte));
            state->mem[hl] = byte;
            state->pc += 2;
            break;
        }
        case 0x02: {
            i8080_TRACE(fprintf (state->log, "0x%04x: stax b", state->pc));
            state->mem[bc] = state->a;
            state->pc++;
            break;
        }
        case 0x12: {
            i8080_TRACE(fprintf (state->log, "0x%04x: stax d", state->pc));
            state->mem[de] = state->a;
            state->pc++;
            break;
        }
        case 0x32: {
            uint16_t word = (state->mem[state->pc+1] | state->mem[state->pc+2]<<8);
            i8080_TRACE(fprintf (state->log, "0x%04x: sta 0x%04x", state->pc, word));
            state->mem[word] = state->a;
            state->pc += 3;
            break;
        }
        case 0x01: {
            uint16_t word = (state->mem[state->pc+1] | state->mem[state->pc+2]<<8);
            i8080_TRACE(fprintf (state->log, "0x%04x: lxi b,0x%04x", state->pc, word));
            state->b = (word >> 8);
            state->c = (word & 0xff);
            state->pc += 3;
            break;
        }
        case 0x11: {
            uint16_t word = (state->mem[state->pc+1] | state->mem[state->pc+2]<<8);
            i8080_TRACE(fprintf (state->log, "0x%04x: lxi d,0x%04x", state->pc, word));
            state->d = (word >> 8);
            state->e = (word & 0xff);
            state->pc += 3;
            break;
        }
        case 0x21: {
            uint16_t word = (state->mem[state->pc+1] | state->mem[state->pc+2]<<8);
            i8080_TRACE(fprintf (state->log, "0x%04x: lxi h,0x%04x", state->pc, word));
            state->h = (word >> 8);
            state->l = (word & 0xff);
            state->pc += 3;
            break;
        }
        case 0x31: {
            uint16_t word = (state->mem[state->pc+1] | state->mem[state->pc+2]<<8);
            i8080_TRACE(fprintf (state->log, "0x%04x: lxi sp,0x%04x", state->pc, word));
            state->sp = word;
            state->pc += 3;
            break;
        }
        case 0x2a: {
            uint16_t addr = (state->mem[state->pc+1] | state->mem[state->pc+2]<<8);
            i8080_TRACE(fprintf (state->log, "0x%04x: lhld 0x%04x", state->pc, addr));
            state->l = state->mem[addr+0];
            state->h = state->mem[addr+1];
            state->pc += 3;
            break;
        }
        case 0x22: {
            uint16_t addr = (state->mem[state->pc+1] | state->mem[state->pc+2]<<8);
            i8080_TRACE(fprintf (state->log, "0x%04x: shld 0x%04x", state->pc, addr));
            state->mem[addr+0] = state->l;
            state->mem[addr+1] = state->h;
            state->pc += 3;
            break;
        }
        case 0xf9: {
            i8080_TRACE(fprintf (state->log, "0x%04x: sphl ", state->pc));
            state->sp = hl;
            state->pc++;
            break;
        }
        case 0xeb: {
            i8080_TRACE(fprintf (state->log, "0x%04x: xchg ", state->pc));
            state->h = ((de >> 8) & 0xff);
            state->l = (de & 0xff);
            state->d = ((hl >> 8) & 0xff);
            state->e = (hl & 0xff);
            state->pc++;
            break;
        }
        case 0xe3: {
            i8080_TRACE(fprintf (state->log, "0x%04x: xthl ", state->pc));
            state->h = state->mem[state->sp+1];
            state->l = state->mem[state->sp];
            state->mem[state->sp+1] = (hl >> 8);
            state->mem[state->sp] = (hl & 0xff);
            state->pc++;
            break;
        }
        case 0x87: case 0x80: case 0x81:
        case 0x82: case 0x83: case 0x84:
        case 0x85: {
            add (state);
            break;
        }
        case 0x86: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: add m", state->pc));
            result = state->a + state->mem[hl];
            i8080_update_flags (state, result, state->a, state->mem[hl]);
            state->a = result & 0xff;
            state->pc++;
            break;
        }
        case 0xc6: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: adi 0x%02x", state->pc, state->mem[state->pc+1]));
            result = state->a + state->mem[state->pc+1];
            i8080_update_flags (state, result, state->a, state->mem[state->pc+1]);
            state->a = result & 0xff;
            state->pc += 2;
            break;
        }
        case 0x8f: case 0x88: case 0x89:
        case 0x8a: case 0x8b: case 0x8c:
        case 0x8d: {
            adc (state);
            break;
        }
        case 0x8e: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: adc m", state->pc));
            result = state->a + state->mem[hl] + state->f.cy;
            i8080_update_flags (state, result, state->a, (state->mem[hl] + state->f.cy));
            state->a = result & 0xff;
            state->pc++;
            break;
        }
        case 0xce: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: aci 0x%02x", state->pc, state->mem[state->pc+1]));
            result = state->a + state->mem[state->pc+1] + state->f.cy;
            i8080_update_flags (state, result, state->a, (state->mem[state->pc+1] + state->f.cy));
            state->a = result & 0xff;
            state->pc += 2;
            break;
        }
        case 0x97: case 0x90: case 0x91:
        case 0x92: case 0x93: case 0x94:
        case 0x95: {
            sub (state);
            break;
        }
        case 0x96: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: sub m", state->pc));
            result = state->a - state->mem[hl];
            i8080_update_flags (state, result, state->a, state->mem[hl]);
            state->a = result & 0xff;
            state->pc++;
            break;
        }
        case 0xd6: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: sui 0x%02x", state->pc, state->mem[state->pc+1]));
            result = state->a - state->mem[state->pc+1];
            i8080_update_flags (state, result, state->a, state->mem[state->pc+1]);
            state->a = result & 0xff;
            state->pc += 2;
            break;
        }
        case 0x9f: case 0x98: case 0x99:
        case 0x9a: case 0x9b: case 0x9c:
        case 0x9d: {
            sbb (state);
            break;
        }
        case 0x9e: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: sbb m", state->pc));
            result = state->a - state->mem[hl] - state->f.cy;
            i8080_update_flags (state, result, state->a, (state->mem[hl] - state->f.cy));
            state->a = result & 0xff;
            state->pc++;
            break;
        }
        case 0xde: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: sbi 0x%02x", state->pc, state->mem[state->pc+1]));
            result = state->a - state->mem[state->pc+1] - state->f.cy;
            i8080_update_flags (state, result, state->a, (state->mem[state->pc+1] - state->f.cy));
            state->a = result & 0xff;
            state->pc += 2;
            break;
        }
        case 0x09: {
            int32_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: dad b", state->pc));
            result = hl + bc;
            state->f.cy = ((result & 0x10000) == 0) ? 0 : 1;
            state->h = ((result & 0xff00) >> 8);
            state->l = ((result & 0x00ff) >> 0);
            state->pc++;
            break;
        }
        case 0x19: {
            int32_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: dad d", state->pc));
            result = hl + de;
            state->f.cy = ((result & 0x10000) == 0) ? 0 : 1;
            state->h = ((result & 0xff00) >> 8);
            state->l = ((result & 0x00ff) >> 0);
            state->pc++;
            break;
        }
        case 0x29: {
            int32_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: dad h", state->pc));
            result = hl + hl;
            state->f.cy = ((result & 0x10000) == 0) ? 0 : 1;
            state->h = ((result & 0xff00) >> 8);
            state->l = ((result & 0x00ff) >> 0);
            state->pc++;
            break;
        }
        case 0x39: {
            int32_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: dad sp", state->pc));
            result = hl + state->sp;
            state->f.cy = ((result & 0x10000) == 0) ? 0 : 1;
            state->h = ((result & 0xff00) >> 8);
            state->l = ((result & 0x00ff) >> 0);
            state->pc++;
            break;
        }
        case 0xf3: {
            i8080_TRACE(fprintf (state->log, "0x%04x: di ", state->pc));
            state->i = 0;
            state->pc++;
            break;
        }
        case 0xfb: {
            i8080_TRACE(fprintf (state->log, "0x%04x: ei ", state->pc));
            state->i = 1;
            state->pc++;
            break;
        }
        case 0x00: {
            i8080_TRACE(fprintf (state->log, "0x%04x: nop ", state->pc));
            state->pc++;
            break;
        }
        case 0x76: {
            i8080_TRACE(fprintf (state->log, "0x%04x: hlt ", state->pc));
#if !defined(TRACE_I8080_STATE)
            printf ("HLT\n");
#endif
            exit(0);
            state->pc++;
            break;
        }
        case 0x3c: case 0x04: case 0x0c:
        case 0x14: case 0x1c: case 0x24:
        case 0x2c: {
            inr (state);
            break;
        }
        case 0x34: {
            uint16_t result;
            uint8_t cy = state->f.cy;
            i8080_TRACE(fprintf (state->log, "0x%04x: inr m", state->pc));
            result = state->mem[hl] + 1;
            i8080_update_flags (state, result, state->mem[hl], 1);
            state->f.cy = cy;
            state->mem[hl] = result & 0xff;
            state->pc++;
            break;
        }
        case 0x3d: case 0x05: case 0x0d:
        case 0x15: case 0x1d: case 0x25:
        case 0x2d: {
            dcr (state);
            break;
        }
        case 0x35: {
            uint16_t result;
            uint8_t cy = state->f.cy;
            i8080_TRACE(fprintf (state->log, "0x%04x: dcr m", state->pc));
            result = state->mem[hl] - 1;
            i8080_update_flags (state, result, state->mem[hl], 1);
            state->f.cy = cy;
            state->mem[hl] = result & 0xff;
            state->pc++;
            break;
        }
        case 0x03: {
            i8080_TRACE(fprintf (state->log, "0x%04x: inx b", state->pc));
            bc++;
            state->b = ((bc & 0xff00) >> 8);
            state->c = ((bc & 0x00ff) >> 0);
            state->pc++;
            break;
        }
        case 0x13: {
            i8080_TRACE(fprintf (state->log, "0x%04x: inx d", state->pc));
            de++;
            state->d = ((de & 0xff00) >> 8);
            state->e = ((de & 0x00ff) >> 0);
            state->pc++;
            break;
        }
        case 0x23: {
            i8080_TRACE(fprintf (state->log, "0x%04x: inx h", state->pc));
            hl++;
            state->h = ((hl & 0xff00) >> 8);
            state->l = ((hl & 0x00ff) >> 0);
            state->pc++;
            break;
        }
        case 0x33: {
            i8080_TRACE(fprintf (state->log, "0x%04x: inx sp", state->pc));
            state->sp++;
            state->pc++;
            break;
        }
        case 0x0b: {
            i8080_TRACE(fprintf (state->log, "0x%04x: dcx b", state->pc));
            bc--;
            state->b = ((bc & 0xff00) >> 8);
            state->c = ((bc & 0x00ff) >> 0);
            state->pc++;
            break;
        }
        case 0x1b: {
            i8080_TRACE(fprintf (state->log, "0x%04x: dcx d", state->pc));
            de--;
            state->d = ((de & 0xff00) >> 8);
            state->e = ((de & 0x00ff) >> 0);
            state->pc++;
            break;
        }
        case 0x27: {
            uint8_t lnibble;
            uint8_t hnibble;
            int cy = state->f.cy;
            int ac;

            i8080_TRACE(fprintf (state->log, "0x%04x: daa", state->pc));

            lnibble = (state->a & 0xf);
            if ((lnibble > 9) || state->f.ac) {
                uint16_t result = (state->a + 6) & 0xff;
                i8080_update_flags (state, result, state->a, 6);
                state->f.ac = 1;
                state->a = (result & 0xff);
            } else {
                state->f.ac = 0;
            }
            ac = state->f.ac;

            hnibble = ((state->a >> 4) & 0xf);
            if ((hnibble > 9) || cy) {
                uint16_t result = (state->a + 0x60);
                i8080_update_flags (state, result, state->a, 0x60);
                state->f.cy = 1;
                state->a = (result & 0xff);
            } else {
                state->f.cy = 0;
            }
            state->f.ac = ac;

            state->pc++;
            break;
        }
        case 0x2b: {
            i8080_TRACE(fprintf (state->log, "0x%04x: dcx h", state->pc));
            hl--;
            state->h = ((hl & 0xff00) >> 8);
            state->l = ((hl & 0x00ff) >> 0);
            state->pc++;
            break;
        }
        case 0x3b: {
            i8080_TRACE(fprintf (state->log, "0x%04x: dcx sp", state->pc));
            state->sp--;
            state->pc++;
            break;
        }
        case 0x2f: {
            i8080_TRACE(fprintf (state->log, "0x%04x: cma ", state->pc));
            state->a = ~state->a;
            state->pc++;
            break;
        }
        case 0x37: {
            i8080_TRACE(fprintf (state->log, "0x%04x: stc ", state->pc));
            state->f.cy = 1;
            state->pc++;
            break;
        }
        case 0x3f: {
            i8080_TRACE(fprintf (state->log, "0x%04x: cmc ", state->pc));
            state->f.cy = (~state->f.cy & 1);
            state->pc++;
            break;
        }
        case 0xa7: case 0xa0: case 0xa1:
        case 0xa2: case 0xa3: case 0xa4:
        case 0xa5: {
            ana (state);
            break;
        }
        case 0xa6: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: ana m(0x%04x)", state->pc, hl));
            result = state->a & state->mem[hl];
            i8080_update_flags (state, result, state->a, state->mem[hl]);
            state->a = (result & 0xff);
            state->f.cy = 0;
            state->pc++;
            break;
        }
        case 0xe6: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: ani 0x%02x", state->pc, state->mem[state->pc+1]));
            result = state->a & state->mem[state->pc+1];
            i8080_update_flags (state, result, state->a, state->mem[state->pc+1]);
            state->a = (result & 0xff);
            state->f.cy = 0;
            state->f.ac = 0;
            state->pc += 2;
            break;
        }
        case 0xaf: case 0xa8: case 0xa9:
        case 0xaa: case 0xab: case 0xac:
        case 0xad: {
            xra (state);
            break;
        }
        case 0xae: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: xra m(0x%04x)", state->pc, hl));
            result = state->a ^ state->mem[hl];
            i8080_update_flags (state, result, state->a, state->mem[hl]);
            state->a = (result & 0xff);
            state->f.cy = 0;
            state->f.ac = 0;
            state->pc++;
            break;
        }
        case 0xee: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: xri 0x%02x", state->pc, state->mem[state->pc+1]));
            result = state->a ^ state->mem[state->pc+1];
            i8080_update_flags (state, result, state->a, state->mem[state->pc+1]);
            state->a = (result & 0xff);
            state->f.cy = 0;
            state->f.ac = 0;
            state->pc += 2;
            break;
        }
        case 0xb7: case 0xb0: case 0xb1:
        case 0xb2: case 0xb3: case 0xb4:
        case 0xb5: {
            ora (state);
            break;
        }
        case 0xb6: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: ora m(0x%04x)", state->pc, hl));
            result = state->a | state->mem[hl];
            i8080_update_flags (state, result, state->a, state->mem[hl]);
            state->a = (result & 0xff);
            state->f.cy = 0;
            state->f.ac = 0;
            state->pc++;
            break;
        }
        case 0xf6: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: ori 0x%02x", state->pc, state->mem[state->pc+1]));
            result = state->a | state->mem[state->pc+1];
            i8080_update_flags (state, result, state->a, state->mem[state->pc+1]);
            state->a = (result & 0xff);
            state->f.cy = 0;
            state->f.ac = 0;
            state->pc += 2;
            break;
        }
        case 0xbf: case 0xb8: case 0xb9:
        case 0xba: case 0xbb: case 0xbc:
        case 0xbd: {
            cmp (state);
            break;
        }
        case 0xbe: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: cmp m(%04x)", state->pc, hl));
            result = state->a - state->mem[hl];
            i8080_update_flags (state, result, state->a, state->mem[hl]);
            state->pc++;
            break;
        }
        case 0xfe: {
            uint16_t result;
            i8080_TRACE(fprintf (state->log, "0x%04x: cpi 0x%02x", state->pc, state->mem[state->pc+1]));
            result = state->a - state->mem[state->pc+1];
            i8080_update_flags (state, result, state->a, state->mem[state->pc+1]);
            state->pc += 2;
            break;
        }
        case 0xc3: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: jmp 0x%04x", state->pc, address));
            state->pc = address;
            break;
        }
        case 0xc2: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: jnz 0x%04x", state->pc, address));
            if (state->f.z == 0)
                state->pc = address;
            else
                state->pc += 3;
            break;
        }
        case 0xca: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: jz 0x%04x", state->pc, address));
            if (state->f.z == 1)
                state->pc = address;
            else
                state->pc += 3;
            break;
        }
        case 0xd2: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: jnc 0x%04x", state->pc, address));
            if (state->f.cy == 0)
                state->pc = address;
            else
                state->pc += 3;
            break;
        }
        case 0xda: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: jc 0x%04x", state->pc, address));
            if (state->f.cy == 1)
                state->pc = address;
            else
                state->pc += 3;
            break;
        }
        case 0xe2: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: jpo 0x%04x", state->pc, address));
            if (state->f.p == 0)
                state->pc = address;
            else
                state->pc += 3;
            break;
        }
        case 0xea: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: jpe 0x%04x", state->pc, address));
            if (state->f.p == 1)
                state->pc = address;
            else
                state->pc += 3;
            break;
        }
        case 0xf2: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: jp 0x%04x", state->pc, address));
            if (state->f.s == 0)
                state->pc = address;
            else
                state->pc += 3;
            break;
        }
        case 0xfa: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: jm 0x%04x", state->pc, address));
            if (state->f.s == 1)
                state->pc = address;
            else
                state->pc += 3;
            break;
        }
        case 0xe9: {
            i8080_TRACE(fprintf (state->log, "0x%04x: pchl ", state->pc));
            state->pc = hl;
            break;
        }
        case 0xcd: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: call 0x%04x", state->pc, address));
            call (state, address);
            break;
        }
        case 0xc4: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: cnz 0x%04x", state->pc, address));
            if (state->f.z == 0)
                call (state, address);
            else
                state->pc += 3;
            break;
        }
        case 0xcc: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: cz 0x%04x", state->pc, address));
            if (state->f.z == 1)
                call (state, address);
            else
                state->pc += 3;
            break;
        }
        case 0xd4: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: cnc 0x%04x", state->pc, address));
            if (state->f.cy == 0)
                call (state, address);
            else
                state->pc += 3;
            break;
        }
        case 0xdc: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: cc 0x%04x", state->pc, address));
            if (state->f.cy == 1)
                call (state, address);
            else
                state->pc += 3;
            break;
        }
        case 0xe4: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: cpo 0x%04x", state->pc, address));
            if (state->f.p == 0)
                call (state, address);
            else
                state->pc += 3;
            break;
        }
        case 0xec: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: cpe 0x%04x", state->pc, address));
            if (state->f.p == 1)
                call (state, address);
            else
                state->pc += 3;
            break;
        }
        case 0xf4: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: cp 0x%04x", state->pc, address));
            if (state->f.s == 0)
                call (state, address);
            else
                state->pc += 3;
            break;
        }
        case 0xfc: {
            uint16_t address = (state->mem[state->pc+1] | (state->mem[state->pc+2] << 8));
            i8080_TRACE(fprintf (state->log, "0x%04x: cm 0x%04x", state->pc, address));
            if (state->f.s == 1)
                call (state, address);
            else
                state->pc += 3;
            break;
        }
        case 0xc9: {
            i8080_TRACE(fprintf (state->log, "0x%04x: ret ", state->pc));
            ret (state);
            break;
        }
        case 0xc0: {
            i8080_TRACE(fprintf (state->log, "0x%04x: rnz ", state->pc));
            if (state->f.z == 0)
                ret (state);
            else
                state->pc++;
            break;
        }
        case 0xc8: {
            i8080_TRACE(fprintf (state->log, "0x%04x: rz ", state->pc));
            if (state->f.z == 1)
                ret (state);
            else
                state->pc++;
            break;
        }
        case 0xd0: {
            i8080_TRACE(fprintf (state->log, "0x%04x: rnc ", state->pc));
            if (state->f.cy == 0)
                ret (state);
            else
                state->pc++;
            break;
        }
        case 0xd8: {
            i8080_TRACE(fprintf (state->log, "0x%04x: rc ", state->pc));
            if (state->f.cy == 1)
                ret (state);
            else
                state->pc++;
            break;
        }
        case 0xe0: {
            i8080_TRACE(fprintf (state->log, "0x%04x: rpo ", state->pc));
            if (state->f.p == 0)
                ret (state);
            else
                state->pc++;
            break;
        }
        case 0xe8: {
            i8080_TRACE(fprintf (state->log, "0x%04x: rpe ", state->pc));
            if (state->f.p == 1)
                ret (state);
            else
                state->pc++;
            break;
        }
        case 0xf0: {
            i8080_TRACE(fprintf (state->log, "0x%04x: rp ", state->pc));
            if (state->f.s == 0)
                ret (state);
            else
                state->pc++;
            break;
        }
        case 0xf8: {
            i8080_TRACE(fprintf (state->log, "0x%04x: rm ", state->pc));
            if (state->f.s == 1)
                ret (state);
            else
                state->pc++;
            break;
        }
        case 0xc7: case 0xcf: case 0xd7:
        case 0xdf: case 0xe7: case 0xef:
        case 0xf7: case 0xff: {
            rst (state);
            break;
        }
        case 0xc5: {
            i8080_TRACE(fprintf (state->log, "0x%04x: push b", state->pc));
            state->mem[state->sp - 1] = state->b;
            state->mem[state->sp - 2] = state->c;
            state->sp -= 2;
            state->pc++;
            break;
        }
        case 0xd5: {
            i8080_TRACE(fprintf (state->log, "0x%04x: push d", state->pc));
            state->mem[state->sp - 1] = state->d;
            state->mem[state->sp - 2] = state->e;
            state->sp -= 2;
            state->pc++;
            break;
        }
        case 0xe5: {
            i8080_TRACE(fprintf (state->log, "0x%04x: push h", state->pc));
            state->mem[state->sp - 1] = state->h;
            state->mem[state->sp - 2] = state->l;
            state->sp -= 2;
            state->pc++;
            break;
        }
        case 0xf5: {
            i8080_TRACE(fprintf (state->log, "0x%04x: push psw", state->pc));
            state->mem[state->sp - 1] = state->a;
            state->mem[state->sp - 2] = ((state->f.cy << 0) | (1 << 1) |
                                         (state->f.p  << 2) | (0 << 3) |
                                         (state->f.ac << 4) | (0 << 5) |
                                         (state->f.z  << 6) | (state->f.s << 7));
            state->sp -= 2;
            state->pc++;
            break;
        }
        case 0xc1: {
            i8080_TRACE(fprintf (state->log, "0x%04x: pop b", state->pc));
            state->c = state->mem[state->sp];
            state->b = state->mem[state->sp + 1];
            state->sp += 2;
            state->pc++;
            break;
        }
        case 0xd1: {
            i8080_TRACE(fprintf (state->log, "0x%04x: pop d", state->pc));
            state->e = state->mem[state->sp];
            state->d = state->mem[state->sp + 1];
            state->sp += 2;
            state->pc++;
            break;
        }
        case 0xe1: {
            i8080_TRACE(fprintf (state->log, "0x%04x: pop h", state->pc));
            state->l = state->mem[state->sp];
            state->h = state->mem[state->sp + 1];
            state->sp += 2;
            state->pc++;
            break;
        }
        case 0xf1: {
            i8080_TRACE(fprintf (state->log, "0x%04x: pop psw", state->pc));
            state->a = state->mem[state->sp + 1];
            state->f.cy = ((state->mem[state->sp] >> 0) & 1);
            state->f.p  = ((state->mem[state->sp] >> 2) & 1);
            state->f.ac = ((state->mem[state->sp] >> 4) & 1);
            state->f.z  = ((state->mem[state->sp] >> 6) & 1);
            state->f.s  = ((state->mem[state->sp] >> 7) & 1);
            state->sp += 2;
            state->pc++;
            break;
        }
        case 0xdb: {
            uint8_t port = state->mem[state->pc+1];
            i8080_TRACE(fprintf (state->log, "0x%04x: in 0x%02x", state->pc, port));

            if (state->io_handler) {
                state->a = state->io_handler (port, 0xee, DEVICE_IN);
            }

            state->pc += 2;
            break;
        }
        case 0xd3: {
            uint8_t port = state->mem[state->pc+1];
            i8080_TRACE(fprintf (state->log, "0x%04x: out 0x%02x", state->pc, port));

            if (state->io_handler) {
                state->io_handler (port, state->a, DEVICE_OUT);
            }

            state->pc += 2;
            break;
        }
        default: {
            fprintf (state->log, "0x%04x: 0x%02x [unknown opcode]\n", state->pc, state->mem[state->pc]);
            return -1;
        }
    }

    return 0;
}

void i8080_interrupt (struct i8080_state* state, uint8_t nnn)
{
    if (state->i) {
        i8080_TRACE(fprintf (state->log, "0x%04x: <interrupt> 0x%02x", state->pc, nnn));

        /* same as RST instruction */
        state->mem[state->sp - 1] = ((state->pc & 0xff00 ) >> 8);
        state->mem[state->sp - 2] = ((state->pc & 0x00ff ) >> 0);
        state->i = 0; /* disable interrupts */
        state->sp -= 2;
        state->pc = (nnn * 8);
    }
}

void i8080_load_memory (struct i8080_state* state, const int offset, const char* const filename)
{
    long fsize;
    FILE *f = fopen(filename, "rb");

    if (NULL != f) {
        fseek(f, 0, SEEK_END);
        fsize = ftell(f);
        fseek(f, 0, SEEK_SET);

        fsize = (fsize > state->mem_sizeb) ? state->mem_sizeb : fsize;

        fread(&state->mem[offset], fsize, 1, f);
        fclose(f);
    } else {
        fprintf (stderr, "Error: unable to open %s : %s\n", filename, strerror(errno));
        exit(-1);
    }
}
