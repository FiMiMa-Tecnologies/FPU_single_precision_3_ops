# -----------------------------------------------------------------------------
# FPU Exponent Calculator - Icarus Verilog
# Localização:
#   <projeto>/makefiles/exp_calc/Makefile
# -----------------------------------------------------------------------------

# Diretório deste Makefile e raiz do projeto
MAKEFILE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PROJECT_ROOT := $(abspath $(MAKEFILE_DIR)/../..)

# Diretórios do bloco
SRC_DIR     := $(PROJECT_ROOT)/src/exp_calc
BUILD_DIR   := $(PROJECT_ROOT)/build/exp_calc
RESULTS_DIR := $(PROJECT_ROOT)/results/exp_calc

# Arquivos do bloco Exp Calc
SRC      := $(SRC_DIR)/fpu_exp_calc.v
TB       := $(SRC_DIR)/tesbench.sv
TARGET   := $(BUILD_DIR)/exp_calc_tb.vvp
LOG_FILE := $(RESULTS_DIR)/exp_calc.log

# Ferramentas
IVERILOG := iverilog
VVP      := vvp

.PHONY: all run compile check clean help

# Regra padrão: compila e executa
all: run

# Executa a simulação
run: $(TARGET)
	@mkdir -p "$(RESULTS_DIR)"
	@echo "[RUN] Executando simulação do FPU Exp Calc..."
	@echo "[LOG] Salvando resultado em:"
	@echo "      $(LOG_FILE)"
	@cd "$(BUILD_DIR)" && $(VVP) "$(TARGET)" > "$(LOG_FILE)"
	@cat "$(LOG_FILE)"

# Apenas compila
compile: $(TARGET)

# Compilação com Icarus Verilog
$(TARGET): check $(SRC) $(TB)
	@mkdir -p "$(BUILD_DIR)"
	@echo "[IVERILOG] Compilando fpu_exp_calc.v + tesbench.sv..."
	$(IVERILOG) -Wall -g2012 -o "$(TARGET)" "$(SRC)" "$(TB)"

# Verifica se os arquivos necessários existem
check:
	@test -f "$(SRC)" || { \
		echo "ERRO: RTL do Exp Calc não encontrado:"; \
		echo "  $(SRC)"; \
		exit 1; \
	}

	@test -f "$(TB)" || { \
		echo "ERRO: testbench não encontrado:"; \
		echo "  $(TB)"; \
		exit 1; \
	}

# Remove somente os artefatos gerados para o Exp Calc
clean:
	@echo "[CLEAN] Removendo $(BUILD_DIR)"
	@rm -rf "$(BUILD_DIR)"

# Ajuda
help:
	@echo "FPU Exp Calc - comandos disponíveis:"
	@echo "  make -f $(MAKEFILE_DIR)/Makefile          # compila e executa"
	@echo "  make -f $(MAKEFILE_DIR)/Makefile compile  # apenas compila"
	@echo "  make -f $(MAKEFILE_DIR)/Makefile run      # compila se necessário e executa"
	@echo "  make -f $(MAKEFILE_DIR)/Makefile clean    # limpa os artefatos"
	@echo ""
	@echo "Log da última simulação:"
	@echo "  $(LOG_FILE)"
	@echo ""
	@echo "Recomendado: usar scripts/exp_calc/exp_calc.sh"