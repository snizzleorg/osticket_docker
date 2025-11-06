# osTicket Docker Documentation

## 📖 Main Documentation

**[README.md](README.md)** - Complete setup and deployment guide
- Pre-built Docker Hub images
- Portainer deployment
- Configuration
- Management
- Troubleshooting

**[PORTAINER_DEPLOY_GUIDE.md](PORTAINER_DEPLOY_GUIDE.md)** - Detailed Portainer deployment
- Step-by-step instructions
- Configuration options
- Migration tool usage
- Security checklist

---

## 🚀 Quick Start

### For Portainer (Recommended)

1. Copy `docker-compose.portainer.yml`
2. Paste into Portainer → Stacks → Add Stack
3. Update passwords
4. Deploy
5. Access at `http://your-server:8082`

### Docker Images

- **Web**: `universaldilettant/osticket-web:latest`
- **Migration**: `universaldilettant/osticket-migration:latest`

Both pre-built for AMD64, hosted free on Docker Hub.

---

## 🔧 For Developers

### Building Images

```bash
./build-for-portainer.sh
```

Builds and pushes both images to Docker Hub for AMD64 architecture.

### Local Development

Use `docker-compose.yml` for local development (builds from source):

```bash
docker compose up -d
```

---

## 📦 What's Included

- **osTicket v1.18.1** with PHP 8.3
- **MariaDB 10.11** database
- **phpMyAdmin** for database management
- **Migration tools** for data import

---

## 🔗 External Resources

- **osTicket Docs**: https://docs.osticket.com/
- **Docker Hub Images**: https://hub.docker.com/u/universaldilettant
- **GitHub Repository**: https://github.com/snizzleorg/osticket_docker
