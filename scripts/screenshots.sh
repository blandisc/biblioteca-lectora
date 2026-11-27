#!/usr/bin/env bash
# Toma capturas de la app en el simulador de iPhone: los dos estilos, en claro
# y oscuro, de cada pestaña y del lector. Uso: scripts/screenshots.sh <carpeta>
# Opcional: SKIP_BUILD=1, DEVICE=<udid> (el simulador del proyecto, «Gabinete») y DERIVED=<carpeta>
# (en el Mac, /tmp/dd-gabinete, la misma de todas las sesiones).
set -euo pipefail

OUT=${1:-capturas}
BUNDLE=mx.iracheta.gabinete
mkdir -p "$OUT"

DEVICE=${DEVICE:-$(xcrun simctl list devices available -j | python3 -c '
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
')}
echo "Simulador: $DEVICE"
xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b

# SKIP_BUILD=1 reutiliza la app ya compilada en DERIVED.
# Para revisar a mano lo que pasa con iCloud (solo en DEBUG): `-screenshot.cloud downloading`
# abre con «Bajando tu biblioteca» y `-screenshot.cloud gaveUp` como si ya no la esperara
# (p. ej. xcrun simctl launch <udid> <bundle> -screenshot.cloud downloading).
[ -n "${SKIP_BUILD:-}" ] || xcodebuild -project Lectora.xcodeproj -scheme Lectora_iOS -configuration Debug \
  -destination "id=$DEVICE" -derivedDataPath "${DERIVED:-build/screens}" build CODE_SIGNING_ALLOWED=NO -quiet
xcrun simctl install "$DEVICE" "${DERIVED:-build/screens}"/Build/Products/Debug-iphonesimulator/Gabinete.app
xcrun simctl status_bar "$DEVICE" override --time 9:41 --batteryState discharging --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 || true

# Biblioteca de muestra: EPUB generados (textos de dominio público) que la app
# importa al primer arranque, como si los hubieras añadido tú.
DATA=$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE" data)
SEED="$DATA/Documents/Semilla"
mkdir -p "$SEED"
mk() { python3 scripts/make-sample-epub.py "$SEED/$1" "${@:2}"; }
mk 1-fundacion.epub --title "Fundación" --author "Isaac Asimov" --series "Fundación" --index 1 --isbn 9788497599245 --year 1951
mk 2-fundacion-imperio.epub --title "Fundación e Imperio" --author "Isaac Asimov" --series "Fundación" --index 2 --isbn 9788497593069 --year 1952
mk 3-segunda-fundacion.epub --title "Segunda Fundación" --author "Isaac Asimov" --series "Fundación" --index 3 --year 1953
mk 4-rayuela.epub --title "Rayuela" --author "Julio Cortázar" --year 1963
mk 5-bestiario.epub --title "BESTIARIO (Spanish Edition)" --author "Cortázar, Julio" --year 1951
mk 6-pedro-paramo.epub --title "Pedro Páramo" --author "Juan Rulfo" --year 1955
mk 7-ficciones.epub --title "Ficciones" --author "Jorge Luis Borges" --year 1944
mk 8-pride.epub --title "Pride and Prejudice" --author "Jane Austen" --language en --year 1813
mk 9-quijote.epub --year 1605
mk 10-ciudad.epub --title "La ciudad y los perros" --author "Gabriel García Márquez" --year 1963
xcrun simctl launch "$DEVICE" "$BUNDLE" -screenshot.seed YES >/dev/null
# Importa y luego busca cada libro en Open Library y Google Books.
sleep 90
echo "  biblioteca de muestra importada"

shoot() { # nombre, espera, argumentos…
  local name=$1 wait=$2; shift 2
  xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$DEVICE" "$BUNDLE" "$@" >/dev/null
  sleep "$wait"
  # Con la Mac ocupada la app tarda en pintar: se repite mientras la captura salga en
  # blanco (una pantalla en blanco pesa menos de 80 KB; cualquiera de la app, más).
  local tries=0
  while :; do
    xcrun simctl io "$DEVICE" screenshot "$OUT/$name.png" >/dev/null 2>&1
    [ "$(stat -f%z "$OUT/$name.png")" -gt 80000 ] || [ $tries -ge 15 ] && break
    tries=$((tries + 1)); sleep 2
  done
  # Y un respiro más para que termine de acomodarse lo que llega después (portadas).
  [ $tries -gt 0 ] && sleep 2 && xcrun simctl io "$DEVICE" screenshot "$OUT/$name.png" >/dev/null 2>&1
  echo "  $name"
}

# Estilo elegido: Editorial. Cada pestaña en claro y oscuro, más la biblioteca
# en lista y la Mesa con el mini reproductor.
for mode in light dark; do
  for tab in reading library notebook search; do
    shoot "editorial-$mode-$tab" 4 -appearance.style editorial -appearance.mode "$mode" -screenshot.tab "$tab"
  done
  shoot "editorial-$mode-library-list" 4 -appearance.style editorial -appearance.mode "$mode" -screenshot.tab library -library.layout Lista -library.sort Título
  shoot "editorial-$mode-detail" 5 -appearance.mode "$mode" -screenshot.tab library -screenshot.screen detail
  shoot "editorial-$mode-review" 5 -appearance.mode "$mode" -screenshot.tab library -screenshot.screen review
  shoot "editorial-$mode-welcome" 4 -appearance.mode "$mode" -screenshot.screen welcome
  shoot "editorial-$mode-diary" 5 -appearance.mode "$mode" -screenshot.tab reading -screenshot.screen diary
  shoot "editorial-$mode-note" 5 -appearance.mode "$mode" -screenshot.tab notebook -screenshot.screen note
  shoot "editorial-$mode-highlights" 4 -appearance.mode "$mode" -screenshot.tab notebook -screenshot.screen highlights
  shoot "editorial-$mode-settings" 4 -appearance.mode "$mode" -screenshot.tab notebook -screenshot.screen settings
done

# Lector: abre el libro más reciente (el Quijote).
for style in editorial; do
  for mode in light dark; do
    shoot "$style-$mode-reader" 8 -appearance.style "$style" -appearance.mode "$mode" -screenshot.openFirst YES
    shoot "$style-$mode-page" 8 -appearance.style "$style" -appearance.mode "$mode" -screenshot.openFirst YES -screenshot.hideChrome YES
    shoot "$style-$mode-contents" 9 -appearance.style "$style" -appearance.mode "$mode" -screenshot.openFirst YES -screenshot.screen contents
    shoot "$style-$mode-marks" 9 -appearance.style "$style" -appearance.mode "$mode" -screenshot.openFirst YES -screenshot.screen marks
    shoot "$style-$mode-appearance" 9 -appearance.style "$style" -appearance.mode "$mode" -screenshot.openFirst YES -screenshot.screen appearance
    shoot "$style-$mode-booksearch" 11 -appearance.style "$style" -appearance.mode "$mode" -screenshot.openFirst YES -screenshot.screen booksearch
  done
done
