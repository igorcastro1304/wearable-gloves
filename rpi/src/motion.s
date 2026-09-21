.include "defs.s"

.global motion_update
.global motion_dpi_next
.global odometer

.section .rodata
.balign 4
dpi_table:                          
    .word 128, 256, 384, 512

curve_lut:                          
.include "curve_lut.s"

.section .data
.balign 4
dpi_idx:
    .word 1

.section .bss
.balign 16
hist_x:   .skip 16                  
hist_y:   .skip 16
odometer: .skip 16                  

.section .text

motion_dpi_next:
    adrp x1, dpi_idx
    add  x1, x1, :lo12:dpi_idx
    ldr  w0, [x1]
    add  w0, w0, #1
    and  w0, w0, #3
    str  w0, [x1]
    ret

motion_update:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    stp  x19, x20, [sp, #16]

    mov  w20, w0                    
    mov  w19, w1                    

    adrp x0, hist_x
    add  x0, x0, :lo12:hist_x
    mov  w1, w20
    bl   neon_avg4
    mov  w20, w0
    adrp x0, hist_y
    add  x0, x0, :lo12:hist_y
    mov  w1, w19
    bl   neon_avg4
    mov  w19, w0

    mov  w0, w20
    bl   axis_curve
    mov  w20, w0
    mov  w0, w19
    bl   axis_curve
    mov  w19, w0

    adrp x2, dpi_idx
    add  x2, x2, :lo12:dpi_idx
    ldr  w3, [x2]
    adrp x4, dpi_table
    add  x4, x4, :lo12:dpi_table
    ldr  w2, [x4, x3, lsl #2]
    mov  w0, w20
    mov  w1, w19
    bl   neon_scale_sat         
    mov  w20, w0
    mov  w19, w1

    .if INVERT_X
    neg  w20, w20
    .endif
    .if INVERT_Y
    neg  w19, w19
    .endif

    orr  w4, w20, w19
    cbz  w4, mu_idle

    cmp  w20, #0
    cneg w4, w20, lt
    cmp  w19, #0
    cneg w5, w19, lt
    add  w1, w4, w5
    adrp x0, odometer
    add  x0, x0, :lo12:odometer
    bl   mw_add128_u32

    bl   buttons_get
    mov  w1, w20
    mov  w2, w19
    bl   hid_send_mouse
    b    mu_exit

mu_idle:
    mov  w0, #0
mu_exit:
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret

axis_curve:
    cmp  w0, #0
    cneg w1, w0, lt                
    lsr  w1, w1, #CURVE_SHIFT
    mov  w2, #255
    cmp  w1, w2
    csel w1, w1, w2, ls            
    adrp x3, curve_lut
    add  x3, x3, :lo12:curve_lut
    ldrb w1, [x3, x1]
    cmp  w0, #0                    
    cneg w0, w1, lt
    ret

neon_avg4:
    ldr  q0, [x0]
    fmov s1, w1
    ext  v0.16b, v0.16b, v1.16b, #4     
    str  q0, [x0]
    addv s2, v0.4s                      
    fmov w0, s2
    asr  w0, w0, #2                     
    ret

neon_scale_sat:
    fmov s0, w0
    mov  v0.s[1], w1                    
    dup  v1.2s, w2                      
    mul  v0.2s, v0.2s, v1.2s
    srshr v0.2s, v0.2s, #8              
    sqxtn v0.4h, v0.4s                  
    sqxtn v0.8b, v0.8h                  
    movi v2.8b, #0x81                   
    smax v0.8b, v0.8b, v2.8b            
    smov w0, v0.b[0]
    smov w1, v0.b[1]
    ret
