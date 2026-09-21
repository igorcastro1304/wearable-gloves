.include "defs.s"

.global _start

.section .rodata
default_uart:  .asciz "/dev/serial0"
default_hid:   .asciz "/dev/hidg0"
msg_start:     .asciz "[rpi] aguardando pacotes do FPGA (Ctrl+C encerra)...\n"
msg_ok:        .asciz "pacotes_ok    = 0x"
msg_crc:       .asciz "pacotes_crc   = 0x"
msg_total:     .asciz "pacotes_total = 0x"
msg_odo:       .asciz "odometro      = 0x"
msg_err_uart:  .asciz "[rpi] erro: nao consegui abrir/configurar a serial\n"
msg_err_hid:   .asciz "[rpi] erro: nao consegui abrir /dev/hidg0 (gadget HID ativo? rode como root)\n"

.section .bss
.balign 16
rx_buf:     .skip 64
pkt_ctx:    .skip CTX_SIZE
stat_ok:    .skip 16
stat_crc:   .skip 16
stat_total: .skip 16

.section .text

_start:
    ldr  x9, [sp]
    adrp x25, default_uart
    add  x25, x25, :lo12:default_uart
    adrp x26, default_hid
    add  x26, x26, :lo12:default_hid
    cmp  x9, #2
    blt args_done
    ldr  x25, [sp, #16]             
    cmp  x9, #3
    blt args_done
    ldr  x26, [sp, #24]             
args_done:

    bl   sig_setup

    mov  x0, x25
    bl   uart_open
    cmp  x0, #0
    blt  fail_uart
    mov  x19, x0

    mov  x0, x26
    bl   hid_setup
    cmp  x0, #0
    blt  fail_hid

    adrp x22, pkt_ctx
    add  x22, x22, :lo12:pkt_ctx
    mov  x0, x22
    bl   proto_reset

    mov  x0, #STDOUT
    adrp x1, msg_start
    add  x1, x1, :lo12:msg_start
    bl   print_cstr

main_loop:
    adrp x0, stop_flag
    add  x0, x0, :lo12:stop_flag
    ldr  w1, [x0]
    cbnz w1, shutdown

    mov  x0, x19
    adrp x1, rx_buf
    add  x1, x1, :lo12:rx_buf
    mov  x2, #64
    bl   uart_read
    cmp  x0, #0
    bgt process
    beq shutdown                  
    cmn  x0, #EINTR                
    beq main_loop
    b    shutdown                 

process:
    mov  x23, x0
    adrp x24, rx_buf
    add  x24, x24, :lo12:rx_buf

byte_loop:
    cbz  x23, main_loop
    ldrb w1, [x24], #1
    sub  x23, x23, #1
    mov  x0, x22
    bl   proto_feed
    cmp  w0, #1
    beq packet_ok
    cmp  w0, #2
    beq packet_crc
    b    byte_loop

packet_ok:
    adrp x0, stat_ok
    add  x0, x0, :lo12:stat_ok
    mov  w1, #1
    bl   mw_add128_u32
    mov  x0, x22
    bl   dispatch_packet
    b    byte_loop

packet_crc:
    adrp x0, stat_crc
    add  x0, x0, :lo12:stat_crc
    mov  w1, #1
    bl   mw_add128_u32
    b    byte_loop

shutdown:
    bl   hid_close
    mov  x0, x19
    mov  x8, #SYS_CLOSE
    svc  #0

    adrp x0, stat_total
    add  x0, x0, :lo12:stat_total
    adrp x1, stat_ok
    add  x1, x1, :lo12:stat_ok
    ldp  x2, x3, [x1]
    stp  x2, x3, [x0]
    adrp x1, stat_crc
    add  x1, x1, :lo12:stat_crc
    bl   mw_add128

    mov  x0, #STDOUT
    adrp x1, msg_ok
    add  x1, x1, :lo12:msg_ok
    bl   print_cstr
    adrp x0, stat_ok
    add  x0, x0, :lo12:stat_ok
    mov  w1, #STDOUT
    bl   print_hex128

    mov  x0, #STDOUT
    adrp x1, msg_crc
    add  x1, x1, :lo12:msg_crc
    bl   print_cstr
    adrp x0, stat_crc
    add  x0, x0, :lo12:stat_crc
    mov  w1, #STDOUT
    bl   print_hex128

    mov  x0, #STDOUT
    adrp x1, msg_total
    add  x1, x1, :lo12:msg_total
    bl   print_cstr
    adrp x0, stat_total
    add  x0, x0, :lo12:stat_total
    mov  w1, #STDOUT
    bl   print_hex128

    mov  x0, #STDOUT
    adrp x1, msg_odo
    add  x1, x1, :lo12:msg_odo
    bl   print_cstr
    adrp x0, odometer
    add  x0, x0, :lo12:odometer
    mov  w1, #STDOUT
    bl   print_hex128

    mov  x0, #0
    b    do_exit

fail_hid:
    mov  x0, x19
    mov  x8, #SYS_CLOSE
    svc  #0
    mov  x0, #STDERR
    adrp x1, msg_err_hid
    add  x1, x1, :lo12:msg_err_hid
    bl   print_cstr
    mov  x0, #2
    b    do_exit

fail_uart:
    mov  x0, #STDERR
    adrp x1, msg_err_uart
    add  x1, x1, :lo12:msg_err_uart
    bl   print_cstr
    mov  x0, #1

do_exit:
    mov  x8, #SYS_EXIT
    svc  #0
