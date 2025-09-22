#!/usr/bin/bash
set -euo pipefail

# Adiciona caminhos comuns ao PATH para encontrar ferramentas
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

check_dependency() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✓ $cmd: $(command -v "$cmd")"
        return 0
    else
        echo "✗ $cmd: não encontrado"
        return 1
    fi
}

echo "[check] Verificando dependências..."

failed=0
for dep in docker k3d kubectl helm; do
    check_dependency "$dep" || failed=1
done

if [ $failed -eq 1 ]; then
    echo ""
    echo "[error] Algumas dependências estão faltando."
    echo "Para instalar as dependências faltantes:"
    echo ""
    echo "# helm (se não estiver funcionando)"
    echo "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash"
    echo ""
    echo "# k3d (se não estiver funcionando)"
    echo "curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | sudo bash"
    echo ""
    echo "# kubectl (se não estiver funcionando)"
    echo "curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    echo "sudo chmod +x kubectl"
    echo "sudo mv kubectl /usr/bin/"
    exit 1
fi

echo "[ok] Todas as dependências foram encontradas."
