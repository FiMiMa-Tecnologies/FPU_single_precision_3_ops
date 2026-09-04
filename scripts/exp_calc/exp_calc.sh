#!/usr/bin/env bash

set -euo pipefail

# Diretório onde este script está localizado:
# <projeto>/scripts/exp_calc
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Retorna dois níveis para alcançar a raiz do projeto
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

MAKEFILE="${PROJECT_ROOT}/makefiles/exp_calc/Makefile"

if [[ ! -f "${MAKEFILE}" ]]; then
    echo "ERRO: Makefile do Exp Calc não encontrado:"
    echo "  ${MAKEFILE}"
    exit 1
fi

# Encaminha qualquer alvo/argumento diretamente ao Makefile
exec make -f "${MAKEFILE}" "$@"
