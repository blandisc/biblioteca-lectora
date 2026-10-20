#!/usr/bin/env bash
# Regla del sistema de diseño (docs/sistema-diseno.md): las pantallas no usan
# números, colores ni fuentes sueltos; todo sale de Theme y de Components.
# Revisa App/Shared/Screens y el lector. Uso: scripts/lint-design.sh
set -uo pipefail
cd "$(dirname "$0")/.."

files=$(ls App/Shared/Screens/*.swift App/Shared/Reader/ReaderView.swift)
pattern='(\.padding\(|spacing: |\.frame\(|cornerRadius: |lineWidth: |\.opacity\(|\.offset\()([^)]*[^A-Za-z_.0-9])?[1-9][0-9]*(\.[0-9]+)?|Color\(hex|\.system\(size|Font\.custom'

violations=$(grep -nE "$pattern" $files | grep -vE '^\S+:\s*[0-9]+:\s*//' | grep -v 'lint-design: permitido')
if [ -n "$violations" ]; then
  echo "Valores sueltos fuera del sistema de diseño (usa tokens de Theme o un componente):"
  echo "$violations"
  exit 1
fi
echo "Sistema de diseño: sin valores sueltos en $(echo "$files" | wc -w | tr -d ' ') archivos."
