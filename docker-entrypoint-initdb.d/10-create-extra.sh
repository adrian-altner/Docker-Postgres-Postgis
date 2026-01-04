#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[initdb-extra] $*"
}

psql_admin() {
  psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname postgres "$@"
}

create_role() {
  local role_name="$1"
  local role_pass="$2"

  if [[ -z "${role_name}" || -z "${role_pass}" ]]; then
    log "ERROR: EXTRA_USERS entry requires username:password"
    exit 1
  fi

  log "Ensuring role exists: ${role_name}"
  psql_admin --set=role_name="${role_name}" --set=role_pass="${role_pass}" <<'SQL'
DO $$
DECLARE
  name text := :'role_name';
  pass text := :'role_pass';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = name) THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', name, pass);
  END IF;
END $$;
SQL
}

create_db() {
  local db_name="$1"
  local owner_name="${2:-${POSTGRES_USER}}"

  if [[ -z "${db_name}" ]]; then
    log "ERROR: EXTRA_DATABASES entry requires db_name or db_name:owner"
    exit 1
  fi

  log "Ensuring database exists: ${db_name} (owner: ${owner_name})"
  psql_admin --set=db_name="${db_name}" --set=owner_name="${owner_name}" <<'SQL'
DO $$
DECLARE
  db text := :'db_name';
  owner_role text := :'owner_name';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = db) THEN
    EXECUTE format('CREATE DATABASE %I OWNER %I', db, owner_role);
  END IF;
END $$;
SQL
}

enable_extensions() {
  local db_name="$1"
  local extensions_csv="$2"

  if [[ -z "${extensions_csv}" ]]; then
    return 0
  fi

  IFS=',' read -r -a extensions <<< "${extensions_csv}"
  for ext in "${extensions[@]}"; do
    ext="$(echo "${ext}" | xargs)"
    [[ -z "${ext}" ]] && continue
    log "Ensuring extension in ${db_name}: ${ext}"
    psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${db_name}" \
      --set=ext_name="${ext}" <<'SQL'
DO $$
DECLARE
  ext text := :'ext_name';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = ext) THEN
    EXECUTE format('CREATE EXTENSION %I', ext);
  END IF;
END $$;
SQL
  done
}

main() {
  local extra_users="${EXTRA_USERS:-}"
  local extra_databases="${EXTRA_DATABASES:-}"
  local extra_extensions="${EXTRA_EXTENSIONS:-}"

  if [[ -z "${extra_users}${extra_databases}${extra_extensions}" ]]; then
    log "No EXTRA_USERS/EXTRA_DATABASES/EXTRA_EXTENSIONS set; skipping."
    return 0
  fi

  if [[ -n "${extra_users}" ]]; then
    IFS=',' read -r -a users <<< "${extra_users}"
    for user_spec in "${users[@]}"; do
      user_spec="$(echo "${user_spec}" | xargs)"
      [[ -z "${user_spec}" ]] && continue
      if [[ "${user_spec}" != *:* ]]; then
        log "ERROR: Invalid EXTRA_USERS entry: '${user_spec}' (expected username:password)"
        exit 1
      fi
      create_role "${user_spec%%:*}" "${user_spec#*:}"
    done
  fi

  if [[ -n "${extra_databases}" ]]; then
    IFS=',' read -r -a dbs <<< "${extra_databases}"
    for db_spec in "${dbs[@]}"; do
      db_spec="$(echo "${db_spec}" | xargs)"
      [[ -z "${db_spec}" ]] && continue
      if [[ "${db_spec}" == *:* ]]; then
        create_db "${db_spec%%:*}" "${db_spec#*:}"
        enable_extensions "${db_spec%%:*}" "${extra_extensions}"
      else
        create_db "${db_spec}" "${POSTGRES_USER}"
        enable_extensions "${db_spec}" "${extra_extensions}"
      fi
    done
  fi

  if [[ -n "${extra_extensions}" ]]; then
    log "Ensuring extensions in default database: ${POSTGRES_DB}"
    enable_extensions "${POSTGRES_DB}" "${extra_extensions}"
  fi
}

main "$@"
