#!/usr/bin/env bash

set -euo pipefail

# Diretório onde este script está localizado
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# scripts/ fica diretamente abaixo da raiz do projeto
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MAKEFILE="${PROJECT_ROOT}/makefiles/Multiplier/Makefile"

if [[ ! -f "${MAKEFILE}" ]]; then
    echo "ERRO: Makefile do Multiplier não encontrado:"
    echo "  ${MAKEFILE}"
    exit 1
fi

# Encaminha qualquer alvo/argumento diretamente ao Makefile
exec make -f "${MAKEFILE}" "$@"