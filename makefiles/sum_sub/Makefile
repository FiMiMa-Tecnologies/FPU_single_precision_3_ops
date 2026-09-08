# Simulacao do fpu_sum_sub com Icarus Verilog.
SHELL := /bin/bash
.SHELLFLAGS := -e -o pipefail -c
.DEFAULT_GOAL := run
.DELETE_ON_ERROR:

MAKEFILE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PROJECT_ROOT := $(abspath $(MAKEFILE_DIR)/../..)
SRC_DIR := $(PROJECT_ROOT)/src/sum_sub
BUILD_DIR := $(PROJECT_ROOT)/build/sum_sub
RESULTS_DIR := $(PROJECT_ROOT)/results/sum_sub

SRC := $(SRC_DIR)/fpu_sum_sub.v
TB := $(PROJECT_ROOT)/testbenchs/sum_sub/fpu_sum_sub_tb.v
TARGET := $(BUILD_DIR)/sum_sub_tb.vvp
LOG_FILE := $(RESULTS_DIR)/sum_sub.log

IVERILOG ?= iverilog
VVP ?= vvp

.PHONY: all compile run clean help
all: run

compile: $(TARGET)

$(TARGET): $(SRC) $(TB) $(MAKEFILE_DIR)/Makefile
	@mkdir -p "$(BUILD_DIR)"
	$(IVERILOG) -g2012 -s fpu_sum_sub_tb -o "$@" $(foreach file,$(TB) $(SRC),"$(file)")

# Preserva o codigo de saida do simulador enquanto salva e exibe o log.
run: $(TARGET)
	@mkdir -p "$(RESULTS_DIR)"
	@echo "[RUN] fpu_sum_sub: log em $(LOG_FILE)"
	@cd "$(RESULTS_DIR)" && $(VVP) "$(TARGET)" 2>&1 | tee "$(LOG_FILE)"

clean:
	$(RM) "$(TARGET)" "$(LOG_FILE)"

help:
	@echo "make -f $(MAKEFILE_DIR)/Makefile [run|compile|clean|help]"
	@echo "run (padrao): compila e executa o testbench de soma e subtracao."
	@echo "compile: apenas compila; clean: remove os artefatos deste teste."
	@echo "Log: $(LOG_FILE)"
