.include "defs.s"

.global print_cstr
.global print_hex128

.section .rodata
hex_lut:
    .ascii "0123456789ABCDEF"

.section .text

print_cstr:
    mov  x2, #0
pc_len:
    ldrb w3, [x1, x2]
    cbz  w3, pc_write
    add  x2, x2, #1
    b    pc_len
pc_write:
    mov  x8, #SYS_WRITE
    svc  #0
    ret

print_hex128:
    stp  x29, x30, [sp, #-80]!
    mov  x29, sp
    str  x19, [sp, #16]
    mov  w19, w1

    ldp  x2, x3, [x0]           
    adrp x4, hex_lut
    add  x4, x4, :lo12:hex_lut
    add  x7, sp, #32

    mov  x6, #60
ph_hi:
    lsr  x9, x3, x6
    and  x9, x9, #0xf
    ldrb w9, [x4, x9]
    strb w9, [x7], #1
    subs x6, x6, #4
    bge ph_hi

    mov  x6, #60
ph_lo:
    lsr  x9, x2, x6
    and  x9, x9, #0xf
    ldrb w9, [x4, x9]
    strb w9, [x7], #1
    subs x6, x6, #4
    bge ph_lo

    mov  w9, #10                  
    strb w9, [x7]

    mov  w0, w19
    add  x1, sp, #32
    mov  x2, #33
    mov  x8, #SYS_WRITE
    svc  #0

    ldr  x19, [sp, #16]
    ldp  x29, x30, [sp], #80
    ret
