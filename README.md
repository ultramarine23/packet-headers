<!--no-pdf-->
# CMSC 131 Lab 1 Starter

Decode, encode, and checksum 20-byte IPv4 packet headers under a C driver.
The manual is the assignment. This file is the repository's own notes.

## Layout

```text
Makefile            platform preamble and build rules
driver.c            provided: argument parsing and file I/O
cdecl.h             provided: the calling-convention macros
decode.asm          yours
encode.asm          yours
checksum.asm        yours
run_tests.sh        provided: the correctness gate
contract_test.c     provided: the second pass, in C
contract_regs.asm   provided: register discipline checks for contract_test
tests/              provided: the header fixtures, their expected output,
                    and manifest.txt, the list both passes read
LICENSE             CC BY-NC-SA 4.0, inherited from the pcasm material
```

## What to Run

```bash
make
make check
```

`make` builds `renpkt` and `contract_test`. `make check` builds both, then
runs `./run_tests.sh`, which reports each test and exits nonzero when any
of them differ.

The gate has two passes. The first decodes every header listed in
`tests/manifest.txt` and compares the output with `tests/expected/`. The
second is `contract_test`. It decodes and re-encodes every header the
manifest marks valid. It checks a checksum vector that needs the carry
folded twice. It checks that all three routines keep `ebx`, `esi`, `edi`,
and `ebp`, and return with `esp` where the call left it. A program can pass
the first pass and fail the second. That failure is the usual encoder bug.

## Reading a First Run

The assembly files ship as stubs that assemble and link as-is, so the build
works before you write any code. Right now they do nothing useful, which
makes every check fail: `7 of 7 checks differ`. That red run is the correct
starting state for a starter. The badge stays red until you implement the
routines.

## Adding a Header

Put the header in `tests/NAME.bin`. Write the output `renpkt --decode`
must print for it in `tests/expected/NAME.out`. Then add one line to
`tests/manifest.txt`:

```text
NAME valid
```

Use `invalid` for a header with a wrong checksum. A valid header joins the
round trip in `contract_test` as well as the decode pass. The gate fails
and names the file when a `.bin` is not in the manifest, and when a listed
header has no expected file.

## The Driver's Argument Checks

`renpkt --encode` refuses a value its field cannot hold, and two values the
standard forbids. `--len` takes 20 through 65535, because the total length
counts the header. It defaults to 20. `--flags` takes 0 through 3, because
the top bit of the field is reserved and must be zero. `--df` sets 2 and
`--mf` sets 1. A refused option exits with status 2 and writes no file.

## Documentation

The three sections at the end of this file are yours. Complete Design Notes
and Subsystem Ownership before the Week 1 progress report. Complete Quirks
and Issues before the Week 3 progress report. Each section says what it
needs. Leave the rest of this file as it is.

## Fixtures

The provided files are fixtures. The grader compares your fork against the
starter. An edit to `driver.c`, `Makefile`, `run_tests.sh`,
`contract_test.c`, `contract_regs.asm`, or a provided `tests/` file appears
as a diff in the open. Your own headers and manifest lines are additions,
not edits.

---

## Design Notes

### Problem analysis

`renpkt` reads and writes exactly the 20-byte IPv4 base header. The provided
C driver handles arguments, file I/O, and printing; assembly handles every
field and the checksum. Options and payload are outside this activity.
Byte offsets below start at zero. IHL counts 32-bit words: 5 means 20 bytes.

| Header bytes | Fields | Struct offsets |
|---|---|---|
| 0 | Version in bits 7–4; IHL in bits 3–0 | +0, +4 |
| 1 | DSCP in bits 7–2; ECN in bits 1–0 | +8, +12 |
| 2–3 | Total length, big-endian | +16 |
| 4–5 | Identification, big-endian | +20 |
| 6–7 | Three flags above a thirteen-bit fragment offset | +24, +28 |
| 8 | TTL | +32 |
| 9 | Protocol (including TCP 6, UDP 17, ICMP 1, and other values) | +36 |
| 10–11 | Header checksum, big-endian | +40 |
| 12–15 | Four source address octets | +44 |
| 16–19 | Four destination address octets | +48 |

The fragment offset crosses a byte boundary. Its upper five bits occupy
byte 6 bits 4–0; its lower eight bits occupy byte 7. The decoder masks byte
6 with `0x1F`, shifts by eight, and combines byte 7. This is equivalent to
masking the combined network word with `0x1FFF`. The flags use `0xE0` and
a right shift of five, preserving the reserved bit when reading a file.
The driver restricts outgoing flags to 0–3 and total length to 20–65535.

### Solution architecture

`decode_header` reads each numeric field with byte loads, shifts and masks,
then writes the struct. `esi` points to the header, `edi` to the struct;
`eax`, `ebx`, `ecx`, and `edx` hold extracted pieces. The addresses are
copied in octet order into their four-byte arrays.

`encode_header` reverses this mapping. `esi` points to the input struct,
`edi` to the destination, `eax` holds a masked field, and `ebx` assembles
four output bytes. Numeric fields are packed into network order with shifts
and masks; the address arrays already contain octets in output order.
Every output byte is initialized, including zeroing bytes 10–11 before
calling `ip_checksum`. The input struct's checksum is ignored. The returned
high and low bytes are stored at offsets 10 and 11 respectively.

`ip_checksum` takes a header pointer and a nonnegative even byte count;
all activity calls use 20. `esi` walks the buffer, `ecx` counts remaining
bytes, `ebx` and `edx` assemble each network word, and `eax` accumulates
the sum in 32 bits. It repeatedly adds the high sixteen bits to the low
sixteen bits until no carry remains, then complements the result. With
checksum bytes zero this generates the checksum; with the stored checksum
included it returns zero for a valid header. No tables, floating point,
`bswap`, or `xchg` are used.

The struct offsets follow `driver.c`: eleven four-byte unsigned integers
occupy offsets 0–43, followed by two four-byte octet arrays at 44 and 48.
All three routines use `enter 0,0` and `pusha`/`popa`. The five cdecl
obligations are to preserve `ebx`, `esi`, `edi`, and `ebp`, and balance `esp`.
For the checksum result, `[esp+28]` is the saved `eax` slot after `pusha`;
replacing that slot before `popa` keeps the returned checksum in `eax`.

Example stack trace for `decode_header(hdr, &fields)`, starting at
`esp=0x1000`: pushing `&fields` gives `0x0FFC`, pushing `hdr` gives `0x0FF8`,
and `call` gives `0x0FF4`. `enter` saves `ebp` at `0x0FF0`, making `hdr`
`[ebp+8]` and `&fields` `[ebp+12]`. `pusha` gives `0x0FD0`; `popa` restores
`0x0FF0`, `leave` restores `0x0FF4`, and `ret` restores `0x0FF8`. The
caller removes the eight argument bytes to return to `0x1000`.
The encoder likewise removes its eight argument bytes after calling the
checksum routine; its `edi` pointer survives that call.

### Timeline

| Week | Goal | Owner |
|---|---|---|
| 1 | Framework | all |
| 2 | Decoder | Jared |
| 3 | Encoder and Checksum | Brent/JM |
| 4 | Defense | all |

## Subsystem Ownership

Complete this section before the Week 1 progress report. The manual lists
the three subsystems. Each member owns one. In a group of four, two members
share one. The commit history must agree with this table.

| Subsystem | Owner |
|---|---|
| Decode path (`decode.asm`) | Jared Chua |
| Encode path (`encode.asm`) | |
| Checksum and tests (`checksum.asm`, `tests/`) | |

## Quirks and Issues

### Known issues

- No failures remain in the current correctness gate or the independent
  CLI checks. These checks cover this activity's 20-byte format, not IPv4
  options or payload processing.
- GCC warns about potential filename truncation in the supplied
  `contract_test.c`. Our fixture names fit its buffer. The provided harness
  is retained unchanged as required by the manual.

### Quirks

- The encoder originally used an immediate store without an operand size,
  which NASM refused to assemble. Specifying `dword` initializes TTL,
  protocol, and both checksum bytes before packing the output.
- The encoder originally shifted the upper fragment-offset bits by sixteen
  after masking `0x1F00`. That placed them in byte 7 instead of byte 6.
  Shifting by eight preserves both the flag bits and the complete offset.
- The decoder previously masked flags with `0x60`, dropping the reserved
  bit. It now uses `0xE0`. `edge_reserved` deliberately contains that bit
  with a correct checksum: checksum validity does not imply a legal IPv4
  header. The decoder reports all three bits; the CLI rejects outgoing
  reserved flags. This diagnostic fixture is marked `valid` in the manifest
  because that classification means checksum-valid, as the harness defines.
- A sum can still overflow after one carry fold. `edge_doublefold` has a
  zero-checksum word sum of `0x2FFFF`: the first fold yields `0x10001`, the
  second yields `0x0002`, and the stored checksum is `0xFFFD`. The supplied
  contract also checks `0x8FFFF`. The checksum loop repeats until the high
  half is zero.
- `pusha` saves `eax` too. Returning a computed result before an ordinary
  `popa` would restore the caller's old value. The checksum replaces the
  saved `eax` slot so the return value survives restoration.

### Verification

Run from the repository root:

```bash
make check
python3 tools/verify_edges.py
```

The correctness gate passes all 13 checks: twelve decoded fixtures plus the
contract pass. The contract includes ten exact header round trips, the
supplied double-fold vector, and register/stack checks for all three routines.
Added fixtures cover minimum length, TTL 1, offset 1, maximum offset, a legal
header needing two carry folds, reserved-bit decoding, and corruption.
The original boundary fixture covers both flags, maximum DSCP/ECN, and
other maximum field values.

The independent Python oracle uses network-order packing and one's
complement arithmetic. Its fixed seed makes 256 CLI encode/decode cases
repeatable, checks all four legal flag combinations, verifies nine rejected
field ranges write no output file, and checks default values. It does not
use the assembly output to derive expected results. To regenerate only our
added fixtures, run `python3 tools/verify_edges.py --generate-fixtures`.
Python 3.9 or newer is needed for this optional script; the supplied gate
still requires only the original build tools.

For the manual's defense round trip:

```bash
./renpkt --encode --dscp 46 --ecn 1 --len 1500 --id 48879 \
  --mf --frag 4660 --ttl 128 --proto 17 \
  --src 10.0.0.1 --dst 10.0.0.2 -o /tmp/renpkt-rebuilt.bin
cmp /tmp/renpkt-rebuilt.bin tests/sample04.bin
```

Each member should be able to trace the shared fields, explain the carry
fold and cdecl stack, and explain a subsystem they did not write. Individual
reflections and peer assessments must describe each member's actual work.
