#!/usr/bin/bash
set -euo pipefail

# Script para criar secrets do Kubernetes de forma segura
# Uso: ./scripts/create-secrets.sh [all]
# Se nenhum argumento for fornecido, cria todos os secrets disponíveis

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Carrega variáveis de ambiente
if [[ -f "${ROOT_DIR}/.env" ]]; then
    set -a
    source "${ROOT_DIR}/.env"
    set +a
fi

COMPONENT="${1:-all}"

echo "[secrets] Criando secrets do Kubernetes para componente: ${COMPONENT}..."

# Verifica se o cluster está rodando
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "[error] kubectl não consegue conectar ao cluster. Verifique o kubeconfig."
    exit 1
fi

case "${COMPONENT}" in
    "all")
        echo "[secrets] Criando todos os secrets disponíveis..."
        echo "[info] Nenhum secret específico configurado para este ambiente básico."
        ;;
    *)
        echo "[error] Componente inválido: ${COMPONENT}"
        echo "Uso: $0 [all]"
        exit 1
        ;;
esac

echo "[ok] Secrets criados com sucesso!"
