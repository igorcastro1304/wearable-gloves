.include "defs.s"

.global proto_reset
.global proto_feed

.section .text

proto_reset:
    stp  xzr, xzr, [x0]          
    str  wzr, [x0, #CTX_CRC]
    ret

proto_feed:
    stp  x29, x30, [sp, #-32]!
    mov  x29, sp
    stp  x19, x20, [sp, #16]
    mov  x19, x0                    
    mov  w20, w1                    

    ldr  w2, [x19, #CTX_STATE]
    cmp  w2, #ST_SOF
    beq pf_sof
    cmp  w2, #ST_TYPE
    beq pf_type
    cmp  w2, #ST_LEN
    beq pf_len
    cmp  w2, #ST_PAYLOAD
    beq pf_payload
    cmp  w2, #ST_CRC
    beq pf_crc
    b    pf_resync                  

pf_sof:
    cmp  w20, #PKT_SOF
    bne pf_more
    mov  w2, #ST_TYPE
    str  w2, [x19, #CTX_STATE]
    b    pf_more

pf_type:
    cmp  w20, #PKT_SOF
    beq pf_more                   
    str  w20, [x19, #CTX_TYPE]
    mov  w0, #0                    
    mov  w1, w20
    bl   crc8_update
    str  w0, [x19, #CTX_CRC]
    mov  w2, #ST_LEN
    str  w2, [x19, #CTX_STATE]
    b    pf_more

pf_len:
    cmp  w20, #MAX_PAYLOAD
    bhi pf_len_bad                 
    str  w20, [x19, #CTX_LEN]
    str  wzr, [x19, #CTX_IDX]
    ldr  w0, [x19, #CTX_CRC]
    mov  w1, w20
    bl   crc8_update
    str  w0, [x19, #CTX_CRC]
    mov  w2, #ST_PAYLOAD
    cbnz w20, pf_len_store          
    mov  w2, #ST_CRC             
pf_len_store:
    str  w2, [x19, #CTX_STATE]
    b    pf_more

pf_len_bad:                        
    mov  w2, #ST_SOF
    cmp  w20, #PKT_SOF
    bne pf_len_bad_store
    mov  w2, #ST_TYPE
pf_len_bad_store:
    str  w2, [x19, #CTX_STATE]
    b    pf_more

pf_payload:
    ldr  w3, [x19, #CTX_IDX]
    add  x4, x19, #CTX_PAYLOAD
    strb w20, [x4, x3]
    add  w3, w3, #1
    str  w3, [x19, #CTX_IDX]
    ldr  w0, [x19, #CTX_CRC]
    mov  w1, w20
    bl   crc8_update
    str  w0, [x19, #CTX_CRC]
    ldr  w3, [x19, #CTX_IDX]      
    ldr  w4, [x19, #CTX_LEN]
    cmp  w3, w4
    blo pf_more
    mov  w2, #ST_CRC
    str  w2, [x19, #CTX_STATE]
    b    pf_more

pf_crc:
    mov  w2, #ST_SOF               
    str  w2, [x19, #CTX_STATE]
    ldr  w3, [x19, #CTX_CRC]
    cmp  w20, w3
    bne pf_bad
    mov  w0, #1
    b    pf_exit
pf_bad:
    mov  w0, #2
    b    pf_exit

pf_resync:
    mov  w2, #ST_SOF
    str  w2, [x19, #CTX_STATE]
pf_more:
    mov  w0, #0
pf_exit:
    ldp  x19, x20, [sp, #16]
    ldp  x29, x30, [sp], #32
    ret
