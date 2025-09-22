#!/usr/bin/env bash
set -euo pipefail

: "${CLUSTER_NAME:=dev}"
: "${REGISTRY_NAME:=k3d-dev-registry}"

echo "[down] Removendo cluster '${CLUSTER_NAME}'..."
k3d cluster delete "${CLUSTER_NAME}" || true

echo "[down] Removendo registry '${REGISTRY_NAME}' (se existir)..."
if k3d registry list | grep -q "${REGISTRY_NAME}"; then
    k3d registry delete "${REGISTRY_NAME}"
    echo "[down] Registry '${REGISTRY_NAME}' removido."
else
    echo "[down] Registry '${REGISTRY_NAME}' não encontrado, pulando..."
fi

echo "[down] Removendo volumes persistentes..."
# Remove volumes do servidor e agentes se existirem
# Primeiro, tenta remover volumes específicos conhecidos
for volume in "${CLUSTER_NAME}-server" "${CLUSTER_NAME}-agent-0"; do
    if docker volume ls -q | grep -q "^${volume}$"; then
        docker volume rm "${volume}" || true
        echo "[down] Volume '${volume}' removido."
    else
        echo "[down] Volume '${volume}' não encontrado, pulando..."
    fi
done

# Remove volume do agente único
echo "[down] Verificando volume do agente..."
agent_volume="${CLUSTER_NAME}-agent-0"
if docker volume ls -q | grep -q "^${agent_volume}$"; then
    docker volume rm "${agent_volume}" || true
    echo "[down] Volume '${agent_volume}' removido."
else
    echo "[down] Volume '${agent_volume}' não encontrado, pulando..."
fi

echo "[ok] Ambiente removido."
