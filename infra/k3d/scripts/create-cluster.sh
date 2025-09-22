#!/usr/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Carrega e exporta variáveis de ambiente se o arquivo .env existir
if [[ -f "${ROOT_DIR}/.env" ]]; then
    set -a  # automatically export all variables
    source "${ROOT_DIR}/.env"
    set +a
fi

# Exporta variáveis padrão se não estiverem definidas
export CLUSTER_NAME="${CLUSTER_NAME:-dev}"
export K3S_VERSION="${K3S_VERSION:-v1.29.5-k3s1}"
export REGISTRY_NAME="${REGISTRY_NAME:-k3d-dev-registry}"
export REGISTRY_PORT="${REGISTRY_PORT:-5001}"

: "${CLUSTER_NAME:=dev}"

# Validações pré-criação
echo "[validate] Verificando pré-requisitos..."

# Verifica se o cluster já existe
if k3d cluster list | grep -q "${CLUSTER_NAME}"; then
    echo "[error] Cluster '${CLUSTER_NAME}' já existe. Use 'make down' primeiro."
    exit 1
fi

# Verifica se as portas estão disponíveis
if netstat -tuln 2>/dev/null | grep -q ":80 "; then
    echo "[warning] Porta 80 já está em uso. Pode haver conflitos."
fi

if netstat -tuln 2>/dev/null | grep -q ":443 "; then
    echo "[warning] Porta 443 já está em uso. Pode haver conflitos."
fi

if netstat -tuln 2>/dev/null | grep -q ":${REGISTRY_PORT} "; then
    echo "[error] Porta ${REGISTRY_PORT} já está em uso. Mude REGISTRY_PORT no .env"
    exit 1
fi

# Verifica se o Docker está rodando
if ! docker info >/dev/null 2>&1; then
    echo "[error] Docker não está rodando. Inicie o Docker primeiro."
    exit 1
fi

echo "[create] Criando cluster k3d '${CLUSTER_NAME}'..."

# Usa configuração otimizada para 1 node
echo "[info] Usando configuração otimizada para 1 node"
k3d cluster create --config <(envsubst < "${ROOT_DIR}/values/cluster.yaml")
KUBECONFIG=$(k3d kubeconfig write "${CLUSTER_NAME}")
cp "${KUBECONFIG}" ~/.kube/config
echo "[info] Kubeconfig em $KUBECONFIG"
echo "[wait] Aguardando nós prontos..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "[ok] Cluster '${CLUSTER_NAME}' criado."
