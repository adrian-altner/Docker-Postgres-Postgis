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

echo "[pg-extra-apply] Applying EXTRA_* to running service: ${SERVICE}"
${COMPOSE_CMD} exec -T "${run_env[@]}" "${SERVICE}" bash -lc '/docker-entrypoint-initdb.d/10-create-extra.sh'
