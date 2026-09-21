.include "defs.s"

.global sig_setup
.global stop_flag

.section .data
.balign 4
stop_flag:
    .word 0

.section .text

sig_handler:
    adrp x1, stop_flag
    add  x1, x1, :lo12:stop_flag
    mov  w2, #1
    str  w2, [x1]
    ret

sig_setup:
    stp  x29, x30, [sp, #-48]!
    mov  x29, sp

    adrp x0, sig_handler
    add  x0, x0, :lo12:sig_handler
    str  x0, [sp, #16]
    stp  xzr, xzr, [sp, #24]       
    str  xzr, [sp, #40]

    mov  x0, #SIGINT
    add  x1, sp, #16
    mov  x2, #0
    mov  x3, #8
    mov  x8, #SYS_RT_SIGACTION
    svc  #0

    mov  x0, #SIGTERM
    add  x1, sp, #16
    mov  x2, #0
    mov  x3, #8
    mov  x8, #SYS_RT_SIGACTION
    svc  #0

    mov  x0, #0
    ldp  x29, x30, [sp], #48
    ret
