#!/usr/bin/env bash
set -euo pipefail

pgdata="${PGDATA:-/var/lib/postgresql/data}"
host_script="${pgdata%/}/pg-extra-apply.sh"
template="/usr/local/bin/pg-extra-apply.template.sh"

pgdata_dir="${pgdata%/}"
pgdata_parent="$(dirname "${pgdata_dir}")"
if [[ ! -f "${pgdata_dir}/PG_VERSION" && -f "${pgdata_parent}/PG_VERSION" ]]; then
  echo "[entrypoint-wrapper] ERROR: PGDATA is set to '${pgdata_dir}', but an existing cluster was found at '${pgdata_parent}'." >&2
  echo "[entrypoint-wrapper] ERROR: Fix the volume mount or set PGDATA to '${pgdata_parent}' to avoid initializing a new empty cluster." >&2
  exit 1
fi

if [[ -f "${template}" && -f "${pgdata%/}/PG_VERSION" && ! -f "${host_script}" ]]; then
  host_dir="$(dirname "${host_script}")"
  if [[ -d "${host_dir}" && -w "${host_dir}" ]]; then
    if cp -f "${template}" "${host_script}"; then
      chmod 0755 "${host_script}" || true
    else
      echo "[entrypoint-wrapper] WARN: could not write ${host_script}; continuing." >&2
    fi
  else
    echo "[entrypoint-wrapper] WARN: ${host_dir} not writable; skipping ${host_script} creation." >&2
  fi
fi

exec /usr/local/bin/docker-entrypoint.sh "$@"
