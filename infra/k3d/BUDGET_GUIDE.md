# Guia para Ambiente Single Node

Este guia é específico para ambiente single node com recursos limitados:
- **1 node físico**: i7 11th gen, 16GB RAM, 1TB SSD
- **Orçamento baixo**: Foco em desenvolvimento local
- **Futuro na nuvem**: Migração para EC2 free tier quando necessário

## 🎯 Configuração Otimizada

### Recursos Alocados por Container

| Componente | RAM | CPU | Observações |
|------------|-----|-----|-------------|
| k3d-server | 2GB | 1 core | Servidor principal |
| k3d-agent | 2GB | 1 core | Worker node |
| Registry | 512MB | 0.5 core | Registry local |
| **Total** | **~4.5GB** | **2.5 cores** | **Sobram ~11.5GB para desenvolvimento** |

### Configurações de Economia

```yaml
# Configurações otimizadas para single node
servers: 1
agents: 1
memory: 2Gi per container
cpus: 1 per container
max-pods: 30
eviction-hard: memory.available<1Gi
```

## 🚀 Setup Rápido

### 1. Configuração Inicial (5 minutos)

```bash
# Clone e configure
git clone <seu-repo>
cd infra/k3d

# Configure o ambiente
cp env.example .env

# Gere senhas
make generate-passwords

# Verifique dependências
make deps
```

### 2. Criação do Cluster (2 minutos)

```bash
# Cria cluster otimizado
make up

# Testa funcionamento
make test

# Verifica status
make status
```

### 3. Desenvolvimento

```bash
# Registry local para builds rápidos
docker tag minha-app:latest localhost:5001/minha-app:latest
docker push localhost:5001/minha-app:latest

# Deploy no cluster
kubectl run minha-app --image=localhost:5001/minha-app:latest
```

## 💰 Estratégia de Custos

### Desenvolvimento Local (Atual)
- **Custo**: R$ 0 (apenas energia elétrica)
- **Recursos**: 16GB RAM, 1TB SSD
- **Uso**: 4.5GB para k3d + 11.5GB para desenvolvimento
- **Vantagem**: Zero latência, controle total

### Migração Futura para AWS Free Tier
- **Custo**: R$ 0 (primeiro ano)
- **Recursos**: 1GB RAM, 30GB SSD (t1.micro)
- **Limitações**: Apenas para testes básicos
- **Estratégia**: Usar para CI/CD e deploys de teste

### Configuração Híbrida Recomendada
```bash
# Desenvolvimento local (principal)
make up  # Cluster local

# Deploy de teste na AWS
aws ec2 run-instances --image-id ami-xxx --instance-type t3.micro
```

## 🔧 Otimizações Específicas

### 1. Limpeza Automática
```bash
# Adicione ao crontab para limpeza semanal
0 2 * * 0 cd /path/to/k3d && make down && make up
```

### 2. Monitoramento de Recursos
```bash
# Script para monitorar uso
#!/bin/bash
echo "=== Uso de Recursos ==="
docker stats --no-stream
echo "=== Pods do Cluster ==="
kubectl top pods --all-namespaces
```

### 3. Backup Automático
```bash
# Backup do cluster (semanal)
k3d cluster export dev --output cluster-backup.tar
```

## 📊 Comparação de Custos

| Ambiente | Custo Mensal | RAM | SSD | Latência | Controle |
|----------|--------------|-----|-----|----------|----------|
| **Local (Atual)** | R$ 50-100 | 16GB | 1TB | 0ms | 100% |
| AWS t3.micro | R$ 0 (1º ano) | 1GB | 30GB | 50-100ms | 80% |
| AWS t3.small | R$ 30-50 | 2GB | 30GB | 50-100ms | 80% |
| AWS t3.medium | R$ 60-100 | 4GB | 30GB | 50-100ms | 80% |

## 🎯 Recomendações para Seu Caso

### Fase 1: Desenvolvimento Local (Atual)
- Use a configuração `cluster.yaml` (otimizada para single node)
- Mantenha apenas serviços essenciais
- Use registry local para builds
- Monitore uso de recursos

### Fase 2: Testes na Nuvem (Futuro)
- Configure CI/CD com GitHub Actions
- Use AWS free tier para deploys de teste
- Mantenha desenvolvimento local
- Migre apenas para produção

### Fase 3: Produção (Longo Prazo)
- Avalie custos vs benefícios
- Considere Kubernetes gerenciado (EKS, GKE)
- Mantenha ambiente local para desenvolvimento

## 🛠️ Comandos Úteis

```bash
# Verificar uso de recursos
make status

# Limpar cluster e recriar
make down && make up

# O ambiente é otimizado para single node
# Não há necessidade de adicionar agentes

# Testar aplicação
kubectl port-forward svc/minha-app 8080:80
```

## 📈 Próximos Passos

1. **Imediato**: Configure o ambiente local otimizado
2. **Curto prazo**: Implemente CI/CD básico
3. **Médio prazo**: Configure AWS free tier para testes
4. **Longo prazo**: Avalie migração completa para nuvem

Este setup te permite desenvolver com eficiência máxima no seu hardware atual, mantendo os custos baixos e preparando para uma futura migração para a nuvem quando necessário.
