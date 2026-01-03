## Überblick

Dieses Setup betreibt **PostgreSQL 16 + PostGIS** per Docker Compose (Dokploy/Hetzner).  
PostGIS wird über ein **lokal gebautes Image** installiert (wichtig, wenn du nicht auf ein fertiges `postgis/*` Image setzen willst).

Persistenz erfolgt über einen **Bind-Mount** nach `/srv/postgres/pgdata` auf dem Host.

---

## Voraussetzungen

- Docker + Compose Plugin: `docker compose version`
- Zugriff als `root` oder via `sudo`
- `.env` im selben Ordner wie `docker-compose.yml` mit:
  - `POSTGRES_USER`
  - `POSTGRES_PASSWORD`
  - `POSTGRES_DB`

Beispiel `.env`:

```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=CHANGEME
POSTGRES_DB=db_name
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

```bash
docker exec -it postgres psql -U postgres -d db_name
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
docker exec -t postgres pg_dump -U postgres -d db_name -Fc > db_name.dump
```

Restore:

```bash
cat db_name.dump | docker exec -i postgres pg_restore -U postgres -d db_name --no-owner --no-acl -v
```

---

## 5) Updates (über GitHub/Dokploy)

Nach einem Pull/Deploy (neues `Dockerfile` oder Compose-Änderungen):

```bash
docker compose build postgres
docker compose up -d
```

PostGIS musst du nur einmal pro DB aktivieren (Step 3).
