# -----------------------------------------------------------------------------
# Multiplier - Icarus Verilog
# Localização:
#   <projeto>/makefiles/Multiplier/Makefile
# -----------------------------------------------------------------------------

# Caminhos do projeto
MAKEFILE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PROJECT_ROOT := $(abspath $(MAKEFILE_DIR)/../..)
SRC_DIR      := $(PROJECT_ROOT)/src/$(PROJECT_NAME)
BUILD_DIR    := $(PROJECT_ROOT)/build/$(PROJECT_NAME)

# Edite aqui:
PROJECT_NAME := Multiplier

# Arquivos
SRC       := $(SRC_DIR)/multiplier.v
TB       ?= $(SRC_DIR)/testbench.sv
TARGET    := $(BUILD_DIR)/tb.vvp

# Ferramentas
IVERILOG := iverilog
VVP      := vvp

.PHONY: all run compile check clean help

# Compila e executa
all: run

# Executa a simulação
run: $(TARGET)
	@echo "[RUN] Executando $(TARGET)"
	@cd "$(BUILD_DIR)" && $(VVP) "$(TARGET)"

# Apenas compila
compile: $(TARGET)

# Compilação com Icarus Verilog
$(TARGET): check
	@mkdir -p "$(BUILD_DIR)"
	@echo "[IVERILOG] Compilando multiplier.v + testbench.sv..."
	$(IVERILOG) -Wall -g2012 -o "$(TARGET)" "$(SRC)" "$(TB)"

# Verifica os arquivos
check:
	@test -f "$(SRC)" || { \
		echo "ERRO: arquivo RTL não encontrado:"; \
		echo "  $(SRC)"; \
		exit 1; \
	}

	@test -f "$(TB)" || { \
		echo "ERRO: testbench não encontrado:"; \
		echo "  $(TB)"; \
		echo "Crie/mova o testbench para src/multiplier/testbench.sv"; \
		exit 1; \
	}

# Limpeza
clean:
	@echo "[CLEAN] Removendo $(BUILD_DIR)"
	@rm -rf "$(BUILD_DIR)"

help:
	@echo "Uso:"
	@echo "  make -f $(MAKEFILE_DIR)/Makefile"
	@echo "  make -f $(MAKEFILE_DIR)/Makefile compile"
	@echo "  make -f $(MAKEFILE_DIR)/Makefile clean"
	@echo ""
	@echo "Ou utilize scripts/multiplier.sh"