#!/usr/bin/env bash

set -euo pipefail

# Diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Raiz do projeto
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MAKEFILE="${PROJECT_ROOT}/makefiles/Multiplier/Makefile"

if [[ ! -f "${MAKEFILE}" ]]; then
    echo "ERRO: Makefile não encontrado:"
    echo "  ${MAKEFILE}"
    exit 1
fi

# Repassa os argumentos para o make
make -f "${MAKEFILE}" "$@"