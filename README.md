## Überblick

Dieses Setup betreibt **PostgreSQL 16 + PostGIS** per Docker Compose (Dokploy/Hetzner).  
PostGIS wird über ein **lokal gebautes Image** installiert (wichtig, wenn du nicht auf ein fertiges `postgis/*` Image setzen willst).

Persistenz erfolgt über einen **Bind-Mount** nach `/srv/postgres/pgdata` auf dem Host.  
Hinweis: `PGDATA` zeigt auf ein Unterverzeichnis (`/var/lib/postgresql/data/pgdata`), damit `initdb` auch dann funktioniert, wenn das Mount-Root nicht leer ist.

---

## Voraussetzungen

- Docker + Compose Plugin: `docker compose version`
- Zugriff als `root` oder via `sudo`
- (Dokploy) Externes Docker-Netzwerk `dokploy-network` (wird von Dokploy i.d.R. angelegt; sonst einmalig: `docker network create dokploy-network`)
- `.env` im selben Ordner wie `docker-compose.yml` mit:
  - `POSTGRES_PASSWORD` (Pflicht)
  - optional: `POSTGRES_USER`, `POSTGRES_DB`

Beispiel `.env`:

```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=CHANGEME
POSTGRES_DB=postgres

# optional: zusätzliche User/DBs + Extensions (laufen nur beim ersten Init, wenn PGDATA leer ist)
# Format: comma-separated
EXTRA_USERS=app_user:CHANGEME,readonly_user:CHANGEME
EXTRA_DATABASES=app_db:app_user,readonly_db:readonly_user
EXTRA_EXTENSIONS=postgis,pgcrypto
```

---

## 1) Datenordner (Bind-Mount) auf dem Host anlegen

Einmalig auf dem Server:

```bash
mkdir -p /srv/postgres/pgdata
chown -R 999:999 /srv/postgres/pgdata
```

Hinweis: UID/GID `999:999` ist im offiziellen `postgres` Image üblich. Falls du Permission-Fehler siehst, prüfe den Container-User und passe Ownership an.

---

## 2) Image bauen und Container starten

Im Ordner `Dokploy/Postgres/`:

```bash
docker compose build postgres
docker compose up -d
```

Status/Logs:

```bash
docker compose ps
docker compose logs -f postgres
```

Wichtig:
- **Kein** `docker compose down -v` (würde named volumes löschen; bei Bind-Mount bleibt der Ordner bestehen, aber “-v” ist trotzdem unnötig/destruktiv in anderen Services).

---

## 3) PostGIS in der Datenbank aktivieren

PostGIS ist **pro Datenbank** eine Extension (Installation im Image reicht nicht).

Optional: Wenn du `EXTRA_EXTENSIONS=postgis` setzt, wird PostGIS beim ersten Init automatisch aktiviert.

```bash
docker compose exec postgres psql -U postgres -d postgres
```

In `psql`:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
SELECT PostGIS_full_version();
```

Quick-Test:

```sql
SELECT ST_AsText(ST_Point(13.4050, 52.5200));
```

---

## 4) Backup / Restore (empfohlen vor Änderungen)

Backup (Custom Format):

```bash
docker compose exec -T postgres pg_dump -U postgres -d postgres -Fc > postgres.dump
```

Restore:

```bash
cat postgres.dump | docker compose exec -T postgres pg_restore -U postgres -d postgres --no-owner --no-acl -v
```

---

## 5) Updates (über GitHub/Dokploy)

Nach einem Pull/Deploy (neues `Dockerfile` oder Compose-Änderungen):

```bash
docker compose build postgres
docker compose up -d
```

PostGIS musst du nur einmal pro DB aktivieren (Step 3).

---

## Extra User/DBs nachträglich anlegen (re-run)

Wenn `PGDATA` bereits existiert, laufen Init-Skripte nicht mehr automatisch. Du kannst die Extra-Erstellung dann jederzeit idempotent ausführen:

```bash
chmod +x scripts/pg-extra-apply.sh
./scripts/pg-extra-apply.sh
```

Optional (Overrides nur für diesen Lauf):

```bash
EXTRA_USERS='app_user:CHANGEME' EXTRA_DATABASES='app_db:app_user' EXTRA_EXTENSIONS='postgis,pgcrypto' ./scripts/pg-extra-apply.sh
```

Zusätzlich wird im Container (und damit auf dem Host unter `/srv/postgres/pgdata`) ein persistentes Script bereitgestellt:

```bash
docker compose exec -T postgres /var/lib/postgresql/data/pg-extra-apply.sh
```

Mit Overrides:

```bash
docker compose exec -T -e EXTRA_USERS='app_user:CHANGEME' -e EXTRA_DATABASES='app_db:app_user' -e EXTRA_EXTENSIONS='postgis,pgcrypto' postgres /var/lib/postgresql/data/pg-extra-apply.sh
```
