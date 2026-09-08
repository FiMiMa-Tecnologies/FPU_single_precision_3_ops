#!/usr/bin/env bash

set -euo pipefail

# Diretório onde este script está localizado:
# <projeto>/scripts/norm
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Retorna dois níveis para alcançar a raiz do projeto
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

MAKEFILE="${PROJECT_ROOT}/makefiles/norm/Makefile"

if [[ ! -f "${MAKEFILE}" ]]; then
    echo "ERRO: Makefile do Mult Norm não encontrado:"
    echo "  ${MAKEFILE}"
    exit 1
fi

# Encaminha qualquer alvo/argumento diretamente ao Makefile
exec make -f "${MAKEFILE}" "$@"
