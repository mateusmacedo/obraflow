#!/usr/bin/env bash
set -euo pipefail

: "${CLUSTER_NAME:=dev}"
: "${RANCHER_HOSTNAME:=rancher-dev.sslip.io}"

echo "[k3d] Clusters disponíveis:"
k3d cluster list || true
echo

echo "[k8s] Nós:"
kubectl get nodes -o wide || true
echo

echo "[k8s] Namespaces principais:"
kubectl get ns | egrep "kube-system|kube-public|default|cattle-system" || true
echo

echo "[k8s] Pods no cattle-system:"
kubectl -n cattle-system get pods -o wide || true
echo

echo "[info] Acesse: http://${RANCHER_HOSTNAME}"
