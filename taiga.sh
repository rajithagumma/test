#!/bin/bash
set -euo pipefail

# ------------------ CONFIG ------------------
DOMAIN="testing.justuju.in"
EMAIL="rajitha@justuju.in"
CERT_EMAIL="devs@justuju.in"
EMAIL_PASS="qhygrahuvwxmsvnh"
SECRET_KEY="a5027928ced68010988457de9dbf7a1184952a280fdc5eac18456dcab0c29f23"
CONF_DIR="$(pwd)/conf"
ADMIN_USER="gummarajitha"
ADMIN_PASS="123456"


# ------------------ INSTALL DOCKER ------------------
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER

# ------------------ CLONE TAIGA ------------------
if [ ! -d "taiga-docker" ]; then
  git clone https://github.com/taigaio/taiga-docker.git
fi
cd taiga-docker
git checkout stable

# ------------------ OVERWRITE .env FILE ------------------
cat > .env <<EOF
TAIGA_SCHEME=https
TAIGA_DOMAIN=$DOMAIN
SUBPATH=""
WEBSOCKETS_SCHEME=wss
SECRET_KEY=$SECRET_KEY
POSTGRES_USER=taiga
POSTGRES_PASSWORD=taiga
EMAIL_BACKEND=smtp
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=$EMAIL
EMAIL_HOST_PASSWORD=$EMAIL_PASS
EMAIL_DEFAULT_FROM=$EMAIL
EMAIL_USE_TLS=True
EMAIL_USE_SSL=False
RABBITMQ_USER=taiga
RABBITMQ_PASS=taiga
RABBITMQ_VHOST=taiga
RABBITMQ_ERLANG_COOKIE=secret-erlang-cookie
ATTACHMENTS_MAX_AGE=86400
MAX_UPLOAD_SIZE=104857600
ENABLE_TELEMETRY=True
EOF

# ------------------ OVERWRITE docker-compose.yml FILE ------------------
cat > docker-compose.yml <<EOF
version: "3.5"

x-environment:
  &default-back-environment
  POSTGRES_DB: "taiga"
  POSTGRES_USER: "\${POSTGRES_USER}"
  POSTGRES_PASSWORD: "\${POSTGRES_PASSWORD}"
  POSTGRES_HOST: "taiga-db"
  TAIGA_SECRET_KEY: "\${SECRET_KEY}"
  TAIGA_SITES_SCHEME: "\${TAIGA_SCHEME}"
  TAIGA_SITES_DOMAIN: "\${TAIGA_DOMAIN}"
  TAIGA_SUBPATH: "\${SUBPATH}"
  EMAIL_BACKEND: "django.core.mail.backends.\${EMAIL_BACKEND}.EmailBackend"
  DEFAULT_FROM_EMAIL: "\${EMAIL_DEFAULT_FROM}"
  EMAIL_USE_TLS: "\${EMAIL_USE_TLS}"
  EMAIL_USE_SSL: "\${EMAIL_USE_SSL}"
  EMAIL_HOST: "\${EMAIL_HOST}"
  EMAIL_PORT: "\${EMAIL_PORT}"
  EMAIL_HOST_USER: "\${EMAIL_HOST_USER}"
  EMAIL_HOST_PASSWORD: "\${EMAIL_HOST_PASSWORD}"
  RABBITMQ_USER: "\${RABBITMQ_USER}"
  RABBITMQ_PASS: "\${RABBITMQ_PASS}"
  ENABLE_TELEMETRY: "\${ENABLE_TELEMETRY}"
  PUBLIC_REGISTER_ENABLED: "True"

x-volumes:
  &default-back-volumes
  - taiga-static-data:/taiga-back/static
  - taiga-media-data:/taiga-back/media

services:
  taiga-db:
    image: postgres:12.3
    environment:
      POSTGRES_DB: "taiga"
      POSTGRES_USER: "\${POSTGRES_USER}"
      POSTGRES_PASSWORD: "\${POSTGRES_PASSWORD}"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER}"]
      interval: 2s
      timeout: 15s
      retries: 5
      start_period: 3s
    volumes:
      - taiga-db-data:/var/lib/postgresql/data
    networks:
      - taiga

  taiga-back:
    image: taigaio/taiga-back:latest
    environment: *default-back-environment
    volumes: *default-back-volumes
    networks:
      - taiga
    depends_on:
      taiga-db:
        condition: service_healthy
      taiga-events-rabbitmq:
        condition: service_started
      taiga-async-rabbitmq:
        condition: service_started

  taiga-async:
    image: taigaio/taiga-back:latest
    entrypoint: ["/taiga-back/docker/async_entrypoint.sh"]
    environment: *default-back-environment
    volumes: *default-back-volumes
    networks:
      - taiga
    depends_on:
      taiga-db:
        condition: service_healthy
      taiga-events-rabbitmq:
        condition: service_started
      taiga-async-rabbitmq:
        condition: service_started

  taiga-async-rabbitmq:
    image: rabbitmq:3.8-management-alpine
    environment:
      RABBITMQ_ERLANG_COOKIE: "\${RABBITMQ_ERLANG_COOKIE}"
      RABBITMQ_DEFAULT_USER: "\${RABBITMQ_USER}"
      RABBITMQ_DEFAULT_PASS: "\${RABBITMQ_PASS}"
      RABBITMQ_DEFAULT_VHOST: "\${RABBITMQ_VHOST}"
    hostname: "taiga-async-rabbitmq"
    volumes:
      - taiga-async-rabbitmq-data:/var/lib/rabbitmq
    networks:
      - taiga

  taiga-front:
    image: taigaio/taiga-front:latest
    environment:
      TAIGA_URL: "\${TAIGA_SCHEME}://\${TAIGA_DOMAIN}"
      TAIGA_WEBSOCKETS_URL: "\${WEBSOCKETS_SCHEME}://\${TAIGA_DOMAIN}"
      TAIGA_SUBPATH: "\${SUBPATH}"
      PUBLIC_REGISTER_ENABLED: "true"
    networks:
      - taiga
    volumes:
      - ./conf/conf.json:/usr/share/nginx/html/conf.json:ro

  taiga-events:
    image: taigaio/taiga-events:latest
    environment:
      RABBITMQ_USER: "\${RABBITMQ_USER}"
      RABBITMQ_PASS: "\${RABBITMQ_PASS}"
      TAIGA_SECRET_KEY: "\${SECRET_KEY}"
    networks:
      - taiga
    depends_on:
      taiga-events-rabbitmq:
        condition: service_started

  taiga-events-rabbitmq:
    image: rabbitmq:3.8-management-alpine
    environment:
      RABBITMQ_ERLANG_COOKIE: "\${RABBITMQ_ERLANG_COOKIE}"
      RABBITMQ_DEFAULT_USER: "\${RABBITMQ_USER}"
      RABBITMQ_DEFAULT_PASS: "\${RABBITMQ_PASS}"
      RABBITMQ_DEFAULT_VHOST: "\${RABBITMQ_VHOST}"
    hostname: "taiga-events-rabbitmq"
    volumes:
      - taiga-events-rabbitmq-data:/var/lib/rabbitmq
    networks:
      - taiga

  taiga-protected:
    image: taigaio/taiga-protected:latest
    environment:
      MAX_AGE: "\${ATTACHMENTS_MAX_AGE}"
      SECRET_KEY: "\${SECRET_KEY}"
      MAX_UPLOAD_SIZE: "\${MAX_UPLOAD_SIZE}"
    networks:
      - taiga

  taiga-gateway:
    image: nginx:1.19-alpine
    ports:
      - "9000:80"
    volumes:
      - ./taiga-gateway/taiga.conf:/etc/nginx/conf.d/default.conf
      - taiga-static-data:/taiga/static
      - taiga-media-data:/taiga/media
    networks:
      - taiga
    depends_on:
      - taiga-front
      - taiga-back
      - taiga-events

volumes:
  taiga-static-data:
  taiga-media-data:
  taiga-db-data:
  taiga-async-rabbitmq-data:
  taiga-events-rabbitmq-data:

networks:
  taiga:
EOF

# ------------------ CREATE conf/conf.json FILE ------------------
mkdir -p ./conf
cat > ./conf/conf.json <<EOF
{
  "api": "https://$DOMAIN/api/v1/",
  "eventsUrl": "wss://$DOMAIN/events",
  "baseHref": "/",
  "eventsMaxMissedHeartbeats": 5,
  "eventsHeartbeatIntervalTime": 60000,
  "eventsReconnectTryInterval": 10000,
  "debug": false,
  "debugInfo": false,
  "defaultLanguage": "en",
  "themes": ["taiga"],
  "defaultTheme": "taiga",
  "defaultLoginEnabled": true,
  "publicRegisterEnabled": true,
  "feedbackEnabled": true,
  "supportUrl": "https://community.taiga.io/",
  "privacyPolicyUrl": null,
  "termsOfServiceUrl": null,
  "maxUploadFileSize": null,
  "contribPlugins": [],
  "tagManager": {"accountId": null},
  "tribeHost": null,
  "enableAsanaImporter": false,
  "enableGithubImporter": false,
  "enableJiraImporter": false,
  "enableTrelloImporter": false,
  "gravatar": false,
  "rtlLanguages": ["ar", "fa", "he"]
}
EOF



# ------------------ INSTALL AND CONFIGURE NGINX ------------------
sudo apt install -y nginx certbot python3-certbot-nginx
sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

sudo tee /etc/nginx/sites-available/$DOMAIN > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    client_max_body_size 100M;

    location = /conf.json {
        root /var/www/html;
        add_header Content-Type application/json;
    }

    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Scheme \$scheme;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_redirect off;
        proxy_pass http://localhost:9000/;
    }

    location /events {
        proxy_pass http://localhost:9000/events;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
}

EOF

sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
sudo cp ./conf/conf.json /var/www/html/conf.json
sudo nginx -t && sudo systemctl reload nginx

# ------------------ OBTAIN SSL CERTIFICATE ------------------
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email $CERT_EMAIL
sudo certbot renew --dry-run --non-interactive


# ------------------ PREPARE POST-REBOOT SCRIPT ------------------
cat > /home/ubuntu/taiga-post-reboot.sh <<EOF
#!/bin/bash
cd /home/ubuntu/taiga-docker
./launch-taiga.sh
sleep 10
./taiga-manage.sh createsuperuser \
  --username $ADMIN_USER \
  --email $EMAIL \
  --password $ADMIN_PASS
EOF

chmod +x /home/ubuntu/taiga-post-reboot.sh


# ------------------ INFORM USER AND REBOOT ------------------
echo "🟡 Docker group permission will apply after reboot. Rebooting now..."
sudo reboot
