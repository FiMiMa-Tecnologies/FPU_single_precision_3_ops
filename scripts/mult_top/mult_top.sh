#!/usr/bin/env bash

set -euo pipefail

# Resolve a raiz do projeto independentemente do diretorio de execucao.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MAKEFILE="${PROJECT_ROOT}/makefiles/mult_top/Makefile"

if [[ ! -f "${MAKEFILE}" ]]; then
    echo "ERRO: Makefile do fpu_mult_top nao encontrado:"
    echo "  ${MAKEFILE}"
    exit 1
fi

# Sem argumentos, compila e simula. Aceita compile, run, clean e help.
exec make -f "${MAKEFILE}" "$@"
