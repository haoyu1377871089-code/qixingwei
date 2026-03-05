#!/usr/bin/env python3
"""Convert byte-addressed Verilog hex to 32-bit word-addressed hex (little-endian)."""
import sys

with open(sys.argv[1]) as f:
    lines = f.read().split('\n')

with open(sys.argv[2], 'w') as out:
    for line in lines:
        line = line.strip()
        if not line:
            continue
        if line.startswith('@'):
            addr = int(line[1:], 16)
            out.write('@%08X\n' % (addr // 4))
            continue
        bs = line.split()
        while len(bs) >= 4:
            w = (int(bs[3], 16) << 24 | int(bs[2], 16) << 16 |
                 int(bs[1], 16) << 8 | int(bs[0], 16))
            out.write('%08X\n' % w)
            bs = bs[4:]
