#!/usr/bin/bash
set -euo pipefail

# Script para gerar senhas seguras para a implantação
# Uso: ./scripts/generate-passwords.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

echo "[generate] Gerando senhas seguras..."

# Função para gerar senha segura
generate_password() {
    local length="${1:-32}"
    openssl rand -base64 "${length}" | tr -d "=+/" | cut -c1-"${length}"
}

# Função para gerar chave de criptografia
generate_encryption_key() {
    openssl rand -base64 2000 | tr -dc 'A-Z' | fold -w 128 | head -n 1
}

# Gera senhas se não existirem no .env
if [[ -f "${ENV_FILE}" ]]; then
    source "${ENV_FILE}"
fi

# Gera senha básica do cluster se não existir
if [[ -z "${CLUSTER_PASSWORD:-}" ]]; then
    CLUSTER_PASSWORD=$(generate_password 20)
    echo "[generate] Senha do cluster gerada: ${CLUSTER_PASSWORD}"
fi


# Atualiza o arquivo .env
{
    echo "# Senhas geradas automaticamente - NÃO COMMITAR"
    echo "CLUSTER_PASSWORD=${CLUSTER_PASSWORD}"
    echo ""
    echo "# Configurações do cluster"
    echo "CLUSTER_NAME=${CLUSTER_NAME:-dev}"
    echo "K3S_VERSION=${K3S_VERSION:-v1.29.5-k3s1}"
    echo ""
    echo "# Registry local"
    echo "REGISTRY_NAME=${REGISTRY_NAME:-k3d-dev-registry}"
    echo "REGISTRY_PORT=${REGISTRY_PORT:-5001}"
} > "${ENV_FILE}"

echo "[ok] Senhas geradas e salvas em ${ENV_FILE}"
echo "[warning] IMPORTANTE: Adicione .env ao .gitignore para não commitar senhas!"
