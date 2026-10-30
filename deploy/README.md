# Free single-server deployment

This deployment runs the existing Spring Boot API, MariaDB, uploaded listing/profile/chat files, and HTTPS reverse proxy together on one ARM64 or AMD64 Linux server. The database and uploads use persistent Docker volumes. No MapTiler or Firebase service account credentials are needed by the backend for this setup; mobile map configuration remains in `mobile/maptiler.env.json`.

## Cloud setup

Create an Oracle Cloud Infrastructure Always Free VM, preferably Ubuntu 24.04 on Ampere A1, and assign it a reserved public IP. Always Free capacity can depend on the selected region. Create a free DNS name and point its A record at the VM's public IP. In the OCI network security list and the VM firewall, allow inbound TCP ports 22, 80, and 443. Keep SSH restricted to your own IP where possible.

Install Docker Engine and the Docker Compose plugin on the VM. Clone this GitHub repository onto the server, then from its `deploy` directory:

```sh
cp .env.example .env
nano .env
```

Set `DOMAIN` to the DNS name you pointed at the VM and replace every example password/secret with unique values. Make sure `JWT_SECRET` is a long random value. Do not commit or share `deploy/.env`.

Start the services:

```sh
docker compose --env-file .env -f compose.yml up -d --build
docker compose --env-file .env -f compose.yml logs -f api
```

When startup completes, check `https://YOUR_DOMAIN/actuator/health`; it should report `UP`. Swagger is at `https://YOUR_DOMAIN/swagger-ui.html`. The first launch creates the administrator from `ADMIN_EMAIL` and `ADMIN_PASSWORD`; save those credentials safely.

## Build the Android app for the live server

On the Windows development computer, open PowerShell in the repository root and run:

```powershell
$env:API_BASE_URL = 'https://YOUR_DOMAIN/api'
.\scripts\build-release.ps1
```

The APK will be at `mobile/build/app/outputs/flutter-apk/app-release.apk`. Install that APK on phones. Clear the environment variable when building a local-network APK again.

## Keep data safe

The MariaDB data and media uploads survive container restarts because they are stored in named volumes. Back up both volumes regularly; a VM or disk failure can still lose them. Run `docker compose down` to stop the app without deleting data. Do not use `docker compose down -v` unless you intentionally want to erase the database and uploaded files.

Push notifications outside the app remain disabled until Firebase Cloud Messaging is configured. Database-backed in-app notifications continue to work. Free server resources can be reclaimed or unavailable in some regions, and a single free VM is suitable for a demo or small pilot rather than a critical production service.
