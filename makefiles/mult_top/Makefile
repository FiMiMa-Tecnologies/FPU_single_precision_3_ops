# Simulacao dos 100000 casos aleatorios do fpu_mult_top com Icarus Verilog.
SHELL := /bin/bash
.SHELLFLAGS := -e -o pipefail -c
.DEFAULT_GOAL := run
.DELETE_ON_ERROR:

MAKEFILE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PROJECT_ROOT := $(abspath $(MAKEFILE_DIR)/../..)
SRC_DIR := $(PROJECT_ROOT)/src/multiplier
BUILD_DIR := $(PROJECT_ROOT)/build/mult_top
RESULTS_DIR := $(PROJECT_ROOT)/results/mult_top

SRC := $(SRC_DIR)/fpu_mult_top.v \
       $(SRC_DIR)/fpu_mult_24x24.v \
       $(SRC_DIR)/fpu_mult_exp_calc.v \
       $(SRC_DIR)/fpu_mult_norm.v \
       $(SRC_DIR)/fpu_mult_signal.v
TB := $(PROJECT_ROOT)/testbenchs/mult_top/testbench.sv
TARGET := $(BUILD_DIR)/mult_top_tb.vvp
LOG_FILE := $(RESULTS_DIR)/mult_top.log
VCD_FILE := $(RESULTS_DIR)/mult_top.vcd

IVERILOG ?= iverilog
VVP ?= vvp

.PHONY: all compile run clean help
all: run

compile: $(TARGET)

$(TARGET): $(SRC) $(TB) $(MAKEFILE_DIR)/Makefile
	@mkdir -p "$(BUILD_DIR)"
	$(IVERILOG) -g2012 -s testbench -o "$@" $(foreach file,$(TB) $(SRC),"$(file)")

# pipefail preserva a falha do testbench mesmo usando tee para salvar o log.
run: $(TARGET)
	@mkdir -p "$(RESULTS_DIR)"
	@echo "[RUN] fpu_mult_top: log em $(LOG_FILE)"
	@cd "$(RESULTS_DIR)" && $(VVP) "$(TARGET)" 2>&1 | tee "$(LOG_FILE)"

clean:
	$(RM) "$(TARGET)" "$(LOG_FILE)" "$(VCD_FILE)"

help:
	@echo "make -f $(MAKEFILE_DIR)/Makefile [run|compile|clean|help]"
	@echo "run (padrao): compila e simula os 100000 casos aleatorios."
	@echo "compile: apenas compila; clean: remove os artefatos deste teste."
	@echo "Log: $(LOG_FILE)"
	@echo "Formas de onda: $(VCD_FILE)"
