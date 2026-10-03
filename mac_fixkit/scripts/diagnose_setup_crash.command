#!/bin/bash
set -u
OUT="$HOME/Desktop/Mayia-Mac-Diagnostics-$(date +%Y%m%d-%H%M%S).txt"
{
  echo "MAYIA MAC DIAGNOSTICS"
  date
  echo "--- system ---"
  sw_vers
  uname -a
  echo "--- mounted Mayia volumes ---"
  mount | grep -i Mayia || true
  echo "--- recent Mayia crashes ---"
  ls -lt "$HOME/Library/Logs/DiagnosticReports"/*Mayia* 2>/dev/null | head -n 10 || true
  echo "--- setup log ---"
  tail -n 100 "$HOME/Library/Logs/Mayia/setup.log" 2>/dev/null || true
} > "$OUT" 2>&1
open -R "$OUT"
echo "Saved: $OUT"
read -r -p "Press Enter to close..." _
