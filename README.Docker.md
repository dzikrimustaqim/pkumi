# PKUMI Docker Setup

Simplified Docker configuration untuk aplikasi PKUMI Laravel.

## 📁 Struktur File

```
pkumi/
├── Dockerfile              # Docker image configuration
├── docker-compose.yml      # Container orchestration
├── docker-entrypoint.sh    # Initialization script
├── .env.docker             # Environment template
└── docker/
    └── nginx/
        └── default.conf    # Nginx configuration
```

## 🚀 Quick Start

### 1. Setup Environment
```bash
# Copy environment template
cp .env.docker .env

# Edit .env jika perlu (APP_KEY akan di-generate otomatis)
```

### 2. Deploy
```bash
# Satu perintah untuk build dan start
docker-compose up -d
```

Selesai! Aplikasi akan:
- Build Docker image
- Start containers (app + database)
- Generate APP_KEY otomatis
- Run database migrations
- Optimize untuk production

### 3. Access Application
- **Web**: http://localhost:18081
- **Health Check**: http://localhost:18081/health
- **Database**: localhost:13306

## 📋 Common Commands

```bash
# Start containers
docker-compose up -d

# Stop containers
docker-compose down

# View logs
docker-compose logs -f app

# Restart
docker-compose restart

# Rebuild
docker-compose up -d --build

# Clean everything (including volumes)
docker-compose down --rmi all -v
```

## 🔧 Environment Variables

Edit file `.env` untuk konfigurasi:

```env
APP_PORT=18081              # Application port
DB_PORT=13306               # Database port (from host)
DB_DATABASE=pkumi_db        # Database name
DB_USERNAME=pkumi_user      # Database user
DB_PASSWORD=pkumi_secure    # Database password
DB_ROOT_PASSWORD=root_pass  # MySQL root password
```

## 📊 Container Info

| Container | Service | Port |
|-----------|---------|------|
| pkumi_app | Laravel + Nginx + PHP-FPM | 18081 |
| pkumi_db  | MySQL 8.0 | 13306 |

## 💾 Data Persistence

Data berikut disimpan secara permanen:
- **mysql_data**: Database MySQL (Docker volume)
- **./storage**: File uploads dan logs (bind mount)

## ⚙️ What Happens on Startup

1. Wait for database connection
2. Generate APP_KEY (jika belum ada)
3. Run database migrations
4. Cache configs, routes, views
5. Create storage symlink
6. Fix permissions
7. Start PHP-FPM + Nginx

## 🔍 Troubleshooting

### Container tidak start
```bash
docker-compose logs app
docker-compose logs db
```

### Reset semua
```bash
docker-compose down --rmi all -v
cp .env.docker .env
docker-compose up -d
```

### Access container shell
```bash
docker-compose exec app sh
```

### Run artisan commands
```bash
docker-compose exec app php artisan migrate
docker-compose exec app php artisan cache:clear
```

## 🔒 Production Notes

Untuk production, update `.env`:
- Set strong passwords untuk `DB_PASSWORD` dan `DB_ROOT_PASSWORD`
- Set `APP_URL` ke domain Anda
- Gunakan reverse proxy (Nginx/Caddy) dengan SSL

## 📝 Notes

- APP_KEY akan di-generate otomatis saat pertama kali start
- Database migrations akan dijalankan otomatis
- Optimasi cache akan dilakukan otomatis
- Tidak perlu setup manual, semua otomatis

---

Simple, clean, dan production-ready! 🚀
