.include "defs.s"

.global hid_setup
.global hid_send_mouse
.global hid_close

.section .data
.balign 8
fd_mouse: .quad -1

.section .text

hid_setup:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp

    mov  x1, x0
    mov  x0, #AT_FDCWD
    mov  x2, #O_WRONLY
    mov  x3, #0
    mov  x8, #SYS_OPENAT
    svc  #0
    cmp  x0, #0
    blt  hs_fail
    adrp x1, fd_mouse
    add  x1, x1, :lo12:fd_mouse
    str  x0, [x1]
    mov  x0, #0
    b    hs_exit
hs_fail:
    mov  x0, #-1
hs_exit:
    ldp  x29, x30, [sp], #16
    ret

hid_send_mouse:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp

    strb w0, [sp, #16]
    strb w1, [sp, #17]
    strb w2, [sp, #18]
    strb wzr, [sp, #19]

    adrp x3, fd_mouse
    add  x3, x3, :lo12:fd_mouse
    ldr  x0, [x3]
    cmp  x0, #0
    blt  hsm_err
    add  x1, sp, #16
    mov  x2, #4
    mov  x8, #SYS_WRITE
    svc  #0
    cmp  x0, #4
    bne hsm_err
    mov  x0, #0
    b    hsm_exit
hsm_err:
    mov  x0, #-1
hsm_exit:
    ldp  x29, x30, [sp], #32
    ret

hid_close:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    str  x19, [sp, #16]

    mov  w0, #0
    mov  w1, #0
    mov  w2, #0
    bl   hid_send_mouse

    adrp x19, fd_mouse
    add  x19, x19, :lo12:fd_mouse
    ldr  x0, [x19]
    cmp  x0, #0
    blt  hc_exit
    mov  x8, #SYS_CLOSE
    svc  #0
    mov  x0, #-1
    str  x0, [x19]

hc_exit:
    ldr  x19, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret
