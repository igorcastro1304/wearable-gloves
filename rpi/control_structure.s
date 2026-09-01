.global _start

.section .data
command_buffer: .byte 'M', 'K', 'D', 'X' //M = Mouse, K = Keyboard, D = DPI, X = Unknown

.section .text
_start:
    mov x19, #0
    mov x20, #4

    for_loop:
        cmp x19, x20
        bge for_loop_end

        adrp x21, command_buffer
        add x21, x21, :lo12:command_buffer
        ldrb w0, [x21, x19]

        bl parse_command_routine

        add x19, x19, #1
        b for_loop

    for_loop_end:
        mov w0, #150

        cmp w0, #200
        ble check_elseif

        mov w1, #3
        b if_end

    check_elseif:
        cmp w0, #50
        ble check_else

        mov w1, #2
        b if_end

    check_else:
        mov w1, #1

    if_end:
        mov w0, #0
        mov x0, #93
        svc #0

    parse_command_routine:
        stp x29, x30, [sp, #-16]!

        cmp w0, #'M'
        beq cmd_mouse_id
        cmp w0, #'K'
        beq cmd_key_id
        cmp w0, #'D'
        beq cmd_dpi_id
        b cmd_default

    cmd_mouse_id:
        mov x1, #0
        b execute_jump
    
    cmd_key_id:
        mov x1, #1
        b execute_jump
    
    cmd_dpi_id:
        mov x1, #2
        b execute_jump

    execute_jump:
        cmp x1, #2
        bhi cmd_default

        adr x2, jump_table
        ldr x3, [x2, x1, lsl #3]
        br x3

    .align 3
    jump_table:
        .quad handler_mouse
        .quad handler_keyboard
        .quad handler_dpi

    handler_mouse:
        mov w10, #0x01
        b parse_exit

    handler_keyboard:
        mov w10, #0x02
        b parse_exit

    handler_dpi:
        mov w10, #0x03
        b parse_exit
    
    cmd_default:
        mov w10, #0xFF

    parse_exit:
        ldp x29, x30, [sp], #16
        ret