#!/usr/bin/bash
set -euo pipefail

# Script para permitir ingress de uma nova aplicação
# Uso: ./scripts/allow-app-ingress.sh <namespace> <app-name> <port>

NAMESPACE="${1:-}"
APP_NAME="${2:-}"
PORT="${3:-8080}"

if [[ -z "${NAMESPACE}" || -z "${APP_NAME}" ]]; then
    echo "Uso: $0 <namespace> <app-name> [port]"
    echo "Exemplo: $0 meu-namespace minha-app 8080"
    exit 1
fi

echo "[network] Criando NetworkPolicy para ${APP_NAME} no namespace ${NAMESPACE}..."

# Cria namespace se não existir
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Aplica label no namespace
kubectl label namespace "${NAMESPACE}" name="${NAMESPACE}" --overwrite

# Cria NetworkPolicy
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-${APP_NAME}-ingress
  namespace: ${NAMESPACE}
spec:
  podSelector:
    matchLabels:
      app: ${APP_NAME}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    - namespaceSelector:
        matchLabels:
          name: ${NAMESPACE}
    ports:
    - protocol: TCP
      port: ${PORT}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-${APP_NAME}-external
  namespace: ${NAMESPACE}
spec:
  podSelector:
    matchLabels:
      app: ${APP_NAME}
  policyTypes:
  - Ingress
  ingress:
  - from: []  # Permite acesso externo
    ports:
    - protocol: TCP
      port: ${PORT}
EOF

echo "[ok] NetworkPolicy criada para ${APP_NAME}!"
echo "[info] Para verificar: kubectl get networkpolicies -n ${NAMESPACE}"
