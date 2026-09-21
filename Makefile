# ============================================================================
#   make check       roda TODOS os testes: simulacoes Verilog + teste ARM64 no QEMU
#   make sim         roda todas as simulacoes Verilog (falha se houver [FAIL] ou [TIMEOUT])
#   make sim-uart | sim-debounce | sim-crc | sim-fifo | sim-pkt | sim-lowpass |
#        sim-lowpass-dsp | sim-deadzone | sim-imu       uma simulacao por vez
#   make             compila rpi_hid, fake_fpga e fake_fpga_fast
#   make qemu-test   [PC] teste automatico no QEMU (sem Raspberry Pi), compara com os gabaritos
#   make qemu-show   [PC] relatorios HID do ultimo qemu-test (decimais com sinal)
#   make run         [Pi] executa como root:  make run ARGS=/dev/serial0
#   make test-fifo   [Pi] teste sem FPGA: fake_fpga -> FIFO -> rpi_hid -> /dev/hidg0
#   make deploy      [PC] copia os binarios:   make deploy PI=pi@raspberrypi.local
#   make run-remote  [PC] compila, copia e executa no Pi via ssh
#   make disasm      desmonta o binario
#   make clean
#
# ============================================================================

.DEFAULT_GOAL := all

# ---------------------------------------------------------------- diretorios
FPGA  := fpga
RPI   := rpi
SRC   := $(RPI)/src
INC   := $(RPI)/include
TST   := $(or $(firstword $(wildcard $(RPI)/tst $(RPI)/test)),$(RPI)/tst)
BUILD := $(RPI)/build
SIM   := $(BUILD)/sim

# ---------------------------------------------------------------- toolchain ARM64
ARCH := $(shell uname -m)
ifeq ($(ARCH),aarch64)
CROSS ?=
QEMU  ?=
else
CROSS ?= aarch64-linux-gnu-
QEMU  ?= qemu-aarch64
endif

AS      := $(CROSS)as
LD      := $(CROSS)ld
OBJDUMP := $(CROSS)objdump

ASFLAGS := -g -I $(INC)
LDFLAGS := -z noexecstack

TARGET  := $(BUILD)/rpi_hid
FAKE    := $(BUILD)/fake_fpga
FAST    := $(BUILD)/fake_fpga_fast
MODULES := main uart hid crc bigint proto dispatch motion buttons print sig
OBJS    := $(addprefix $(BUILD)/,$(addsuffix .o,$(MODULES)))
INCS    := $(wildcard $(INC)/*.inc)

FIFO := /tmp/fpga.fifo
ARGS ?=
PI   ?=

# ---------------------------------------------------------------- simulacao Verilog
IV := iverilog -g2005

define RUN_SIM
	$(IV) $(3) -o $(SIM)/$(1).vvp $(2)
	cd $(SIM) && vvp $(1).vvp | tee $(1).log
	@if grep -q -E '\[FAIL\]|\[TIMEOUT\]' $(SIM)/$(1).log; then echo "==> $(1): FALHOU"; exit 1; fi
	@if ! grep -q '\[SIM\]' $(SIM)/$(1).log; then echo "==> $(1): simulacao incompleta (sem linha [SIM])"; exit 1; fi
	@echo "==> $(1): OK"
endef

.PHONY: all check run test-fifo qemu-test qemu-show deploy run-remote disasm clean help \
        sim sim-uart sim-debounce sim-crc sim-fifo sim-pkt sim-lowpass sim-lowpass-dsp sim-deadzone sim-imu

all: $(TARGET) $(FAKE) $(FAST)

check: sim qemu-test
	@echo "check: todos os testes passaram"

help:
	@grep -E '^#   make|^#        sim' $(MAKEFILE_LIST) | sed 's/^# *//'

# ---------------------------------------------------------------- testes Verilog
sim: sim-uart sim-debounce sim-crc sim-fifo sim-pkt sim-lowpass sim-lowpass-dsp sim-deadzone sim-imu
	@echo "sim: todas as simulacoes passaram"

$(SIM):
	mkdir -p $(SIM)

sim-uart: | $(SIM)
	$(call RUN_SIM,uart_tx_tb,$(FPGA)/uart_tx.v $(FPGA)/uart_tx_tb.v)

sim-debounce: | $(SIM)
	$(call RUN_SIM,debounce_tb,$(FPGA)/debounce.v $(FPGA)/debounce_tb.v)

sim-crc: | $(SIM)
	$(call RUN_SIM,crc8_bram_tb,$(FPGA)/crc8_bram.v $(FPGA)/crc8_bram_tb.v)

sim-fifo: | $(SIM)
	$(call RUN_SIM,uart_tx_fifo_tb,$(FPGA)/uart_tx.v $(FPGA)/byte_fifo.v $(FPGA)/uart_tx_fifo.v $(FPGA)/uart_tx_fifo_tb.v)

sim-pkt: | $(SIM)
	$(call RUN_SIM,pkt_sender_tb,$(FPGA)/uart_tx.v $(FPGA)/byte_fifo.v $(FPGA)/uart_tx_fifo.v $(FPGA)/crc8_bram.v $(FPGA)/pkt_sender.v $(FPGA)/pkt_sender_tb.v)

sim-lowpass: | $(SIM)
	$(call RUN_SIM,lowpass_dsp_tb,$(FPGA)/mult18s.v $(FPGA)/lowpass_dsp.v $(FPGA)/lowpass_dsp_tb.v)

sim-lowpass-dsp: | $(SIM)
	$(call RUN_SIM,lowpass_dsp_tb_dsp,$(FPGA)/mult18x18_sim_model.v $(FPGA)/mult18s.v $(FPGA)/lowpass_dsp.v $(FPGA)/lowpass_dsp_tb.v,-Plowpass_dsp_tb.USE_DSP=1)

sim-deadzone: | $(SIM)
	$(call RUN_SIM,deadzone_filter_tb,$(FPGA)/mult18s.v $(FPGA)/deadzone_filter.v $(FPGA)/deadzone_filter_tb.v)

sim-imu: | $(SIM)
	$(call RUN_SIM,imu_interface_tb,$(FPGA)/i2c_master.v $(FPGA)/imu_interface.v $(FPGA)/imu_interface_tb.v)

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/%.o: $(SRC)/%.s $(INCS) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(BUILD)/fake_fpga.o: $(TST)/fake_fpga.s $(INCS) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(BUILD)/fake_fpga_fast.o: $(TST)/fake_fpga.s $(INCS) | $(BUILD)
	$(AS) $(ASFLAGS) --defsym FAKE_ROUNDS=1 --defsym FAKE_DELAY_NS=0 -o $@ $<

$(TARGET): $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

$(FAKE): $(BUILD)/fake_fpga.o
	$(LD) $(LDFLAGS) -o $@ $<

$(FAST): $(BUILD)/fake_fpga_fast.o
	$(LD) $(LDFLAGS) -o $@ $<

qemu-test: all
	$(QEMU) $(FAST) > $(BUILD)/fpga.bin
	: > $(BUILD)/hid.out
	$(QEMU) $(TARGET) $(BUILD)/fpga.bin $(BUILD)/hid.out > $(BUILD)/stats.txt
	od -An -v -tx1 -w4 $(BUILD)/hid.out | sed 's/^ //' > $(BUILD)/hid.hex
	diff -u $(TST)/expected_hid.hex $(BUILD)/hid.hex
	diff -u $(TST)/expected_stats.txt $(BUILD)/stats.txt
	@echo "qemu-test: OK ($$(wc -l < $(BUILD)/hid.hex) relatorios HID conferem com o gabarito)"

qemu-show:
	@echo "buttons   dx   dy  wheel"
	@od -An -v -td1 -w4 $(BUILD)/hid.out

run: $(TARGET)
ifeq ($(ARCH),aarch64)
	sudo $(TARGET) $(ARGS)
else
	@echo "make run so funciona no Raspberry Pi (aarch64). No PC use: make qemu-test ou make run-remote PI=usuario@ip"
endif

test-fifo: all
ifeq ($(ARCH),aarch64)
	rm -f $(FIFO) && mkfifo $(FIFO)
	sudo sh -c '$(TARGET) $(FIFO) & pid=$$!; sleep 1; $(FAKE) > $(FIFO); sleep 1; kill $$pid; wait $$pid'
else
	@echo "make test-fifo so funciona no Raspberry Pi (aarch64). No PC use: make qemu-test"
endif

deploy: all
	@test -n "$(PI)" || (echo "use: make deploy PI=usuario@ip" && false)
	scp $(TARGET) $(FAKE) $(PI):/tmp/

run-remote: deploy
	ssh -t $(PI) "sudo /tmp/rpi_hid $(ARGS)"

disasm: $(TARGET)
	$(OBJDUMP) -d $(TARGET) | less

clean:
	rm -rf $(BUILD)