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
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'role_name', :'role_pass')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'role_name')
\gexec
SQL
}

create_db() {
  local db_name="$1"
  local owner_name="${2:-${POSTGRES_USER}}"
  local encoding="${3:-}"
  local locale="${4:-}"

  if [[ -z "${db_name}" ]]; then
    log "ERROR: EXTRA_DATABASES entry requires db_name or db_name:owner"
    exit 1
  fi

  # Build log message
  local log_msg="Ensuring database exists: ${db_name} (owner: ${owner_name}"
  [[ -n "${encoding}" ]] && log_msg+=", encoding: ${encoding}"
  [[ -n "${locale}" ]] && log_msg+=", locale: ${locale}"
  log_msg+=")"
  log "${log_msg}"

  # When encoding or locale is specified, use TEMPLATE template0
  if [[ -n "${encoding}" || -n "${locale}" ]]; then
    # Build CREATE DATABASE command with encoding and locale
    local create_cmd="CREATE DATABASE %I OWNER %I TEMPLATE template0"
    [[ -n "${encoding}" ]] && create_cmd+=" ENCODING %L"
    [[ -n "${locale}" ]] && create_cmd+=" LC_COLLATE %L LC_CTYPE %L"

    if [[ -n "${encoding}" && -n "${locale}" ]]; then
      psql_admin --set=db_name="${db_name}" --set=owner_name="${owner_name}" \
                 --set=encoding="${encoding}" --set=locale="${locale}" <<SQL
SELECT format('${create_cmd}', :'db_name', :'owner_name', :'encoding', :'locale', :'locale')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name')
\\gexec
SQL
    elif [[ -n "${encoding}" ]]; then
      psql_admin --set=db_name="${db_name}" --set=owner_name="${owner_name}" \
                 --set=encoding="${encoding}" <<SQL
SELECT format('CREATE DATABASE %I OWNER %I TEMPLATE template0 ENCODING %L', :'db_name', :'owner_name', :'encoding')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name')
\\gexec
SQL
    else
      psql_admin --set=db_name="${db_name}" --set=owner_name="${owner_name}" \
                 --set=locale="${locale}" <<SQL
SELECT format('CREATE DATABASE %I OWNER %I TEMPLATE template0 LC_COLLATE %L LC_CTYPE %L', :'db_name', :'owner_name', :'locale', :'locale')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name')
\\gexec
SQL
    fi
  else
    psql_admin --set=db_name="${db_name}" --set=owner_name="${owner_name}" <<'SQL'
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'owner_name')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name')
\gexec
SQL
  fi
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
SELECT format('CREATE EXTENSION IF NOT EXISTS %I', :'ext_name')
\gexec
SQL
  done
}

main() {
  local extra_users="${EXTRA_USERS:-}"
  local extra_databases="${EXTRA_DATABASES:-}"
  local extra_extensions="${EXTRA_EXTENSIONS:-}"
  local db_encoding="${DB_ENCODING:-}"
  local db_locale="${DB_LOCALE:-}"

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

      # Parse extended format: db_name:owner:encoding:locale
      local db_name owner encoding locale
      IFS=':' read -r db_name owner encoding locale <<< "${db_spec}"

      # Apply defaults
      owner="${owner:-${POSTGRES_USER}}"
      encoding="${encoding:-${db_encoding}}"
      locale="${locale:-${db_locale}}"

      create_db "${db_name}" "${owner}" "${encoding}" "${locale}"
      enable_extensions "${db_name}" "${extra_extensions}"
    done
  fi

  if [[ -n "${extra_extensions}" ]]; then
    log "Ensuring extensions in default database: ${POSTGRES_DB}"
    enable_extensions "${POSTGRES_DB}" "${extra_extensions}"
  fi
}

main "$@"
