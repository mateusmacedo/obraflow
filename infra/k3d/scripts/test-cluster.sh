#!/usr/bin/bash
set -euo pipefail

# Script para testar conectividade básica do cluster k3d
# Uso: ./scripts/test-cluster.sh

echo "[test] Testando conectividade do cluster k3d..."

# Verifica se kubectl consegue conectar
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "[error] kubectl não consegue conectar ao cluster"
    echo "[info] Verifique se o cluster está rodando: make status"
    exit 1
fi

echo "[ok] kubectl conectado ao cluster"

# Testa componentes básicos
echo "[test] Verificando componentes do cluster..."

# Verifica nodes
echo "[test] Nodes:"
kubectl get nodes -o wide

# Verifica pods do sistema
echo "[test] Pods do sistema:"
kubectl get pods -n kube-system

# Verifica se o registry local está funcionando
echo "[test] Verificando registry local..."
if kubectl get pods -n kube-system | grep -q "local-path-provisioner"; then
    echo "[ok] Local path provisioner está rodando"
else
    echo "[warning] Local path provisioner não encontrado"
fi

# Testa criação de um pod simples
echo "[test] Testando criação de pod..."
kubectl run test-pod --image=nginx:alpine --restart=Never --rm -i --tty -- /bin/sh -c "echo 'Teste de conectividade OK' && exit 0" || {
    echo "[error] Falha ao criar pod de teste"
    exit 1
}

echo "[ok] Cluster k3d funcionando corretamente!"
echo "[info] Para mais informações: kubectl cluster-info"
