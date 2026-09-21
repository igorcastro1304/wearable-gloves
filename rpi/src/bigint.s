.global mw_add128_u32
.global mw_add128

.section .text

mw_add128_u32:
    ldp  x2, x3, [x0]
    mov  w1, w1                
    adds x2, x2, x1            
    adc  x3, x3, xzr
    stp  x2, x3, [x0]
    ret

mw_add128:
    ldp  x2, x3, [x0]
    ldp  x4, x5, [x1]
    adds x2, x2, x4
    adc  x3, x3, x5
    stp  x2, x3, [x0]
    ret
