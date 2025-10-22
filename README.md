# PKUMI - Sistem Informasi Akademik

Aplikasi manajemen akademik untuk Program Kuliah Mandiri (PKUMI) berbasis Laravel 12 dengan fitur lengkap untuk pengelolaan mahasiswa, mata kuliah, nilai, dan pelaporan.

## 📋 Fitur Utama

- **Manajemen Mahasiswa** - CRUD, import/export Excel
- **Manajemen Mata Kuliah** - Per semester dan kelas
- **Input & Perhitungan Nilai** - Dengan bobot nilai konfigurabel
- **Sistem Enrollment** - Pendaftaran mahasiswa ke mata kuliah
- **Pelaporan** - Export PDF & Excel untuk kartu hasil studi
- **Multi-role Authentication** - Admin dan Mahasiswa
- **Activity Logging** - Pencatatan semua aktivitas pengguna
- **Responsive UI** - Tailwind CSS 4 + Alpine.js 3

## 🐳 Arsitektur Docker

Aplikasi menggunakan arsitektur **multi-container** dengan pemisahan service:

### Container Services

| Service   | Image                  | Container Name | Exposed Port    | Description                       |
|-----------|------------------------|----------------|-----------------|-----------------------------------|
| **app**   | Custom (PHP 8.3-FPM)   | `pkumi_app`    | None (internal) | Aplikasi Laravel                  |
| **web**   | nginx:1.27-alpine      | `pkumi_web`    | `18081:80`      | Web server & reverse proxy        |
| **db**    | mysql:8.0              | `pkumi_db`     | None (private)  | Database (optional, profile-based)|

#### Visual Diagram

```
                         INTERNET/BROWSER
                                 │
                                 │ HTTP Request
                                 ▼
                         ┌───────────────┐
                         │  Host Machine │
                         │  Port: 18081  │  ◄── EXPOSED (Public Access)
                         └───────┬───────┘
                                 │ Port Mapping (18081 → 80)
                                 ▼
        ╔═══════════════════════════════════════════════╗
        ║    DOCKER NETWORK (pkumi_network - Bridge)    ║
        ║                    172.x.x.0/16               ║
        ╠═══════════════════════════════════════════════╣
        ║                                               ║
        ║    ┌──────────────────────────────────┐       ║
        ║    │  pkumi_web (nginx:1.27)          │       ║
        ║    │  Port: 80 (internal)             │       ║
        ║    │  IP: 172.x.x.2                   │       ║
        ║    │  EXPOSED ke host                 │       ║
        ║    └──────────────┬───────────────────┘       ║
        ║                   │                           ║
        ║                   │ FastCGI (:9000)           ║
        ║                   │ PRIVATE CONNECTION        ║
        ║                   ▼                           ║
        ║    ┌──────────────────────────────────┐       ║
        ║    │  pkumi_app (PHP-FPM 8.3)         │       ║
        ║    │  Port: 9000 (internal)           │       ║
        ║    │  IP: 172.x.x.3                   │       ║
        ║    │  NOT EXPOSED                     │       ║
        ║    └──────────────┬───────────────────┘       ║
        ║                   │                           ║
        ║                   │ MySQL (:3306)             ║
        ║                   │ PRIVATE CONNECTION        ║
        ║                   ▼                           ║
        ║    ┌──────────────────────────────────┐       ║
        ║    │  pkumi_db (MySQL 8.0)            │       ║
        ║    │  Port: 3306 (internal)           │       ║
        ║    │  IP: 172.x.x.4                   │       ║
        ║    │  NOT EXPOSED (Profile: db)       │       ║
        ║    └──────────────────────────────────┘       ║
        ║                                               ║
        ╚═══════════════════════════════════════════════╝
```

#### Koneksi Public vs Private

| Layer           | Source          | Target         | Port       | Protocol   | Access Type | Exposed to Host |
|-----------------|-----------------|----------------|------------|------------|-------------|-----------------|
| **PUBLIC**      | Browser         | pkumi_web      | 18081→80   | HTTP/HTTPS | Public      | YES             |
| **PRIVATE**     | pkumi_web       | pkumi_app      | 9000       | FastCGI    | Internal    | NO              |
| **PRIVATE**     | pkumi_app       | pkumi_db       | 3306       | MySQL      | Internal    | NO              |

**Penjelasan:**

- **PUBLIC Access:** Hanya `pkumi_web` yang dapat diakses dari luar Docker network melalui port 18081
- **PRIVATE Access:** Komunikasi `pkumi_web → pkumi_app` dan `pkumi_app → pkumi_db` hanya terjadi di dalam Docker network
- **Service Discovery:** Container menggunakan service name untuk komunikasi (`app:9000`, `db:3306`)
- **Security:** Database tidak exposed ke host machine (no port mapping) untuk keamanan maksimal

#### Request Flow (Step by Step)

```
[1] User buka browser → http://localhost:18081
                        │
[2] Request masuk ke Host Machine (Windows) port 18081
                        │
[3] Docker port mapping forward ke pkumi_web:80
                        │
[4] Nginx (pkumi_web) terima request
     │
     ├─ File statis (CSS/JS/Images)? → Langsung serve
     └─ File PHP? → Forward ke pkumi_app:9000 (FastCGI)
                        │
[5] PHP-FPM (pkumi_app) proses request Laravel
     │
     ├─ Jalankan routing
     ├─ Execute controller
     └─ Butuh data? → Query ke pkumi_db:3306
                        │
[6] MySQL (pkumi_db) eksekusi query dan return data
                        │
[7] Laravel format response (JSON/HTML)
                        │
[8] Response kembali ke Nginx → Browser
```

#### Kenapa Aman?

**1. Database Isolation**
   - Database tidak bisa diakses langsung dari internet
   - Hanya container `pkumi_app` yang bisa connect ke database
   - Tidak ada port mapping database ke host machine

**2. Single Entry Point**
   - Semua HTTP traffic masuk melalui Nginx (port 18081)
   - Centralized access control dan logging
   - Mudah implementasi rate limiting dan security rules

**3. Network Isolation**
   - Container berkomunikasi dalam private Docker network
   - Service discovery menggunakan container name (bukan IP)
   - Isolated dari host network untuk security layer tambahan

**4. No Direct PHP Access**
   - PHP-FPM tidak exposed ke public
   - Hanya Nginx yang bisa berkomunikasi dengan PHP-FPM via FastCGI
   - Melindungi dari direct PHP vulnerability exploitation

## 🚀 Quick Start

### 1. Clone Repository

```powershell
git clone https://github.com/dzikrimustaqim/pkumi.git
cd pkumi
```

### 2. Setup Environment

```powershell
# Copy environment template
Copy-Item .env.docker .env

# Edit jika perlu (gunakan notepad atau editor lain)
notepad .env
```

### 3. Build & Start Containers

```powershell
# Dengan database internal (MySQL container)
docker-compose --profile db up -d --build

# Tanpa database internal (gunakan database eksternal)
docker-compose up -d --build
```

### 4. Verifikasi Container Running

```powershell
docker-compose ps
```

**Output yang diharapkan:**

```
NAME          IMAGE               STATUS          PORTS
pkumi_app     pkumi-app           Up (healthy)    -
pkumi_web     nginx:1.27-alpine   Up (healthy)    0.0.0.0:18081->80/tcp
pkumi_db      mysql:8.0           Up (healthy)    - (jika pakai --profile db)
```

### 5. Akses Aplikasi

- **URL Utama**: http://localhost:18081
- **Health Check**: http://localhost:18081/health
- **Login Admin**: http://localhost:18081/admin
- **Login Mahasiswa**: http://localhost:18081/login

## ⚙️ Konfigurasi Environment

File `.env` berisi konfigurasi aplikasi. Berikut penjelasan variable penting:

### Application Settings

```env
APP_NAME=PKUMI
APP_ENV=production          # production / local / staging
APP_KEY=                    # Auto-generated saat container start pertama kali
APP_DEBUG=false             # true untuk development, false untuk production
APP_URL=http://localhost:18081
APP_PORT=18081              # Port untuk akses dari host machine
```

### Database Configuration

```env
DB_CONNECTION=mysql
DB_HOST=db                  # "db" = container MySQL internal
                            # hostname/IP lain = database eksternal
DB_PORT_INTERNAL=3306       # Port MySQL internal (di dalam container network)
DB_DATABASE=pkumi_db
DB_USERNAME=pkumi_user
DB_PASSWORD=pkumi_secure_2025
DB_ROOT_PASSWORD=root_secure_2025  # Hanya dipakai jika menggunakan container db
```

**Mode Database:**

- **Internal (Container MySQL):** Set `DB_HOST=db`, jalankan dengan `--profile db`
- **External (Database Terpisah):** Set `DB_HOST=<hostname/IP>`, jalankan tanpa `--profile db`

### Lainnya

```env
CACHE_STORE=file           # file / redis / memcached
SESSION_DRIVER=file        # file / database / redis
QUEUE_CONNECTION=database  # sync / database / redis
LOG_CHANNEL=daily          # single / daily / stack
LOG_LEVEL=error            # debug / info / warning / error
```

## 🔧 Detail Container Services

### 1. Service: `app` (PHP-FPM)

**Base Image:** `php:8.3-fpm-alpine`  
**Container Name:** `pkumi_app`  
**Internal Port:** 9000 (FastCGI)  
**Exposed Port:** ❌ Tidak exposed (internal only)

**PHP Extensions Installed:**

- PDO MySQL (database connection)
- mbstring (string handling)
- exif, pcntl, bcmath, gd (image processing)
- zip (file compression)
- intl (internationalization)
- opcache (performance optimization)

**Volume Mounts:**

```
./storage             → /var/www/html/storage           (RW)
./bootstrap/cache     → /var/www/html/bootstrap/cache   (RW)
```

**Proses Startup (docker-entrypoint.sh):**

1. Wait for database connection (max 30 retries × 2 seconds)
2. Generate `APP_KEY` jika belum ada
3. Run migrations (`php artisan migrate --force`)
4. Optimize application (config, route, view cache)
5. Create storage symlink
6. Fix permissions (775 untuk storage & bootstrap/cache)
7. Start PHP-FPM

**Health Check:**

```bash
php-fpm -t
# Test PHP-FPM configuration
# Interval: 30s, Timeout: 10s, Retries: 3, Start Period: 40s
```

### 2. Service: `web` (Nginx)

**Base Image:** `nginx:1.27-alpine`  
**Container Name:** `pkumi_web`  
**Internal Port:** 80  
**Exposed Port:** ✅ `18081:80` (host:container)

**Volume Mounts:**

```
./docker/nginx/default.conf  → /etc/nginx/conf.d/default.conf  (RO)
./storage                    → /var/www/html/storage           (RO)
./public                     → /var/www/html/public            (RO)
```

**Nginx Configuration Highlights:**

- **Root Directory:** `/var/www/html/public`
- **PHP Handler:** FastCGI pass ke `app:9000`
- **Health Endpoint:** `/health` (return 200 "healthy")
- **Static Files Caching:** 30 days untuk images, CSS, JS, fonts
- **Try Files:** Laravel-style routing (try_files → index.php)

**Dependencies:**

- Depends on `app` service dengan `condition: service_healthy`
- Nginx tidak akan start sebelum PHP-FPM ready

**Health Check:**

```bash
wget --quiet --tries=1 --spider http://localhost/health
# Interval: 10s, Timeout: 5s, Retries: 3, Start Period: 10s
```

### 3. Service: `db` (MySQL)

**Base Image:** `mysql:8.0`  
**Container Name:** `pkumi_db`  
**Internal Port:** 3306  
**Exposed Port:** ❌ **TIDAK exposed** (security by design)  
**Volume Mounts:**

```
pkumi_mysql_data  → /var/lib/mysql  (Named volume, persistent)
```

**Environment Variables:**

- `MYSQL_DATABASE`: Database name yang akan dibuat otomatis
- `MYSQL_USER`: Non-root user
- `MYSQL_PASSWORD`: Password untuk MYSQL_USER
- `MYSQL_ROOT_PASSWORD`: Password untuk root user

**Health Check:**

```bash
mysqladmin ping -h localhost -u root -p${DB_ROOT_PASSWORD}
# Interval: 10s, Timeout: 5s, Retries: 5, Start Period: 30s
```

**Persistent Data:**

Data MySQL disimpan di named volume `pkumi_mysql_data` sehingga tetap ada meskipun container dihapus.
```

**Persistent Data:**
Data MySQL disimpan di named volume `pkumi_mysql_data` sehingga tetap ada meskipun container dihapus.

## 🗂️ Docker Volumes

| Volume Name                    | Type         | Mount Point                       | Deskripsi                              |
|--------------------------------|--------------|-----------------------------------|----------------------------------------|
| `pkumi_mysql_data`             | Named Volume | `/var/lib/mysql`                  | Persistent MySQL data                  |
| `./storage`                    | Bind Mount   | `/var/www/html/storage`           | Laravel storage (uploads, logs, cache) |
| `./bootstrap/cache`            | Bind Mount   | `/var/www/html/bootstrap/cache`   | Laravel bootstrap cache                |
| `./public`                     | Bind Mount   | `/var/www/html/public`            | Public assets (web only, read-only)    |
| `./docker/nginx/default.conf`  | Bind Mount   | `/etc/nginx/conf.d/default.conf`  | Nginx config (read-only)               |

**Volume Backup:**

```powershell
# Backup MySQL data
docker run --rm -v pkumi_mysql_data:/data -v ${PWD}:/backup alpine tar czf /backup/mysql_backup.tar.gz -C /data .

# Restore MySQL data
docker run --rm -v pkumi_mysql_data:/data -v ${PWD}:/backup alpine tar xzf /backup/mysql_backup.tar.gz -C /data
```

## 🌐 Docker Network

**Network Name:** `pkumi_network`  
**Driver:** `bridge`  
**Type:** Isolated internal network
**Komunikasi Antar-Container:**

- `web` → `app`: nginx connect ke `app:9000` (FastCGI)
- `app` → `db`: Laravel connect ke `db:3306` (MySQL)
- Semua service berkomunikasi menggunakan service name sebagai hostname

**Security:**

- Database **tidak** exposed ke host machine (no port mapping)
- Hanya web service yang dapat diakses dari luar (port 18081)
- Container-to-container communication isolated dari host network
- Container-to-container communication isolated dari host network

## 🛠️ Docker Commands Reference

### Basic Operations

```powershell
# Build image (first time atau setelah Dockerfile berubah)
docker-compose build

# Start dengan database internal
docker-compose --profile db up -d

# Start tanpa database (gunakan database eksternal)
docker-compose up -d

# Stop semua containers
docker-compose down

# Stop dan hapus volumes (⚠️ data MySQL akan hilang!)
docker-compose down -v

# Restart specific service
docker-compose restart app
docker-compose restart web

# Rebuild dan restart service tertentu
docker-compose up -d --no-deps --build app
```

### Logs & Monitoring

```powershell
# View logs semua services
docker-compose logs -f

# View logs specific service
docker-compose logs -f app
docker-compose logs -f web
docker-compose logs -f db

# View last 100 lines
docker-compose logs --tail=100 app

# Check containers status dan health
docker-compose ps
```

### Debugging & Inspection

```powershell
# Exec into container
docker-compose exec app sh
docker-compose exec web sh
docker-compose exec db bash

# Check PHP-FPM config
docker-compose exec app php-fpm -t

# Check PHP extensions
docker-compose exec app php -m

# Test database connection
docker-compose exec app php artisan db:show

# Check Laravel configuration
docker-compose exec app php artisan config:show database
```

### Laravel Artisan Commands

```powershell
# Run migrations
docker-compose exec app php artisan migrate

# Rollback migrations
docker-compose exec app php artisan migrate:rollback

# Seed database
docker-compose exec app php artisan db:seed

# Clear all caches
docker-compose exec app php artisan optimize:clear

# Cache configuration (production optimization)
docker-compose exec app php artisan config:cache
docker-compose exec app php artisan route:cache
docker-compose exec app php artisan view:cache

# Generate APP_KEY manually
docker-compose exec app php artisan key:generate

# Create storage link
docker-compose exec app php artisan storage:link
```

### Database Management

```powershell
# MySQL client (jika pakai container db)
docker-compose exec db mysql -u pkumi_user -p pkumi_db

# Dump database
docker-compose exec db mysqldump -u pkumi_user -ppkumi_secure_2025 pkumi_db > backup.sql

# Import database
Get-Content backup.sql | docker-compose exec -T db mysql -u pkumi_user -ppkumi_secure_2025 pkumi_db

# Check MySQL status
docker-compose exec db mysqladmin -u root -p status
```

## 🔄 Deployment Scenarios

### Scenario 1: Development (Database Internal)

Cocok untuk development lokal atau testing.

```powershell
# 1. Setup environment
Copy-Item .env.docker .env

# 2. Edit .env (optional)
# DB_HOST=db
# APP_DEBUG=true
# APP_ENV=local

# 3. Start dengan database
docker-compose --profile db up -d --build

# 4. Access
# http://localhost:18081
```

**Pros:**
- Self-contained, mudah setup
- Tidak perlu database eksternal

**Cons:**
- Data hilang jika volume dihapus
- Tidak suitable untuk production
```powershell
# 1. Setup environment
Copy-Item .env.docker .env

# 2. Edit .env untuk database eksternal
# DB_HOST=your-db-host.rds.amazonaws.com
# DB_PORT_INTERNAL=3306
# DB_DATABASE=pkumi_prod
# DB_USERNAME=prod_user
# DB_PASSWORD=secure_password_here
# APP_DEBUG=false
# APP_ENV=production

# 3. Start tanpa database container
docker-compose up -d --build

# 4. Access
# http://your-server-ip:18081
```

**Pros:**
- Database terkelola dengan backup otomatis
- Scalable dan production-ready

**Cons:**
- Perlu setup database eksternal terlebih dahulu

### Scenario 3: Multiple Instances (Load Balancing)

Menjalankan multiple instances aplikasi di server yang sama.

```powershell
# Instance 1
$env:APP_PORT=18081
docker-compose -p pkumi_prod up -d

# Instance 2
$env:APP_PORT=18082
docker-compose -p pkumi_staging up -d
```

Kemudian setup reverse proxy (nginx/traefik) untuk load balancing.

**Pros:**
- Multiple environments di satu server
- Resource efficiency

**Cons:**
- Perlu reverse proxy untuk load balancing

## 🔍 Troubleshooting

### Problem: 502 Bad Gateway

**Symptom:** Nginx return 502 error

**Possible Causes & Solutions:**

1. **PHP-FPM belum ready**
   ```powershell
   # Check app container health
   docker-compose ps
   # Lihat logs
   docker-compose logs app
   ```

2. **Database connection timeout**
   - Jika menggunakan `DB_HOST=db` tapi tidak start dengan `--profile db`
   ```powershell
   # Solution: Start dengan database
   docker-compose down
   docker-compose --profile db up -d
   ```

3. **Nginx config salah**
   ```powershell
   # Check nginx config
   docker-compose exec web nginx -t
   # Check fastcgi_pass should be: app:9000
   ```

### Problem: Container Restart Loop

**Symptom:** Container terus restart

```powershell
# Check logs untuk error message
docker-compose logs --tail=50 app

# Common issues:
# 1. Database connection error → Check DB_HOST, DB_PASSWORD
# 2. Permission error → Lihat entrypoint logs
# 3. Invalid APP_KEY → Will be auto-generated on first run
```

**Solutions:**
```powershell
# Fix permissions
docker-compose exec app chown -R www-data:www-data storage bootstrap/cache
docker-compose exec app chmod -R 775 storage bootstrap/cache

# Regenerate APP_KEY
docker-compose exec app php artisan key:generate

# Clear all caches
docker-compose exec app php artisan optimize:clear
```

### Problem: Database Connection Refused

**Symptom:** `SQLSTATE[HY000] [2002] Connection refused`

**Solutions:**

1. **Check DB_HOST di .env**
   ```env
   # Untuk container internal
   DB_HOST=db
   
   # Untuk database eksternal
   DB_HOST=your-database-host
   ```

2. **Check database container running**
   ```powershell
   docker-compose ps db
   # Jika tidak ada, start dengan --profile db
   docker-compose --profile db up -d
   ```

3. **Check database healthy**
   ```powershell
   docker-compose exec db mysqladmin ping -h localhost -u root -p
   ```

### Problem: Port Already in Use

**Symptom:** `Bind for 0.0.0.0:18081 failed: port is already allocated`

**Solutions:**

1. **Change port di .env**
   ```env
   APP_PORT=18082  # atau port lain yang available
   ```

2. **Stop conflicting service**
   ```powershell
   # Check apa yang pakai port 18081
   netstat -ano | findstr :18081
   # Stop process atau ganti port
   ```

### Problem: Permission Denied (Storage/Logs)

**Symptom:** `The stream or file "storage/logs/laravel.log" could not be opened: failed to open stream: Permission denied`

**Solution:**
```powershell
# Fix permissions dari dalam container
docker-compose exec app chown -R www-data:www-data storage bootstrap/cache
docker-compose exec app chmod -R 775 storage bootstrap/cache

# Atau rebuild container (permissions di-set saat entrypoint)
docker-compose down
docker-compose --profile db up -d --build
## 📚 Tech Stack

- **Framework:** Laravel 12
- **PHP:** 8.3 FPM (Alpine Linux)
- **Web Server:** Nginx 1.27 (Alpine Linux)
- **Database:** MySQL 8.0
- **Frontend:** Tailwind CSS 4, Alpine.js 3, Vite 7
- **Additional Libraries:**
  - maatwebsite/excel (Export/Import Excel)
  - barryvdh/laravel-dompdf (Generate PDF)
  - laravel/sanctum (API Authentication)el)
  - barryvdh/laravel-dompdf (Generate PDF)
  - laravel/sanctum (API Authentication)

## 🔐 Security Recommendations

### Production Checklist

- [ ] Ganti semua default passwords di `.env`
- [ ] Set `APP_DEBUG=false`
- [ ] Set `APP_ENV=production`
- [ ] Gunakan database eksternal (managed service)
- [ ] Setup SSL/TLS dengan reverse proxy (nginx/traefik)
- [ ] Setup firewall rules (hanya allow port 80/443)
- [ ] Regular backup database dan volumes
- [ ] Enable fail2ban untuk SSH brute force protection
- [ ] Setup monitoring & alerting (Prometheus, Grafana)
- [ ] Implement rate limiting di nginx
- [ ] Restrict MySQL user privileges (hanya grant yang diperlukan)

### Database Security

```sql
-- Buat user dengan minimal privileges
CREATE USER 'pkumi_user'@'%' IDENTIFIED BY 'strong_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON pkumi_db.* TO 'pkumi_user'@'%';
FLUSH PRIVILEGES;
```

## 📖 Dokumentasi Laravel

- Official Documentation: https://laravel.com/docs/12.x
- Laravel Best Practices: https://github.com/alexeymezenin/laravel-best-practices

## 👥 Contributors

- **Dzikri Mustaqim** - [@dzikrimustaqim](https://github.com/dzikrimustaqim)

## 📄 License

This project is licensed under the MIT License.
