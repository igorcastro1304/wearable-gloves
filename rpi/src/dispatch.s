.include "defs.s"

.global dispatch_packet

.section .rodata
.balign 8
jump_table:
    .quad handle_move
    .quad handle_btn                
    .quad handle_hand               
    .quad handle_dpi                
    .quad handle_unknown            

type_lut:
    //    B  C  D  E  F  G  H  I  J  K  L  M
    .byte 1, 4, 3, 4, 4, 4, 2, 4, 4, 4, 4, 0

.section .text
dispatch_packet:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    str  x19, [sp, #16]
    mov  x19, x0

    ldr  w1, [x19, #CTX_TYPE]
    mov  w3, #4                     
    sub  w2, w1, #0x42
    cmp  w2, #11
    bhi dp_jump                    
    adrp x4, type_lut
    add  x4, x4, :lo12:type_lut
    ldrb w3, [x4, x2]

dp_jump:
    adrp x4, jump_table
    add  x4, x4, :lo12:jump_table
    ldr  x5, [x4, x3, lsl #3]
    mov  x0, x19
    blr  x5

    ldr  x19, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret

handle_move:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp
    ldr  w1, [x0, #CTX_LEN]
    cmp  w1, #8
    bne hm_bad
    ldr  w2, [x0, #CTX_PAYLOAD]
    ldr  w1, [x0, #(CTX_PAYLOAD + 4)]
    mov  w0, w2
    bl   motion_update              
    b    hm_exit
hm_bad:
    mov  w0, #-1
hm_exit:
    ldp  x29, x30, [sp], #16
    ret

handle_btn:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp
    ldr  w1, [x0, #CTX_LEN]
    cmp  w1, #1
    bne hb_bad
    ldrb w0, [x0, #CTX_PAYLOAD]
    bl   buttons_set_phys
    b    hb_exit
hb_bad:
    mov  w0, #-1
hb_exit:
    ldp  x29, x30, [sp], #16
    ret

handle_hand:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp
    ldr  w1, [x0, #CTX_LEN]
    cmp  w1, #1
    bne hh_bad
    ldrb w0, [x0, #CTX_PAYLOAD]
    bl   buttons_set_hand
    b    hh_exit
hh_bad:
    mov  w0, #-1
hh_exit:
    ldp  x29, x30, [sp], #16
    ret

handle_dpi:
    stp  x29, x30, [sp, #-16]!
    mov  x29, sp
    ldr  w1, [x0, #CTX_LEN]
    cmp  w1, #1
    bne hd_bad
    bl   motion_dpi_next
    mov  w0, #0
    b    hd_exit
hd_bad:
    mov  w0, #-1
hd_exit:
    ldp  x29, x30, [sp], #16
    ret

handle_unknown:
    mov  w0, #-1
    ret
