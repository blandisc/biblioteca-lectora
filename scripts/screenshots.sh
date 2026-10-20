#!/usr/bin/env bash
# Toma capturas de la app en el simulador de iPhone: los dos estilos, en claro
# y oscuro, de cada pestaña y del lector. Uso: scripts/screenshots.sh <carpeta>
set -euo pipefail

OUT=${1:-capturas}
BUNDLE=com.example.lectora
mkdir -p "$OUT"

DEVICE=$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
found = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match:
        continue
    for device in devices:
        if re.fullmatch(r"iPhone \d+ Pro", device["name"]):
            found.append((tuple(map(int, match.groups())), device["name"], device["udid"]))
found.sort()
print(found[-1][2])
')
echo "Simulador: $DEVICE"
xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b

xcodebuild -project Lectora.xcodeproj -scheme Lectora_iOS -configuration Debug \
  -destination "id=$DEVICE" -derivedDataPath build/screens build CODE_SIGNING_ALLOWED=NO -quiet
xcrun simctl install "$DEVICE" build/screens/Build/Products/Debug-iphonesimulator/Lectora.app
xcrun simctl status_bar "$DEVICE" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 || true

shoot() { # nombre, espera, argumentos…
  local name=$1 wait=$2; shift 2
  xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$DEVICE" "$BUNDLE" "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$DEVICE" screenshot "$OUT/$name.png" >/dev/null
  echo "  $name"
}

for style in native editorial; do
  for mode in light dark; do
    tabs="reading library notebook"
    [ "$style" = native ] && tabs="$tabs search"
    for tab in $tabs; do
      shoot "$style-$mode-$tab" 4 -appearance.style "$style" -appearance.mode "$mode" -screenshot.tab "$tab"
    done
  done
done

# Lector: se copia un EPUB de muestra a la app y se abre al arrancar.
DATA=$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE" data)
mkdir -p "$DATA/Library/Application Support/Spike"
python3 scripts/make-sample-epub.py "$DATA/Library/Application Support/Spike/Don Quijote.epub"
for style in native editorial; do
  for mode in light dark; do
    shoot "$style-$mode-reader" 8 -appearance.style "$style" -appearance.mode "$mode" -screenshot.openFirst YES
  done
done
