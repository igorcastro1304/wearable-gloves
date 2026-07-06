.global i2c_setup
.global hid_setup

.section .rodata

i2c_path:
	.asciz "/dev/i2c-1"
hid_path:
	.asciz "/dev/hidg0"

.section .text

i2c_setup:
	stp x29, x30, [sp, #-16]!
	mov x29, sp

	mov w0, #-100
	adrp x1, i2c_path
	add x1, x1, :lo12:i2c_path
	mov w2, #2
	mov w3, #0
	mov x8, #56
	svc #0
	cmp x0, #0
	blt i2c_err
	mov x19, x0

	mov w0, w19
	mov x1, #0x0703
	mov x2, #0x68
	mov x8, #29
	svc #0
	cmp x0, #0
	blt i2c_close_err


	sub sp, sp, #16
	mov w0, #0x6b
	strb w0, [sp]
	mov w0, #0x00
	strb w0, [sp, #1]
	mov w0, w19
	mov x1, sp
	mov x2, #2
	mov x8, #64
	svc #0
	add sp, sp, #16
	cmp x0, #2
	blt i2c_close_err

	mov x0, x19
	b i2c_setup_exit

i2c_close_err:
	mov w0, w19
	mov x8, #57
	svc #0

i2c_err:
	mov x0, #-1

i2c_setup_exit:
	ldp x29, x30, [sp], #16
	ret

hid_setup:
	stp x29, x30, [sp, #-16]!
	mov x29, sp

	mov w0, #-100
	adrp x1, hid_path
	add x1, x1, :lo12:hid_path
	mov w2, #1
	mov w3, #0
	mov x8, #56
	svc #0

	ldp x29, x30, [sp], #16
	ret
