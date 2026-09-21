.include "defs.s"

.global crc8_update

.section .rodata
crc8_table:
.include "crc8_table.s"

.section .text

crc8_update:
    eor  w0, w0, w1
    and  w0, w0, #0xff
    adrp x2, crc8_table
    add  x2, x2, :lo12:crc8_table
    ldrb w0, [x2, x0]
    ret
