#!/usr/bin/env python3
"""Offline NXDN golden vectors; independent byte-oriented reference.

Reproduces DroidStar/nxdn.cpp get_frame, encode_header/data, CRC6 and
hardware deinterleave_ambe (AD8DP, GPL-3.0-or-later), checked 2026-10-29.
This does not import or execute FusionLab's packet encoder.
"""
import json
from pathlib import Path

ORDER = [0,3,6,9,12,15,18,21,24,27,30,33,36,39,41,43,45,47,
         1,4,7,10,13,16,19,22,25,28,31,34,37,40,42,44,46,48,
         2,5,8,11,14,17,20,23,26,29,32,35,38]

def bit(d, n):
    return (d[n//8] >> (7-n%8)) & 1

def put(d, n, value):
    d[n//8] = (d[n//8] & ~(128 >> (n%8))) | (value << (7-n%8))

def native(d):
    out = bytearray(7)
    for i, j in enumerate(ORDER):
        put(out, i, bit(d, j))
    return out

def frame(seq, kind, voices):
    p = bytearray(43)
    p[:10] = b'NXDND' + (41007).to_bytes(2, 'big') + (204).to_bytes(2, 'big') + bytes([5 if kind == 0 else 9 if kind == 2 else 1])
    lc = bytearray([8 if kind == 2 else 1, 0, 32, 0xa0, 0x2f, 0, 0xcc] + [0]*7)
    s = bytearray(4)
    s[0] = 1
    if kind == 1:
        s[0] |= (3-seq%4) << 6
        for i in range(18):
            put(s, i+8, bit(lc, seq%4*18+i))
    else:
        s[1] = 0x10
    crc = 63
    for i in range(26):
        feedback = bit(s, i) ^ bool(crc & 32)
        crc = (crc << 1) & 255
        if feedback:
            crc ^= 0x27
    for i in range(6):
        put(s, i+26, (crc >> (5-i)) & 1)
    p[10] = 0xac if kind == 1 else 0x81
    p[11:15] = s
    if kind != 1:
        p[15:29] = lc
        p[29:43] = lc
    else:
        raw = [native(v) for v in voices]
        # DroidStar's byte-wise overlapping copy, distinct from Swift bit offsets.
        for start, a, b in [(15, raw[0], raw[1]), (29, raw[2], raw[3])]:
            p[start:start+7] = a
            for i in range(7):
                p[start+6+i] |= b[i] >> 1
                p[start+7+i] = (b[i] & 1) << 7
            p[start+13] |= b[6] >> 2
    return p.hex()

voices = [bytes(((i*37+11) & (128 if i%7==6 else 255)) for i in range(j*7,(j+1)*7)) for j in range(4)]
vectors = {'voices': [v.hex() for v in voices], 'header': frame(0,0,voices), 'end': frame(5,2,voices)}
for seq in range(1,5):
    vectors[f'voice-{seq}'] = frame(seq,1,voices)
Path(__file__).resolve().parent.parent.joinpath('Tests/Fixtures/NXDNReference.json').write_text(json.dumps(vectors, indent=2)+'\n')
