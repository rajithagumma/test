# 🚀 Taiga Production Deployment – One-Click Setup

This repository contains a script to **automate Taiga installation** in production mode on a clean Ubuntu server using Docker, NGINX, Let's Encrypt SSL, and PostgreSQL.

---

## 📋 Requirements

- Ubuntu 20.04 / 22.04 (fresh server)
- Sudo or root access
- A domain name (A record must point to your server’s IP)
- Gmail account with **App Password** enabled for SMTP
- Open ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)

---

## ⚙️ Configuration

Before running the script, edit the following variables in `taiga.sh`:

| Variable       | Description                                       | Example                     |
|----------------|---------------------------------------------------|-----------------------------|
| `DOMAIN`       | Fully qualified domain name                       | `taiga.example.com`         |
| `EMAIL`        | Gmail address with App Password                   | `user@gmail.com`            |
| `EMAIL_PASS`   | App Password from Gmail                           | `xxxxxxxxxxxxxxxx`          |
| `CERT_EMAIL`   | Email for Let's Encrypt cert registration         | `admin@example.com`         |
| `SECRET_KEY`   | Django secret key (generate via `openssl rand -hex 32`) | `a50279...`           |
| `ADMIN_USER`   | Superuser username for Taiga                      | `admin`                     |
| `ADMIN_PASS`   | Superuser password for login                      | `strongpassword123`         |

---

## 🚀 How to Use

### 1. Provision a Fresh Server

- Create a fresh Ubuntu VM (e.g., Hetzner, DigitalOcean)
- Ensure your domain's A record points to the server IP

### 2. Clone This Repository

```bash
git clone https://github.com/rajithagumma/test.git
```

### 3. Run the Taiga Install Script

```bash
bash ./test/taiga.sh
```

This script will:
- Install Docker and Docker Compose
- Clone the official Taiga Docker repo
- Configure environment files
- Set up NGINX, Let's Encrypt, and firewall
- Reboot the server (required for Docker group access)

### 4. SSH Again After Reboot

Reconnect to the server after reboot:

```bash
ssh ubuntu@<your-server-ip>
```

### 5. Create the Taiga Superuser

Run the post-reboot script:

```bash
bash ./taiga-post-reboot.sh
```

---

## ✅ What’s Installed

- Taiga (Front-end, Back-end, Events, Async, Protected)
- PostgreSQL for data storage
- RabbitMQ for background jobs
- NGINX as reverse proxy
- Certbot for HTTPS
- Docker volumes for persistence

---

## 🌐 Access Your Instance

Open a browser and visit:

```
https://<your-domain>
```

Login using your superuser credentials set in `taiga.sh`.

---

## 📎 References

- Taiga Docs: https://docs.taiga.io
- Taiga Docker: https://github.com/taigaio/taiga-docker
- Let's Encrypt Certbot: https://certbot.eff.org/
- Gmail App Passwords: https://support.google.com/accounts/answer/185833
