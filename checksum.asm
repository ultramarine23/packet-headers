;
; checksum.asm - the one's complement internet checksum.
;
; Compute the one's complement sum used for generation and verification.
;
; The contract, from driver.c:
;
;       int len                   [ebp+12]
;       unsigned char *hdr        [ebp+8]
;
; Sum len bytes of hdr as len/2 16-bit big-endian words into a 32-bit
; accumulator. Fold the carries until the result fits in 16 bits. Return
; the one's complement of that in ax. The manual's worked example is the
; test. Zero the checksum field, sum the sample header, and you must get
; 0x9CBC.
;
; The decode path calls this over the header as it stands, checksum field
; included. A valid header returns 0 and an invalid one does not. The
; encode path calls it over a header whose checksum field you wrote as zero.
; One routine serves both uses. You don't need to know which one called
; you.
;
; Do not clobber ebx, esi, edi, or ebp. C assumes they survive your call.
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _ip_checksum ip_checksum
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

segment .text
        global  _ip_checksum
_ip_checksum:
        enter   0,0
        pusha

        mov     ebx, 0 ;ebx: temporary 16 bit word
        mov     edx, 0 ;edx: temporary storage for second byte

        ;ecx: number of bytes remaining
        ;esi: address of current header byte
        ;ebp: reference point for stack arguments
        ;esp: stack pointer

        ;load function arguments
        mov     ecx, [ebp + 12]         ; iterator/remaining bytes
        mov     esi, [ebp + 8]          ; an address pointing to 20 bytes of header (from encoding)

        ; esi = header, ecx = length in bytes, returns checksum in ax
        ; the loop changes ebx and esi, so save both before it and restore them after
        xor eax, eax ; accumulator initialization (set eax to zero)
        sum_loop:
                cmp ecx, 0
                jle .fold

                ; high 2 byte group
                movzx ebx, byte [esi]
                shl ebx, 8

                ; low 2 byte group
                movzx edx, byte [esi + 1]
                or ebx, edx

                ; 32-bit accumulator, carries are still represented outside the 16 bit group
                add eax, ebx

                add esi, 2
                sub ecx, 2
                jmp sum_loop

        ; do this if the high 16 bit group is not zero
        .fold:

                ; divide the 16 bit groups of eax, store higher 16 bit group to other reg.
                ; shift the higher 16 bit group to the Right...
                ; so that we can add the lower and higher groups
                mov     ebx, eax
                shr     ebx, 16
                jz      .done
                and     eax, 0x0000FFFF
                add     eax, ebx
                jmp     .fold

        .done:
                ; store the returned value
                not     eax
                and     eax, 0x0000FFFF
                ; pusha saved eax at esp+28; replace it so popa returns the result.
                mov     [esp + 28], eax

        popa
        leave
        ret
