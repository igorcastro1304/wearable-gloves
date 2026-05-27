// Programa Assembly ARM64 de Teste de Inicialização do Periférico HID
// Projetado para montagem nativa utilizando GCC/GAS no Raspberry Pi OS (Debian 64-bit)
.global _start

.section .data
/* Seção de dados estáticos pré-alocados em memória RAM */
msg_prompt:
   .ascii "Testando Inicializacao do Barramento HID no Raspberry Pi...\n"
len_prompt =. - msg_prompt

.section .text
_start:
    /* Execução da Chamada de Sistema: sys_write (ID #64) */
    mov     x0, #1
    ldr     x1, =msg_prompt
    ldr     x2, =len_prompt
    mov     x8, #64
    svc     #0

    /* Execução da Chamada de Sistema: sys_exit (ID #93) */
    mov     x0, #0
    mov     x8, #93
    svc     #0
