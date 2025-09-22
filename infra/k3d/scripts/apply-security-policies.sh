#!/usr/bin/bash
set -euo pipefail

# Script para aplicar políticas de segurança básicas
# Uso: ./scripts/apply-security-policies.sh [all] [restrictive|permissive]

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

COMPONENT="${1:-all}"
POLICY_TYPE="${2:-restrictive}"

echo "[security] Aplicando políticas de segurança para componente: ${COMPONENT} (${POLICY_TYPE})..."

# Verifica se o cluster está rodando
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "[error] kubectl não consegue conectar ao cluster. Verifique o kubeconfig."
    exit 1
fi

# Configura labels básicos dos namespaces
echo "[security] Configurando labels dos namespaces..."
kubectl label namespace kube-system name=kube-system --overwrite

case "${COMPONENT}" in
    "all")
        echo "[security] Aplicando políticas de segurança básicas..."
        echo "[info] Aplicando NetworkPolicies básicas para o cluster..."
        
        # Aplica políticas básicas de rede
        kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
        ;;
    *)
        echo "[error] Componente inválido: ${COMPONENT}"
        echo "Uso: $0 [all] [restrictive|permissive]"
        exit 1
        ;;
esac

echo "[ok] Políticas de segurança aplicadas!"
echo "[info] Para verificar NetworkPolicies: kubectl get networkpolicies --all-namespaces"
