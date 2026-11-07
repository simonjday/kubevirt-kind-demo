#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
"${here}/flow-1-lifecycle.sh"
"${here}/flow-2-datavolume.sh"
"${here}/flow-3-live-migration.sh"
