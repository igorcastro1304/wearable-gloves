.extern i2c_setup
.extern hid_setup
.extern movement_processment
.extern axis_cleanup

.section .rodata
timespec_delay:
	.quad 0
	.quad 20000000

.global _start
.section .text

_start:
	bl i2c_setup
	mov x19, x0
	cmp x19, #0
	blt error_exit

	bl hid_setup
	mov x20, x0
	cmp x20, #0
	blt error_exit

	mov x21, #1000

main_loop:
	cbz x21, cleanup_exit

	mov x0, x19
	mov x1, x20
	bl movement_processment
	cmp x0, #0
	blt cleanup_exit

	adrp x0, timespec_delay
	add x0, x0, :lo12:timespec_delay
	mov x1, #0
	mov x8, #101
	svc #0

	sub x21, x21, #1
	b main_loop

cleanup_exit:
	mov x0, x19
	mov x1, x20
	bl axis_cleanup

error_exit:
	mov w0, #0
	mov x8, #93
	svc #0

