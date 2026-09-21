.include "defs.s"

.global uart_open
.global uart_read

.section .text

uart_open:
    stp  x29, x30, [sp, #-80]!
    mov  x29, sp
    str  x19, [sp, #16]

    mov  x1, x0
    mov  x0, #AT_FDCWD
    mov  x2, #(O_RDWR | O_NOCTTY)
    mov  x3, #0
    mov  x8, #SYS_OPENAT
    svc  #0
    cmp  x0, #0
    blt  uo_fail
    mov  x19, x0

    stp  xzr, xzr, [sp, #32]
    stp  xzr, xzr, [sp, #48]
    stp  xzr, xzr, [sp, #64]
    mov  w1, #CFLAGS_115200_8N1
    str  w1, [sp, #40]          
    mov  w1, #1
    strb w1, [sp, #55]

    mov  x0, x19
    mov  x1, #TCSETS
    add  x2, sp, #32
    mov  x8, #SYS_IOCTL
    svc  #0
    cmp  x0, #0
    bge uo_configured
    cmn  x0, #ENOTTY
    bne uo_close_fail

uo_configured:
    mov  x0, x19
    b    uo_exit

uo_close_fail:
    mov  x0, x19
    mov  x8, #SYS_CLOSE
    svc  #0
uo_fail:
    mov  x0, #-1
uo_exit:
    ldr  x19, [sp, #16]
    ldp  x29, x30, [sp], #80
    ret

uart_read:
    mov  x8, #SYS_READ
    svc  #0
    ret
