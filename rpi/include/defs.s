// ---- syscalls (Linux arm64) -------------------------------------------------
.equ SYS_IOCTL,        29
.equ SYS_OPENAT,       56
.equ SYS_CLOSE,        57
.equ SYS_READ,         63
.equ SYS_WRITE,        64
.equ SYS_EXIT,         93
.equ SYS_NANOSLEEP,    101
.equ SYS_RT_SIGACTION, 134

// ---- flags / ioctl ------------------------------------------------------------
.equ AT_FDCWD,  -100
.equ O_WRONLY,  0x1
.equ O_RDWR,    0x2
.equ O_NOCTTY,  0x100
.equ TCSETS,    0x5402
// B115200 (0x1002) | CS8 (0x30) | CREAD (0x80) | CLOCAL (0x800)
.equ CFLAGS_115200_8N1, 0x18b2

.equ STDOUT,  1
.equ STDERR,  2
.equ SIGINT,  2
.equ SIGTERM, 15
.equ EINTR,   4
.equ ENOTTY,  25

// ---- protocolo FPGA -> RPi ----------------------------------------------------
// [0xAA][TYPE][LEN][PAYLOAD * LEN][CRC8 sobre TYPE,LEN,PAYLOAD]
.equ PKT_SOF,     0xAA
.equ MAX_PAYLOAD, 32

// estados do parser
.equ ST_SOF,     0
.equ ST_TYPE,    1
.equ ST_LEN,     2
.equ ST_PAYLOAD, 3
.equ ST_CRC,     4

// layout do contexto do parser (bytes)
.equ CTX_STATE,   0
.equ CTX_TYPE,    4
.equ CTX_LEN,     8
.equ CTX_IDX,     12
.equ CTX_CRC,     16
.equ CTX_PAYLOAD, 24
.equ CTX_SIZE,    64

// ---- movimento do cursor --------------------------------------------------------
.equ CURVE_SHIFT, 7        // bucket da curva = |v| >> 7
.equ INVERT_X,    0        // 1 = inverte o sentido do eixo X
.equ INVERT_Y,    1        // 1 = inverte o sentido do eixo Y