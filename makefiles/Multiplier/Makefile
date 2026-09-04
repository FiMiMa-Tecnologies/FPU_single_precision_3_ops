# -----------------------------------------------------------------------------
# FPU Multiplier - Icarus Verilog
# Localização:
#   <projeto>/makefiles/Multiplier/Makefile
# -----------------------------------------------------------------------------

# Diretório deste Makefile e raiz do projeto
MAKEFILE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PROJECT_ROOT := $(abspath $(MAKEFILE_DIR)/../..)

# Diretórios do bloco
SRC_DIR   := $(PROJECT_ROOT)/src/multiplier
BUILD_DIR := $(PROJECT_ROOT)/build/multiplier

# Arquivos do bloco Multiplier
SRC    := $(SRC_DIR)/fpu_mult.v
TB     := $(SRC_DIR)/testbench.sv
TARGET := $(BUILD_DIR)/mult_tb.vvp

# Ferramentas
IVERILOG := iverilog
VVP      := vvp

.PHONY: all run compile check clean help

# Regra padrão: compila e executa
all: run

# Executa a simulação
run: $(TARGET)
	@echo "[RUN] Executando simulação do Multiplier..."
	@cd "$(BUILD_DIR)" && $(VVP) "$(TARGET)"

# Apenas compila
compile: $(TARGET)

# Compilação com Icarus Verilog
$(TARGET): check $(SRC) $(TB)
	@mkdir -p "$(BUILD_DIR)"
	@echo "[IVERILOG] Compilando fpu_mult.v + testbench.sv..."
	$(IVERILOG) -Wall -g2012 -o "$(TARGET)" "$(SRC)" "$(TB)"

# Verifica se os arquivos necessários existem
check:
	@test -f "$(SRC)" || { \
		echo "ERRO: RTL do multiplicador não encontrado:"; \
		echo "  $(SRC)"; \
		exit 1; \
	}

	@test -f "$(TB)" || { \
		echo "ERRO: testbench não encontrado:"; \
		echo "  $(TB)"; \
		exit 1; \
	}

# Remove somente os artefatos gerados para o Multiplier
clean:
	@echo "[CLEAN] Removendo $(BUILD_DIR)"
	@rm -rf "$(BUILD_DIR)"

# Ajuda
help:
	@echo "FPU Multiplier - comandos disponíveis:"
	@echo "  make -f $(MAKEFILE_DIR)/Makefile          # compila e executa"
	@echo "  make -f $(MAKEFILE_DIR)/Makefile compile  # apenas compila"
	@echo "  make -f $(MAKEFILE_DIR)/Makefile run      # compila se necessário e executa"
	@echo "  make -f $(MAKEFILE_DIR)/Makefile clean    # limpa os artefatos"
	@echo ""
	@echo "Recomendado: usar scripts/mult.sh"