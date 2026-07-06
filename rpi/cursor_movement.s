.global movement_processment
.global axis_cleanup

.section .bss

.lcomm sensor_buf, 6
.lcomm hid_buf, 4

.section .text

movement_processment:
	stp x29, x30, [sp, #-32]!
	stp x19, x20, [sp, #16]
	mov x29, sp

	mov x19, x0
	mov x20, x1

	sub sp, sp, #16
	mov w0, #0x3b
	strb w0, [sp]
	mov w0, w19
	mov x1, sp
	mov x2, #1
	mov x9, #64
	svc #0
	add sp, sp, #16
	cmp x0, #1
	blt read_err

	adrp x21, sensor_buf
	add x21, x21, :lo12:sensor_buf
	mov w0, w19
	mov x1, x21
	mov x2, #6
	mov x8, #63
	svc #0
	cmp x0, #6
	blt read_err

	ldrb w22, [x21, #0]
	ldrb w23, [x21, #1]
	lsl w22, w22, #8
	orr w22, w22, w23
	sxth w22, w22

	ldrb w24, [x21, #2]
	ldrb w25, [x21, #3]
	lsl w24, w24, #8
	orr w24, w24, w25
	sxth w24, w24

	asr w22, w22, #9
	asr w24, w24, #9

	neg w24, w24

	cmp w22, #127
	ble check_min_x
	mov w22, #127

check_min_x:
	cmp w22, #-127
	bge check_max_y
	mov w22, #127

check_max_y:
	cmp w24, #127
	ble check_min_y
	mov w24, #127

check_min_y:
	cmp w24, #-127
	bge format_report
	mov w24, #-127

format_report:
	adrp x25, hid_buf
	add x25, x25, :lo12:hid_buf
	mov w26, #0
	strb w26, [x25, #0]
	strb w22, [x25, #1]
	strb w24, [x25, #2]
	strb w26, [x25, #3]

	mov w0, w20
	mov x1, x25
	mov x2, #4
	mov x8, #64
	svc #0
	cmp x0, #4
	blt read_err

	mov x0, #0
	b read_exit

read_err:
	mov x0, #-1

read_exit:
	ldp x19, x20, [sp, #16]
	ldp x29, x30, [sp], #32
	ret

axis_cleanup:
	stp x29, x30, [sp, #-32]!
	stp x19, x20, [sp, #16]
	mov x29, sp

	mov x19, x0
	mov x20, x1

	adrp x21, hid_buf
	add x21, x21, :lo12:hid_buf
	mov w22, #0
	strb w22, [x21, #0]
	strb w22, [x21, #1]
	strb w22, [x21, #2]
	strb w22, [x21, #3]

	mov w0, w20
	mov x1, x21
	mov x2, #4
	mov x8, #64
	svc #0

	mov w0, w20
	mov x8, #57
	svc #0

	mov w0, w19
	mov x8, #57
	svc #0

	ldp x19, x20, [sp, #16]
	ldp x29, x30, [sp], #32
	ret
