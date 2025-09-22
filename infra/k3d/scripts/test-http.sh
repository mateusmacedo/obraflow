#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Carrega e exporta variáveis de ambiente se o arquivo .env existir
if [[ -f "${ROOT_DIR}/.env" ]]; then
    set -a  # automatically export all variables
    source "${ROOT_DIR}/.env"
    set +a
fi

# Exporta variáveis padrão se não estiverem definidas
export RANCHER_HOSTNAME="${RANCHER_HOSTNAME:-rancher-dev.sslip.io}"

echo "[test] Testando acesso HTTP ao Rancher..."
echo "[info] URL: http://${RANCHER_HOSTNAME}"

# Testa se o cluster está rodando
if ! k3d cluster list | grep -q "dev"; then
    echo "[error] Cluster 'dev' não está rodando. Execute 'make up' primeiro."
    exit 1
fi

# Testa se o Rancher está instalado
if ! kubectl -n cattle-system get deploy rancher >/dev/null 2>&1; then
    echo "[error] Rancher não está instalado. Execute 'make rancher' primeiro."
    exit 1
fi

# Testa se o Rancher está pronto
if ! kubectl -n cattle-system rollout status deploy/rancher --timeout=30s >/dev/null 2>&1; then
    echo "[error] Rancher não está pronto. Aguarde alguns minutos e tente novamente."
    exit 1
fi

# Testa conectividade HTTP
echo "[test] Testando conectividade HTTP..."
if curl -s -f -m 10 "http://${RANCHER_HOSTNAME}" >/dev/null 2>&1; then
    echo "[ok] Rancher está acessível via HTTP!"
    echo "[info] Abra http://${RANCHER_HOSTNAME} no seu navegador"
else
    echo "[error] Não foi possível acessar o Rancher via HTTP"
    echo "[info] Verifique se:"
    echo "  - O cluster está rodando (make up)"
    echo "  - O Rancher está instalado (make rancher)"
    echo "  - O hostname ${RANCHER_HOSTNAME} resolve para 127.0.0.1"
    exit 1
fi
