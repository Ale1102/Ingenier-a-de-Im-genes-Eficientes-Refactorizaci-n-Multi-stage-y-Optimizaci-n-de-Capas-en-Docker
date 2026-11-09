# Ecosistema Docker: Next.js + Laravel + MySQL

Entorno de producción contenerizado con tres servicios (frontend, API y base de datos), imágenes optimizadas con builds multi-stage y orquestación con un único `docker-compose.yml`.

## Estructura

```
.
├── docker-compose.yml
├── .env.example
├── database/init/01-init.sql     # script opcional -> /docker-entrypoint-initdb.d/
├── frontend/                     # Next.js 16 (App Router)
│   ├── Dockerfile
│   └── .dockerignore
└── backend/                      # Laravel 13 (API)
    ├── Dockerfile                # targets: app (PHP-FPM) y web (Nginx)
    ├── .dockerignore
    └── docker/                   # nginx.conf, php.ini, entrypoint.sh
```

## Arquitectura de contenedores

```
                 Host
        :3000                :8000
          │                    │
   ┌──────▼──────┐      ┌──────▼──────┐
   │  frontend   │      │  web (Nginx)│
   │  Next.js    │      └──────┬──────┘
   └─────────────┘             │ FastCGI :9000
        (el navegador          │
         llama a la API   ┌────▼────────┐        ┌────────────┐
         en :8000)        │ app PHP-FPM │──3306─►│  db MySQL  │
                          │  (Laravel)  │        │ vol: db_data│
                          └─────────────┘        └────────────┘
                          └──── red interna backend-net ─────┘
```

- `frontend` publica el puerto 3000. Consume la API desde el navegador vía `NEXT_PUBLIC_API_URL`.
- `web` (Nginx) publica el puerto 8000 y reenvía a `app:9000` (PHP-FPM).
- `db` **no publica el puerto 3306**: solo es accesible dentro de la red `backend-net`.
- Los datos viven en el volumen `db_data` montado en `/var/lib/mysql`.

## Ejecución

Requisitos: Docker con Compose v2.

```bash
cp .env.example .env
# Editar .env: definir contraseñas y APP_KEY
# Generar APP_KEY:
docker run --rm php:8.3-cli php -r "echo 'base64:'.base64_encode(random_bytes(32)).PHP_EOL;"

docker compose up -d --build
```

- Frontend: http://localhost:3000
- API: http://localhost:8000/api/health
- Logs: `docker compose logs -f`
- Detener: `docker compose down` (añadir `-v` borra los datos de MySQL)

Las migraciones se ejecutan al iniciar `app` si `RUN_MIGRATIONS=true`.

## Decisiones técnicas

### Frontend (`frontend/Dockerfile`)
- **Tres etapas** (`deps` → `builder` → `runner`), todas sobre `node:20-alpine`.
- **`deps`** copia solo `package.json` y `package-lock.json` antes del código: `npm ci` queda en caché de capa mientras no cambien las dependencias. Se usa además un cache mount de npm.
- **`builder`** ejecuta `next build`. `NEXT_PUBLIC_API_URL` entra como `ARG` porque Next.js lo incrusta en el bundle durante el build.
- **`runner`** usa `output: "standalone"` (en `next.config.ts`): solo se copia `.next/standalone`, `.next/static` y `public`, sin `node_modules` completo ni código fuente ni dependencias de desarrollo.
- Se ejecuta como usuario no root (`nextjs`) y define `HEALTHCHECK`.
- Nota: el servidor standalone (`node server.js`) es el equivalente optimizado a `next start`.

### Backend (`backend/Dockerfile`)
- **Etapa `vendor`** (`composer:2`): copia primero `composer.json`/`composer.lock` e instala con `--no-dev`, aprovechando la caché de capas. Luego genera el autoloader optimizado (`--classmap-authoritative`).
- **Etapa `app`** (`php:8.3-fpm-alpine`): solo se instala `pdo_mysql` y `opcache`; `mbstring`, `openssl`, `tokenizer`, `xml`, `ctype` y `json` ya vienen compilados en la imagen oficial y el build verifica que estén cargados. De la etapa anterior solo se copia `vendor/`, por lo que Composer no está en la imagen final.
- **Etapa `web`** (`nginx:1.27-alpine`): imagen separada de solo ~74 MB, con un único `nginx.conf` que reenvía a PHP-FPM y solo ejecuta `index.php`.
- PHP-FPM corre como `www-data` (no root), con `opcache` y `expose_php=Off`.
- `entrypoint.sh` genera las cachés de config, rutas y vistas en runtime (cuando las variables de entorno ya existen) y opcionalmente migra.
- **Versión de PHP:** Laravel 13 requiere PHP ≥ 8.3, por eso se usa 8.3 en lugar de 8.2. `composer.json` fija `config.platform.php = 8.3.0` para que el lock sea reproducible aunque el desarrollador use otra versión local.
- `.dockerignore` excluye `.env`, `vendor`, `tests` y cachés locales de `bootstrap/cache` (evitan que providers de desarrollo se cuelen en la imagen).

### Base de datos (`mysql:8.0`)
- Configuración por variables de entorno (`MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`). Compose falla si faltan las obligatorias.
- Volumen nombrado para persistencia y script de inicialización montado de solo lectura en `/docker-entrypoint-initdb.d/`.
- `healthcheck` con `mysqladmin ping`; la API espera con `depends_on: condition: service_healthy`.
- Sin puerto publicado al host.

### Seguridad y reproducibilidad
- Imágenes Alpine, usuarios no root en frontend y PHP-FPM, sin secretos en las imágenes (todo viene del `.env`, ignorado por git).
- Versiones de imágenes fijadas por tag y dependencias fijadas por `package-lock.json` y `composer.lock`.

## Tamaños de imagen (verificados localmente)

| Imagen | Tamaño |
|---|---|
| frontend | ~288 MB |
| app (PHP-FPM) | ~181 MB |
| web (Nginx) | ~74 MB |
