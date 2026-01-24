#!/usr/bin/env bash
set -euo pipefail

SERVICE="${SERVICE:-postgres}"
COMPOSE_CMD="${COMPOSE_CMD:-docker compose}"

run_env=()
if [[ -n "${EXTRA_USERS:-}" ]]; then
  run_env+=(-e "EXTRA_USERS=${EXTRA_USERS}")
fi
if [[ -n "${EXTRA_DATABASES:-}" ]]; then
  run_env+=(-e "EXTRA_DATABASES=${EXTRA_DATABASES}")
fi
if [[ -n "${EXTRA_EXTENSIONS:-}" ]]; then
  run_env+=(-e "EXTRA_EXTENSIONS=${EXTRA_EXTENSIONS}")
fi
if [[ -n "${DB_ENCODING:-}" ]]; then
  run_env+=(-e "DB_ENCODING=${DB_ENCODING}")
fi
if [[ -n "${DB_LOCALE:-}" ]]; then
  run_env+=(-e "DB_LOCALE=${DB_LOCALE}")
fi

echo "[pg-extra-apply] Applying EXTRA_* to running service: ${SERVICE}"
${COMPOSE_CMD} exec -T "${run_env[@]}" "${SERVICE}" bash -lc '/docker-entrypoint-initdb.d/10-create-extra.sh'
