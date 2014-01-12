void ByteMachineExact(__global uchar *rom, __global uchar *mem, int iters) {
  for (int i = 0; i < iters; i++) {
    // byte 0 is instruction pointer
    uchar inst = rom[mem[0]];
    // 3 bits opcode, 5 bits regs/data
    uchar opcode = inst >> 5;
    uchar reg_srca = inst & 1;
    uchar reg_srcb = (inst >> 1) & 3;
    uchar reg_dst = (inst >> 3) & 3;
    switch (opcode) {
    case 0: {
      // Load immediate.
      uchar imm = (inst & 15);
      mem[reg_dst] = imm;
      break;
    }

    case 1: {
      // Add mod 256.
      uchar res = mem[reg_srca] + mem[reg_srcb];
      mem[reg_dst] = res;
      break;
    }

    case 2: {
      // Load indirect.
      uchar addr = mem[reg_srca] + mem[reg_srcb];
      mem[reg_dst] = mem[addr];
      break;
    }

    case 3: {
      // Store indirect.
      uchar addr = mem[reg_srca] + mem[reg_srcb];
      mem[addr] = mem[reg_dst];
      break;
    }

    case 4: {
      // Add if zero.
      if (!mem[reg_srcb]) {
        mem[reg_dst] += mem[reg_srca];
      }
      break;
    }

    case 5: {
      // Left shift.
      uchar res = mem[reg_srca] << reg_srcb;
      mem[reg_dst] = res;
      break;
    }

    case 6: {
      // Swap 1th register with nth.
      uchar lreg = inst & 15;
      uchar tmp = mem[1];
      mem[1] = mem[lreg];
      mem[lreg] = tmp;
      break;
    }

    case 7: {
      // xor
      uchar res = mem[reg_srca] ^ mem[reg_srcb];
      mem[reg_dst] = res;
      break;
    }
    }

    // And increment instruction pointer.
    mem[0]++;

  }
}
