;
; decode.asm - extract every field from a 20-byte IPv4 header.
;
; This is your starting point. It assembles and links as-is, so the build
; works before you write any code. Right now it stores nothing, so renpkt
; prints the zeros driver.c put in the struct. Your job is to replace that
; with the extraction described below.
;
; The contract, from driver.c:
;
;       struct ipv4_fields *out   [ebp+12]
;       unsigned char *hdr        [ebp+8]
;
; hdr points at twenty bytes in network byte order. out points at the struct
; documented in driver.c. Its offsets are:
;
;   +0 version   +4 ihl    +8 dscp   +12 ecn   +16 total_length
;   +20 identification    +24 flags  +28 fragment_offset
;   +32 ttl      +36 protocol       +40 checksum
;   +44 src[0..3]                   +48 dst[0..3]
;
; Every int member is 4 bytes, so a plain 32-bit store fills one. The
; addresses are four single-byte stores each.
;
; Do not clobber ebx, esi, edi, or ebp. C assumes they survive your call.
; Return in eax (driver.c ignores it here, so returning 0 is fine).
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _decode_header decode_header
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

segment .text
        global  _decode_header
_decode_header:
        enter   0,0
        pusha

        ;
        ; TODO: read the header and fill the struct.
        ;
        ; The field-by-field layout is the table in the manual. The notes
        ; that matter before you start:
        ;
        ;   * Every multi-byte field is big-endian, so load it byte by byte
        ;     and recombine. A single 16-bit load gives you the bytes
        ;     reversed.
        ;   * The fragment offset straddles a byte boundary. Its top five
        ;     bits live in byte 6 and its bottom eight in byte 7. Combine
        ;     both bytes into one word first, then shift and mask.
        ;   * The flags are the top three bits of the same word.
        ;   * Read and store the checksum field like any other field.
        ;     ip_checksum computes the VALID line separately.
        ;   * src and dst are four single-byte stores each. No shifting.
        ;
        ; Nothing here reads the file or prints. This routine only fills
        ; the struct, and driver.c does the rest.
        ;

        mov     esi, [ebp + 8]
        mov     edi, [ebp + 12]

        ; move the zeroth byte into ebx {y}
        movzx   ebx, byte [esi + 0]

        ; decode version
        ; ignore lower 4 bits and shift to the beginning
        mov     eax, ebx
        and     eax, 0b11110000
        shr     eax, 4
        mov     [edi], eax

        ; decode IHL
        ; ignore upper 4 bits, and no need to shift
        mov     eax, ebx
        and     eax, 0b00001111
        mov     [edi + 4], eax


        ; move the first byte into ebx {y}
        movzx   ebx, byte [esi + 1]

        ; decode dscp
        ; ignore lower 2 bits and shift to the beginning
        mov     eax, ebx
        and     eax, 0b11111100
        shr     eax, 2
        mov     [edi + 8], eax

        ; decode ECN
        ; ignore upper 6 bits, and no need to shift
        mov     eax, ebx
        and     eax, 0b00000011
        mov     [edi + 12], eax


        ; move and process the second/third bytes {y}
        ; decode length
        ; big-endian: byte 2 goes on ah, byte 3 goes on al
        ; eax naturally reverses the two
        movzx   ebx, byte [esi + 2]
        movzx   ecx, byte [esi + 3]

        mov     eax, ebx
        shl     eax, 8
        or      eax, ecx
        mov     [edi + 16], eax


        ; move and process the fourth/fifth bytes {y}
        ; decode identification
        ; big-endian: byte 4 goes on ah and byte 5 goes on al
        movzx   ebx, byte [esi + 4]
        movzx   ecx, byte [esi + 5]
        
        mov     eax, ebx
        shl     eax, 8
        or      eax, ecx
        mov     [edi + 20], eax


        ; move and process the six/seventh bytes {y}
        movzx   ebx, byte [esi + 6]
        movzx   ecx, byte [esi + 7]

        ; decode flags
        ; take the top 2-3 bits and shift to the beginning
        mov     eax, ebx
        and     eax, 0b01100000
        shr     eax, 5
        mov     [edi + 24], eax

        ; decode fragment offset
        mov     eax, ebx
        and     eax, 0b00011111
        shl     eax, 8
        or      eax, ecx

        mov     [edi + 28], eax


        ; move and process the eigth byte {y}
        ; decode TTL
        movzx   eax, byte [esi + 8]
        mov     [edi + 32], eax


        ; move and process the ninth byte {y}
        ; decode protocol
        movzx   eax, byte [esi + 9]
        mov     [edi + 36], eax


        ; move and process the tenth/eleventh byte {y}
        ; decode header checksum (incomplete since the checksum subsystem hasnt been built yet)
        movzx   ebx, byte [esi + 10]
        movzx   ecx, byte [esi + 11]

        ; call checksum function or whatever, here
        ; placeholder: print the bytes

        mov     eax, ebx
        shl     eax, 8
        or      eax, ecx
        mov     [edi + 40], eax


        ; move and process the twelfth-fifteenth byte {y}
        ; decode source address
        movzx   eax, byte [esi + 12]
        movzx   ebx, byte [esi + 13]
        movzx   ecx, byte [esi + 14]
        movzx   edx, byte [esi + 15]
        
        shl     ebx, 8
        shl     ecx, 16
        shl     edx, 24

        or      eax, ebx
        or      eax, ecx        
        or      eax, edx

        mov     [edi + 44], eax


        ; move and process the sixteenth-nineteenth byte {y}
        ; decode destination address
        movzx   eax, byte [esi + 16]
        movzx   ebx, byte [esi + 17]
        movzx   ecx, byte [esi + 18]
        movzx   edx, byte [esi + 19]
        
        shl     ebx, 8
        shl     ecx, 16
        shl     edx, 24

        or      eax, ebx
        or      eax, ecx        
        or      eax, edx
        
        mov     [edi + 48], eax


        popa
        mov     eax, 0
        leave
        ret
