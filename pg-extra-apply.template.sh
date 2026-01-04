#!/usr/bin/env bash
set -euo pipefail

exec bash -lc '/docker-entrypoint-initdb.d/10-create-extra.sh'
