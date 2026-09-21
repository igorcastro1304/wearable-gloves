.include "defs.s"

.global buttons_set_phys
.global buttons_set_hand
.global buttons_get

.section .rodata
btn_map_lut:
    .byte 0, 1, 2, 3, 0, 2, 1, 3

.section .bss
.balign 4
btn_state:
    .skip 4

.section .text

buttons_set_phys:
    and  w0, w0, #3
    adrp x1, btn_state
    add  x1, x1, :lo12:btn_state
    strb w0, [x1, #0]
    b    buttons_refresh

buttons_set_hand:
    and  w0, w0, #1
    adrp x1, btn_state
    add  x1, x1, :lo12:btn_state
    strb w0, [x1, #1]
    b    buttons_refresh     

buttons_get:
    adrp x1, btn_state
    add  x1, x1, :lo12:btn_state
    ldrb w0, [x1, #2]
    ret

buttons_refresh:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp

    adrp x3, btn_state
    add  x3, x3, :lo12:btn_state
    ldrb w4, [x3, #2]            
    ldrb w0, [x3, #0]            
    ldrb w1, [x3, #1]              
    orr  w0, w0, w1, lsl #2        
    adrp x2, btn_map_lut
    add  x2, x2, :lo12:btn_map_lut
    ldrb w0, [x2, x0]
    strb w0, [x3, #2]
    cmp  w0, w4
    beq br_same

    mov  w1, #0                    
    mov  w2, #0                    
    bl   hid_send_mouse
    b    br_exit
br_same:
    mov  w0, #0
br_exit:
    ldp  x29, x30, [sp], #16
    ret
