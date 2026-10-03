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

**How does the header layout work?**

For this lab, we are essentially tasked to encode/decode/compute the checksum for an IPv4 header, which is composed of 20 bytes. This is what the header layout will look like in the implementation.


***1st Double Word
1st Byte:
This includes the Version and the Internet Header Length which are both 4 widths respectively

2nd Byte: 
We have the DSCP and ECN which are 6 bits and 2 bits width respectively

3rd and 4th Byte:
We have the Total Length that is split between 2 bytes  which we store it in big endian


***2nd Double Word
4th and 5th Byte:
This includes the Identification number which we store it in big endian it has a width of 16 bits

6th Byte: 
We have the flags in which its width is 3 which goes from bit 5 to 7, we reserve bit 7. and we the flag will change depending on whats 1 in bit 5 or 6

6th and 7th:
We have the Fragment Offset in which it occpies the bits 0 - 4 in byte 6; and the entirety of the 7th byte, it has a width of 13


***3rd Double Word
8th Byte:
This includes the TTL which has the width of 8 and occupies the 8th byte

9th Byte: 
We have the Protocol in which it occupies the 9th Byte. It has only 2 values which are 6 for TCP and 17 for UDP

10th and 11th Byte:
We have the Header Checksum in which it occupies 2 bytes

the value of this is the sum of all 16 bits partitions for in the entire header, except the portion in which the Header Checksum will be. If the sum has overflowed, then we add binary 1 to the sum to "fold" it.

Then, we invert the value of the sums, and that will be the Header Checksum


***4th Double Word
12th to 15th Byte:
This includes the entire Source Address

***5th Double Word
16th to 19th Byte:
This includes the entire Destination Address


### Problem analysis

What the tool must read, what it must write, and which field is the hard
one. State the header layout in your own words.

### Solution architecture

How the three routines split the work. Which registers each routine uses,
and how the struct offsets in `driver.c` map to the fields.

**How do the three subsystems split the work?**
So basically the decoding part is what converts the 20 bytes of IPv4 header into a readable format

The encoding part is what gets the inputs to be be masked an inserted into their respective partitions and positions in the entire 20 byte header, and also computes for the value of the checksum.

The Checksum function is to check if the current checksum is VALID, it re runs the same computation for creating the checksum but this time add the portion of the checksum itself to cover the whole header. Then checks if the value is 0x0000 then its VALID, if not then its not valid

### Timeline

One line per week. Name the subsystem each week finishes and the member
who owns it.

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

Complete this section before the Week 3 progress report. The syllabus asks
for documentation of quirks and issues with the complete implementation.
One entry per item. State what happens, what causes it, and what the group
did about it.

### Known issues

- 

### Quirks

- 
