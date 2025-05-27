#!/bin/bash

# WAF com nginx + mod_security + geoip sem epel
# Martinho Caeiro & Paulo Abade

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Execute como root.${RESET}"
    exit 1
fi

echo -e "${YELLOW}Instalando nginx, mod_security e GeoIP...${RESET}"
yum install -y nginx mod_security GeoIP geoipupdate policycoreutils-python

# Habilitar e iniciar nginx
systemctl enable --now nginx

# Ativar ModSecurity no Nginx
sed -i '/http {/a \    include /etc/nginx/modsecurity.conf;' /etc/nginx/nginx.conf

# Criar diretório de regras
mkdir -p /etc/nginx/modsec

# Configuração de ativação do ModSecurity
cat <<EOF > /etc/nginx/modsecurity.conf
modsecurity on;
modsecurity_rules_file /etc/nginx/modsec/main.conf;
EOF

# Criar regra principal
cat <<EOF > /etc/nginx/modsec/main.conf
SecRuleEngine On

# AntiBot: Bloquear agentes suspeitos
SecRule REQUEST_HEADERS:User-Agent "@rx (sqlmap|masscan|HTTrack)" \
"id:1001,phase:1,deny,status:403,msg:'Agente bloqueado (bot)'"

# Blacklist de IPs
SecRule REMOTE_ADDR "@ipMatch 203.0.113.10,198.51.100.23" \
"id:1002,phase:1,deny,status:403,msg:'IP na blacklist'"

EOF

# GeoIP básico
cat <<EOF >> /etc/nginx/nginx.conf

geoip_country /usr/share/GeoIP/GeoIP.dat;
map \$geoip_country_code \$allowed_country {
    default no;
    PT yes;
    BR yes;
    US yes;
}
EOF

# Criar virtual hosts para os 3 domínios
cat <<EOF > /etc/nginx/conf.d/waf.conf
server {
    listen 80;
    server_name www.trinta.org;

    if (\$allowed_country = no) {
        return 403;
    }

    location / {
        proxy_pass http://192.168.30.10;
    }
}

server {
    listen 80;
    server_name www.3emfrente.eu;

    if (\$allowed_country = no) {
        return 403;
    }

    location / {
        proxy_pass http://192.168.30.10;
    }
}

server {
    listen 80;
    server_name www.the.com;

    if (\$allowed_country = no) {
        return 403;
    }

    location / {
        proxy_pass http://192.168.30.10;
    }
}
EOF

# Corrigir permissões
restorecon -Rv /etc/nginx > /dev/null 2>&1

# Reiniciar serviços
systemctl restart nginx

echo -e "${GREEN}✅ WAF configurada com ModSecurity, GeoIP e bloqueio para os domínios!${RESET}"
