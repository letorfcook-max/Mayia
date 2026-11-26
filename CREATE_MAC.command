#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
[[ $(uname -s) == Darwin ]] || { echo 'Run this on macOS.'; exit 1; }
npm install --no-audit --no-fund
npm run check
npm run dist:mac
printf 'Build output: %s/release\n' "$PWD"
