#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# AutoPrime Tech — Setup inicial do VPS Hostinger
# Execute UMA VEZ no servidor após a criação do VPS
# Uso: bash setup-vps.sh
# ══════════════════════════════════════════════════════════════════

set -e

DOMAIN="crm.autoprimetech.com.br"
DEPLOY_PATH="/var/www/evolution-api"
REPO_URL="git@github.com:SEU_ORG/evolution-api.git"  # ← ALTERE AQUI
DEPLOY_USER="deploy"

echo "════════════════════════════════════════════"
echo "  🚀 AutoPrime Tech — Setup VPS Hostinger"
echo "════════════════════════════════════════════"

# 1. Atualizar sistema
echo "📦 Atualizando sistema..."
apt-get update -qq && apt-get upgrade -y -qq

# 2. Instalar dependências
echo "📦 Instalando dependências..."
apt-get install -y -qq \
  git \
  curl \
  wget \
  ufw \
  certbot \
  python3-certbot-nginx \
  ca-certificates \
  gnupg \
  lsb-release

# 3. Instalar Docker
echo "🐳 Instalando Docker..."
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
  echo "✅ Docker instalado"
else
  echo "✅ Docker já instalado"
fi

# 4. Instalar Docker Compose plugin
if ! docker compose version &> /dev/null; then
  apt-get install -y docker-compose-plugin
fi
echo "✅ Docker Compose: $(docker compose version --short)"

# 5. Criar usuário de deploy (sem senha, só SSH)
if ! id "$DEPLOY_USER" &>/dev/null; then
  echo "👤 Criando usuário $DEPLOY_USER..."
  useradd -m -s /bin/bash "$DEPLOY_USER"
  usermod -aG docker "$DEPLOY_USER"
  mkdir -p /home/$DEPLOY_USER/.ssh
  chmod 700 /home/$DEPLOY_USER/.ssh
  echo "✅ Usuário $DEPLOY_USER criado"
fi

# 6. Configurar diretório de deploy
echo "📂 Configurando diretório de deploy..."
mkdir -p "$DEPLOY_PATH"
chown -R $DEPLOY_USER:$DEPLOY_USER "$DEPLOY_PATH"

# 7. Clonar repositório
echo "📥 Clonando repositório..."
sudo -u $DEPLOY_USER git clone "$REPO_URL" "$DEPLOY_PATH" || {
  echo "⚠️  Clone falhou. Configure a chave SSH de deploy primeiro."
  echo "   Execute: cat /home/$DEPLOY_USER/.ssh/deploy_key.pub"
  echo "   E adicione como Deploy Key no GitHub"
}

# 8. Configurar Firewall
echo "🛡️  Configurando firewall..."
ufw --force enable
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw deny 8080/tcp  # Fechar porta direta da Evolution (apenas via Nginx)
echo "✅ Firewall configurado"

# 9. SSL com Certbot
echo "🔒 Configurando SSL..."
certbot certonly --standalone \
  --non-interactive \
  --agree-tos \
  --email adr.bonin@gmail.com \
  -d "$DOMAIN" || echo "⚠️  SSL: configure o DNS antes de rodar certbot"

# 10. Configurar renovação automática do SSL
echo "0 0,12 * * * root certbot renew --quiet" >> /etc/crontab

# 11. Gerar chave SSH para GitHub Actions
echo "🔑 Gerando chave SSH para GitHub Actions..."
ssh-keygen -t ed25519 -C "github-actions@autoprimetech.com.br" \
  -f /home/$DEPLOY_USER/.ssh/deploy_key -N ""

echo ""
echo "════════════════════════════════════════════════════════"
echo "✅ SETUP CONCLUÍDO!"
echo "════════════════════════════════════════════════════════"
echo ""
echo "📋 PRÓXIMOS PASSOS:"
echo ""
echo "1️⃣  Adicione a chave PÚBLICA como Authorized Key no servidor:"
echo "    cat /home/$DEPLOY_USER/.ssh/deploy_key.pub >> /home/$DEPLOY_USER/.ssh/authorized_keys"
echo ""
echo "2️⃣  Copie a chave PRIVADA para o Secret HOSTINGER_SSH_KEY no GitHub:"
echo "    cat /home/$DEPLOY_USER/.ssh/deploy_key"
echo ""
echo "3️⃣  Configure os Secrets no GitHub:"
echo "    HOSTINGER_HOST     = $(curl -s ifconfig.me)"
echo "    HOSTINGER_USER     = $DEPLOY_USER"
echo "    HOSTINGER_PORT     = 22"
echo "    HOSTINGER_SSH_KEY  = (conteúdo da chave privada acima)"
echo "    DEPLOY_PATH        = $DEPLOY_PATH"
echo ""
echo "4️⃣  Copie o .env.example para .env e configure:"
echo "    cp $DEPLOY_PATH/.env.example $DEPLOY_PATH/.env"
echo "    nano $DEPLOY_PATH/.env"
echo ""
echo "5️⃣  Primeiro deploy manual:"
echo "    cd $DEPLOY_PATH"
echo "    docker compose -f docker-compose.prod.yml up -d"
echo ""
echo "🌐 URL: https://$DOMAIN"
echo "════════════════════════════════════════════════════════"
