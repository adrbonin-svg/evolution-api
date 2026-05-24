#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# AutoPrime Tech — Adicionar Secrets no GitHub via CLI
# Requer: gh (GitHub CLI) instalado e autenticado
# Uso: bash add-github-secrets.sh
# ══════════════════════════════════════════════════════════════════

set -e

echo "════════════════════════════════════════════════════"
echo "  🔐 Configurar GitHub Secrets — AutoPrime Tech"
echo "════════════════════════════════════════════════════"

# Verificar gh CLI
if ! command -v gh &> /dev/null; then
  echo "❌ GitHub CLI (gh) não encontrado."
  echo "   Instale em: https://cli.github.com/"
  exit 1
fi

# Verificar autenticação
if ! gh auth status &> /dev/null; then
  echo "❌ Não autenticado no GitHub CLI."
  echo "   Execute: gh auth login"
  exit 1
fi

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
if [ -z "$REPO" ]; then
  echo "❌ Não foi possível detectar o repositório."
  echo "   Execute dentro do diretório do projeto."
  exit 1
fi

echo "📦 Repositório: $REPO"
echo ""

# Coletar informações
read -p "🌐 IP do VPS Hostinger: " VPS_HOST
read -p "👤 Usuário SSH (ex: root ou deploy): " VPS_USER
read -p "🔌 Porta SSH (padrão: 22): " VPS_PORT
VPS_PORT=${VPS_PORT:-22}

read -p "📂 Caminho de deploy no VPS (padrão: /var/www/evolution-api): " DEPLOY_PATH
DEPLOY_PATH=${DEPLOY_PATH:-/var/www/evolution-api}

read -p "🔑 Caminho da chave SSH privada (padrão: ~/.ssh/hostinger_deploy): " SSH_KEY_PATH
SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/hostinger_deploy}

if [ ! -f "$SSH_KEY_PATH" ]; then
  echo ""
  echo "⚠️  Chave SSH não encontrada em $SSH_KEY_PATH"
  echo "   Gerando nova chave..."
  ssh-keygen -t ed25519 -C "deploy@autoprimetech.com.br" -f "$SSH_KEY_PATH" -N ""
  echo ""
  echo "📋 Adicione a chave pública ao VPS:"
  echo "   ssh-copy-id -i ${SSH_KEY_PATH}.pub ${VPS_USER}@${VPS_HOST} -p ${VPS_PORT}"
  echo ""
  read -p "Pressione ENTER após adicionar a chave pública ao VPS..."
fi

echo ""
echo "🔐 Adicionando secrets no GitHub..."

# Adicionar secrets
gh secret set HOSTINGER_HOST     --body "$VPS_HOST"     --repo "$REPO"
gh secret set HOSTINGER_USER     --body "$VPS_USER"     --repo "$REPO"
gh secret set HOSTINGER_PORT     --body "$VPS_PORT"     --repo "$REPO"
gh secret set DEPLOY_PATH        --body "$DEPLOY_PATH"  --repo "$REPO"
gh secret set HOSTINGER_SSH_KEY  < "$SSH_KEY_PATH"      --repo "$REPO"

echo ""
echo "📣 Configurar notificações WhatsApp? (opcional)"
read -p "   URL da Evolution API (ex: https://crm.autoprimetech.com.br): " EVOLUTION_URL
if [ -n "$EVOLUTION_URL" ]; then
  read -p "   Nome da instância WhatsApp: " EVOLUTION_INSTANCE
  read -p "   API Key da Evolution: " EVOLUTION_KEY
  read -p "   Número para notificação (com DDD e 55, ex: 5511999999999): " NOTIFY_NUMBER

  gh secret set EVOLUTION_API_URL      --body "$EVOLUTION_URL"      --repo "$REPO"
  gh secret set EVOLUTION_INSTANCE_NAME --body "$EVOLUTION_INSTANCE" --repo "$REPO"
  gh secret set EVOLUTION_API_KEY      --body "$EVOLUTION_KEY"      --repo "$REPO"
  gh secret set NOTIFY_WHATSAPP_NUMBER --body "$NOTIFY_NUMBER"      --repo "$REPO"
fi

echo ""
echo "════════════════════════════════════════════════════"
echo "✅ Secrets configurados com sucesso!"
echo ""
echo "📋 Secrets adicionados:"
gh secret list --repo "$REPO"
echo ""
echo "🚀 Próximo passo: faça um push na branch main para"
echo "   disparar o primeiro deploy automático!"
echo "════════════════════════════════════════════════════"
