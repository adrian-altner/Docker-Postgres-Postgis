POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=f00na9pd21qvyost

Dokploy Netzwerk: `dokploy-network` (Compose nutzt ein externes Netzwerk mit diesem Namen).

## PostGIS (Apple Silicon / lokal bauen)

Wenn du auf Apple Silicon bist oder kein fertiges `postgis/*` Image nutzen kannst, baue das Postgres-Image mit PostGIS lokal:

- `cd Postgres`
- `docker compose build postgres`
- `docker compose up -d`

PostGIS pro Datenbank aktivieren:

- `docker exec -it postgres psql -U postgres -d adrian_altner_com_db`
- `CREATE EXTENSION IF NOT EXISTS postgis;`
- `SELECT PostGIS_full_version();`

terminal

nur für Root Console
apt install postgresql-client-common


## 1. In den PostgreSQL-Container einloggen

```bash
docker compose exec postgres psql -U postgres 
```

postgres=# \conninfo
You are connected to database "postgres" as user "postgres" via socket in "/var/run/postgresql" at port "5432".

## 2. Projekt-User anlegen

```sql
CREATE ROLE adrian_altner_com_user WITH LOGIN PASSWORD 'hgz2bgnDBJqKdSvh';
```

## 3. Projekt-Datenbank anlegen

```sql
CREATE DATABASE adrian_altner_com_db OWNER adrian_altner_com_user ENCODING 'UTF8';
```

## 5. Öffentliche Default-Rechte entfernen (Best Practice)

1. In die DB wechseln
\c adrian_altner_com_db


```sql

-- 2) Rechte auf der DB
REVOKE ALL ON DATABASE adrian_altner_com_db FROM PUBLIC;
GRANT CONNECT, TEMP ON DATABASE adrian_altner_com_db TO adrian_altner_com_user;

-- 3) Rechte auf dem public-Schema
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE, CREATE ON SCHEMA public TO adrian_altner_com_user;

-- 4) Defaults fuer neue Objekte (falls Owner = postgres)
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO adrian_altner_com_user;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO adrian_altner_com_user;
```

## 6. Optionale Extensions (empfohlen)

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

## 7. Kontrolle

```sql
\l
\q

\du
SELECT current_user, current_database();

\c adrian_altner_com_db adrian_altner_com_user
SELECT current_user, current_database();
```
!!! Command \l öffnet in less, mit q verlassen
