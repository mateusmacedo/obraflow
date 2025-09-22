# k3d-dev - Ambiente de Desenvolvimento Kubernetes (Single Node)

Ambiente de desenvolvimento Kubernetes otimizado para 1 node usando k3d, ideal para desenvolvimento local com recursos limitados.

## 🚀 Início Rápido

### 1. Configuração Inicial

```bash
# Clone o repositório
git clone <repository-url>
cd k3d-dev

# Gere senhas seguras automaticamente
make generate-passwords

# Verifique dependências
make deps
```

### 2. Criar o Ambiente Base

```bash
# Crie o cluster k3d
make up
```

### 3. Configuração do Cluster

```bash
# Crie o cluster k3d
make up

# Teste a conectividade
make test

# Verifique o status
make status
```

## 📋 Comandos Disponíveis

### Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `make help` | Lista todos os comandos disponíveis |
| `make deps` | Verifica dependências (docker, k3d, kubectl) |
| `make up` | Cria o cluster k3d single node e registry local |
| `make down` | Remove cluster e registry |
| `make status` | Mostra status do cluster |
| `make test` | Testa conectividade do cluster |
| `make generate-passwords` | Gera senhas seguras automaticamente |

## 🔧 Configuração

### Variáveis de Ambiente

Copie `env.example` para `.env` e ajuste conforme necessário:

```bash
cp env.example .env
```

Principais variáveis:

- `CLUSTER_NAME`: Nome do cluster (padrão: dev)
- `K3S_VERSION`: Versão do k3s (padrão: v1.29.5-k3s1)
- `REGISTRY_PORT`: Porta do registry local (padrão: 5001)
- `CLUSTER_PASSWORD`: Senha do cluster (gerada automaticamente)

## 🎯 Características

### Vantagens do Ambiente Single Node

- **Baixo uso de recursos**: Otimizado para 1 node com 16GB RAM
- **Configuração rápida**: Setup em poucos comandos
- **Fácil manutenção**: Menos complexidade, mais estabilidade
- **Ideal para desenvolvimento**: Foco no que realmente importa
- **Otimizado para baixo orçamento**: Configuração especial para 1 node

### Configuração

- **`cluster.yaml`**: Configuração otimizada para 1 node (16GB RAM, 1TB SSD)

### Fluxo de Uso Recomendado

```bash
# 1. Configuração inicial
make generate-passwords
make deps

# 2. Criar cluster otimizado para 1 node
make up

# 3. Testar funcionamento
make test

# 4. Verificar status
make status
```

### Portas Expostas

- **80/443**: Ingress (Traefik)
- **6445**: API do Kubernetes
- **5001**: Registry local

## 🔒 Segurança

### Senhas Geradas Automaticamente

O comando `make generate-passwords` gera automaticamente:

- Senha do cluster k3d

### Políticas de Segurança

- **NetworkPolicies básicas**: Aplicadas automaticamente
- **PodSecurityStandards**: Configurados pelo k3s
- **Isolamento de rede**: Implementado via k3d

### Configuração Segura

- Nunca commite o arquivo `.env` (está no `.gitignore`)
- Use secrets do Kubernetes para dados sensíveis
- Configure RBAC conforme necessário para seu projeto

## 🌐 Acesso aos Serviços

### Kubernetes Dashboard (Opcional)
```bash
# Instalar dashboard se necessário
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Port-forward para acesso local
kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:443

# Acesse: https://localhost:8443
```

### Aplicações Desenvolvidas
```bash
# Expor aplicação via port-forward
kubectl port-forward svc/minha-app 8080:80

# Acesse: http://localhost:8080
```

## 🛠️ Desenvolvimento

### Registry Local

O registry local está disponível em `localhost:5001`:

```bash
# Tag uma imagem
docker tag minha-imagem:latest localhost:5001/minha-imagem:latest

# Push para o registry
docker push localhost:5001/minha-imagem:latest

# Pull no cluster
kubectl run test --image=localhost:5001/minha-imagem:latest
```


### Permitindo Acesso para Novas Aplicações

```bash
# Para aplicações que precisam de acesso de rede
./scripts/allow-app-ingress.sh <namespace> <app-name> <port>

# Exemplo
./scripts/allow-app-ingress.sh meu-namespace minha-app 8080
```

## 🔍 Troubleshooting

### Cluster não inicia

```bash
# Verifique se o Docker está rodando
docker info

# Verifique portas em uso
netstat -tuln | grep -E ":(80|443|5001|6445) "

# Limpe e recrie
make down
make up
```

### Cluster com problemas

```bash
# Verifique se o cluster está rodando
make status

# Teste conectividade
make test

# Verifique pods do sistema
kubectl get pods -n kube-system

# Verifique logs de pods com problemas
kubectl logs -n kube-system <nome-do-pod>
```

### Problemas de Conectividade

```bash
# Verifique se o kubeconfig está correto
kubectl config current-context

# Verifique se o cluster está acessível
kubectl cluster-info

# Recrie o cluster se necessário
make down
make up
```

## 📁 Estrutura do Projeto

```text
k3d-dev/
├── values/
│   └── cluster.yaml                    # Configuração otimizada para 1 node
├── scripts/
│   ├── allow-app-ingress.sh            # Permite acesso para aplicações
│   ├── apply-security-policies.sh      # Aplica políticas de segurança básicas
│   ├── create-cluster.sh               # Cria cluster k3d single node
│   ├── create-secrets.sh               # Cria secrets básicos
│   ├── delete-cluster.sh               # Remove cluster
│   ├── generate-passwords.sh           # Gera senhas seguras
│   ├── install-deps.sh                 # Verifica dependências
│   ├── status.sh                       # Status do cluster
│   └── test-cluster.sh                 # Testa conectividade
├── env.example                         # Exemplo de variáveis de ambiente
├── .gitignore                          # Arquivos ignorados
├── Makefile                            # Comandos principais
├── BUDGET_GUIDE.md                     # Guia específico para baixo orçamento
└── README.md                           # Este arquivo
```

## 💰 Guia para Baixo Orçamento

Para ambientes com recursos limitados (1 node, 16GB RAM), consulte o [BUDGET_GUIDE.md](BUDGET_GUIDE.md) que inclui:

- Configuração otimizada para 1 node
- Estratégias de economia de recursos
- Comparação de custos (local vs nuvem)
- Migração futura para AWS free tier
- Monitoramento de recursos

## 📄 Licença

Este projeto está sob a licença MIT.
