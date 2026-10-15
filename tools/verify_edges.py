#!/usr/bin/env python3
"""Independent IPv4 oracle; generate added fixtures or verify CLI round trips."""
import argparse
import random
import struct
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def checksum(header):
    total = sum(struct.unpack('!10H', header))
    while total >> 16:
        total = (total & 0xffff) + (total >> 16)
    return (~total) & 0xffff


def header(dscp=0, ecn=0, length=20, ident=0, flags=0, frag=0,
           ttl=0, proto=0, src=bytes(4), dst=bytes(4)):
    data = bytearray(struct.pack('!BBHHHBBH4s4s', 0x45, dscp << 2 | ecn,
                                length, ident, flags << 13 | frag,
                                ttl, proto, 0, src, dst))
    data[10:12] = struct.pack('!H', checksum(data))
    return bytes(data)


def output(data):
    first, service, length, ident, fragment, ttl, proto, check, src, dst = struct.unpack('!BBHHHBBH4s4s', data)
    flags = fragment >> 13
    flag_text = str(flags) + (' (DF)' if flags & 2 else '') + (' (MF)' if flags & 1 else '')
    protocol = str(proto) + {6: ' (TCP)', 17: ' (UDP)', 1: ' (ICMP)'}.get(proto, '')
    rows = [('Version:', first >> 4), ('IHL:', f'{first & 15} ({(first & 15) * 4} bytes)'),
            ('DSCP:', service >> 2), ('ECN:', service & 3), ('Total Length:', length),
            ('Identification:', ident), ('Flags:', flag_text), ('Fragment Offset:', fragment & 0x1fff),
            ('TTL:', ttl), ('Protocol:', protocol), ('Header Checksum:', f'0x{check:04X}'),
            ('Source:', '.'.join(map(str, src))), ('Destination:', '.'.join(map(str, dst))),
            ('Checksum:', 'VALID' if checksum(data) == 0 else 'INVALID')]
    return ''.join(f'{label:<18}{value}\n' for label, value in rows)


def fixtures():
    # Sum with bytes 10-11 zero is exactly 0x2FFFF: two folds required.
    base = header(ttl=1, proto=6, src=bytes([255]*4))
    words = list(struct.unpack('!10H', base)); words[5] = 0
    remainder = 0x2ffff - sum(words)
    double = header(ttl=1, proto=6, src=bytes([255]*4), dst=struct.pack('!HH', remainder, 0))
    cleared = bytearray(double); cleared[10:12] = bytes(2)
    assert sum(struct.unpack('!10H', cleared)) == 0x2ffff
    reserved = bytearray(header(flags=0)); reserved[6] |= 0x80
    reserved[10:12] = bytes(2); reserved[10:12] = struct.pack('!H', checksum(reserved))
    corrupt = bytearray(double); corrupt[8] ^= 1
    return {'edge_min': header(ttl=1), 'edge_frag1': header(flags=1, frag=1, ttl=1),
            'edge_maxfrag': header(flags=2, frag=8191, length=65535, ttl=255),
            'edge_doublefold': double, 'edge_reserved': bytes(reserved), 'edge_corrupt': bytes(corrupt)}


def run_checks():
    rng = random.Random(131)
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / 'header.bin'
        for i in range(256):
            fields = dict(dscp=rng.randrange(64), ecn=rng.randrange(4), length=rng.randrange(20, 65536),
                          ident=rng.randrange(65536), flags=i % 4, frag=[0, 1, 8191, rng.randrange(8192)][i % 4],
                          ttl=rng.randrange(256), proto=rng.randrange(256),
                          src=rng.randbytes(4), dst=rng.randbytes(4))
            args = [str(ROOT / 'renpkt'), '--encode', '-o', str(path)]
            for name, option in [('length', 'len'), ('ident', 'id'), ('frag', 'frag'), ('ttl', 'ttl'),
                                 ('proto', 'proto'), ('dscp', 'dscp'), ('ecn', 'ecn'), ('flags', 'flags')]:
                args += ['--' + option, str(fields[name])]
            for name in ['src', 'dst']:
                args += ['--' + name, '.'.join(map(str, fields[name]))]
            subprocess.run(args, check=True, capture_output=True)
            expected = header(**fields)
            assert path.read_bytes() == expected, f'encode case {i}'
            decoded = subprocess.run([str(ROOT / 'renpkt'), '--decode', str(path)], check=True,
                                     capture_output=True, text=True).stdout
            assert decoded == output(expected), f'decode case {i}'
        for option, value in [('len', '19'), ('len', '65536'), ('flags', '4'), ('frag', '8192'),
                              ('dscp', '64'), ('ecn', '4'), ('ttl', '256'), ('proto', '256'), ('id', '65536')]:
            path.unlink(missing_ok=True)
            result = subprocess.run([str(ROOT / 'renpkt'), '--encode', '--' + option, value,
                                     '-o', str(path)], capture_output=True)
            assert result.returncode == 2 and not path.exists(), option
        subprocess.run([str(ROOT / 'renpkt'), '--encode', '-o', str(path)], check=True)
        assert path.read_bytes() == header(), 'default values'
    print('Passed 256 independent encode/decode cases, 9 invalid ranges, and defaults.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--generate-fixtures', action='store_true')
    args = parser.parse_args()
    if args.generate_fixtures:
        for name, data in fixtures().items():
            (ROOT / 'tests' / (name + '.bin')).write_bytes(data)
            (ROOT / 'tests' / 'expected' / (name + '.out')).write_text(output(data))
    else:
        run_checks()
