#!/usr/bin/env bash
set -euo pipefail

host_script="/var/lib/postgresql/data/pg-extra-apply.sh"
template="/usr/local/bin/pg-extra-apply.template.sh"

if [[ -f "${template}" && ! -f "${host_script}" ]]; then
  cp -f "${template}" "${host_script}"
  chmod 0755 "${host_script}"
fi

exec /usr/local/bin/docker-entrypoint.sh "$@"
