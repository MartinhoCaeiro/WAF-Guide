#!/bin/bash

# Martinho Caeiro, 23917 & Paulo Abade, 23919
# 2025-05-23
# Script completo de configuração DNS + VirtualHosts

# Cores
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

# Verifica se é root
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}Este script precisa de permissões de root.${RESET}"
    exit 1
fi

# Variáveis
SERVER_IP=$(ip route get 1 | awk '{print $7; exit}')
NAMED_CONF="/etc/named.conf"
HTTPD_CONF="/etc/httpd/conf/httpd.conf"

# Verificação de pacotes
check_package() {
    PACKAGE=$1
    if ! rpm -q "$PACKAGE" &>/dev/null; then
        echo -e "${YELLOW}Pacote $PACKAGE não encontrado.${RESET}"
        read -p "Deseja instalar $PACKAGE? (s/n): " INSTALL
        if [[ "$INSTALL" =~ ^[Ss]$ ]]; then
            yum install -y "$PACKAGE"
            systemctl enable --now "$PACKAGE"
        else
            echo -e "${RED}$PACKAGE é necessário. A sair...${RESET}"
            exit 1
        fi
    fi
}

check_package httpd
check_package bind
check_package bind-utils

# Configuração básica do named
sed -i 's/listen-on port 53 {[^}]*}/listen-on port 53 { any; }/' "$NAMED_CONF"
sed -i 's/allow-query {[^}]*}/allow-query { any; }/' "$NAMED_CONF"

# Criar zonas principais apontando para o WAF
create_zone_waf() {
    DOMAIN=$1
    ZONE_FILE="/var/named/${DOMAIN}.hosts"

    cat <<EOF > "$ZONE_FILE"
\$TTL 38400
@ IN SOA server.tei.pt. admin.tei.pt. (
    $(date +%Y%m%d%H)
    10800
    3600
    604800
    38400 )
@       IN NS server.tei.pt.
@       IN A 192.168.30.5
www     IN A 192.168.30.5
EOF

    chown named:named "$ZONE_FILE"
    chmod 640 "$ZONE_FILE"

    if ! grep -q "zone \"$DOMAIN\"" "$NAMED_CONF"; then
        cat <<EOF >> "$NAMED_CONF"

zone "$DOMAIN" IN {
    type master;
    file "$ZONE_FILE";
    allow-update { none; };
};
EOF
    fi
}

# Criar zonas internas (www1.*) apontando para servidor web
create_zone_www1() {
    DOMAIN=$1
    ZONE_FILE="/var/named/${DOMAIN}.hosts"

    cat <<EOF > "$ZONE_FILE"
\$TTL 38400
@ IN SOA server.tei.pt. admin.tei.pt. (
    $(date +%Y%m%d%H)
    10800
    3600
    604800
    38400 )
@       IN NS server.tei.pt.
www1    IN A 192.168.30.10
EOF

    chown named:named "$ZONE_FILE"
    chmod 640 "$ZONE_FILE"

    if ! grep -q "zone \"$DOMAIN\"" "$NAMED_CONF"; then
        cat <<EOF >> "$NAMED_CONF"

zone "$DOMAIN" IN {
    type master;
    file "$ZONE_FILE";
    allow-update { none; };
};
EOF
    fi
}

# Criar VirtualHost
add_vhost() {
    DOMAIN=$1
    USERNAME=$(echo $DOMAIN | cut -d'.' -f1)
    HOME_DIR="/home/$USERNAME"
    DOC_ROOT="$HOME_DIR/public_html"

    useradd -m -d "$HOME_DIR" -s /sbin/nologin "$USERNAME" 2>/dev/null
    mkdir -p "$DOC_ROOT"

    cat <<HTML > "$DOC_ROOT/index.html"
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8">
    <title>Bem-vindo a $DOMAIN</title>
</head>
<body>
    <h1>Site de $DOMAIN</h1>
    <p>Servidor Apache ativo. IP: $SERVER_IP</p>
</body>
</html>
HTML

    chown -R "$USERNAME:$USERNAME" "$HOME_DIR"
    chmod -R 755 "$HOME_DIR"

    if ! grep -q "NameVirtualHost $SERVER_IP:80" "$HTTPD_CONF"; then
        echo "NameVirtualHost $SERVER_IP:80" >> "$HTTPD_CONF"
    fi

    if grep -q "ServerName $DOMAIN" "$HTTPD_CONF"; then
        echo -e "${YELLOW}VirtualHost já existe para $DOMAIN.${RESET}"
        return
    fi

    cat <<EOF >> "$HTTPD_CONF"

<VirtualHost $SERVER_IP:80>
    ServerName $DOMAIN
    DocumentRoot "$DOC_ROOT"

    <Directory "$DOC_ROOT">
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog /var/log/httpd/${DOMAIN}_error.log
    CustomLog /var/log/httpd/${DOMAIN}_access.log combined
</VirtualHost>
EOF
}

# Execução das tarefas
echo -e "${BLUE}Criando zonas DNS para domínios públicos...${RESET}"
create_zone_waf "trinta.org"
create_zone_waf "3emfrente.eu"
create_zone_waf "the.com"

echo -e "${BLUE}Criando zonas DNS para domínios internos www1...${RESET}"
create_zone_www1 "trinta.org"
create_zone_www1 "3emfrente.eu"
create_zone_www1 "the.com"

echo -e "${BLUE}Criando VirtualHosts...${RESET}"
add_vhost "www1.trinta.org"
add_vhost "www1.3emfrente.eu"
add_vhost "www1.the.com"

# Reiniciar serviços
systemctl restart named
systemctl restart httpd

# Teste DNS
echo -e "${GREEN}Testando resolução DNS:${RESET}"
for domain in "www1.trinta.org" "www1.3emfrente.eu" "www1.the.com"; do
    echo -n "$domain -> "
    dig @"$SERVER_IP" "$domain" +short
done

echo -e "${GREEN}Script concluído com sucesso!${RESET}"
