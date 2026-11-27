#!/usr/bin/env bash
# Estudio del iPhone Duo: cada pantalla de Gabinete en los cuatro modos del Duo, con la bisagra de
# verdad (scripts/duo/duopose.m la mueve en el simulador, sin Device Hub).
#
# Uso:  scripts/duo-estudio.sh <modo>… [--ronda N]
#   modos: cerrado-vertical  cerrado-horizontal  abierto-vertical  abierto-horizontal  (o «todos»)
#          iphone-vertical  iphone-horizontal  (un iPhone normal, para comparar; «comparar» = los dos)
#   scripts/duo-estudio.sh hoja [--ronda N]   solo rehace la hoja de contactos (index.html)
#
# Salida: /tmp/gabinete-duo-estudio/ronda-N/<modo>/<pantalla>.png y ronda-N/index.html (las cuatro
# columnas lado a lado, por pantalla). Variables: DEVICE (por omisión «Gabinete Duo»),
# IPHONE (el simulador «Gabinete», iPhone 17 Pro), DERIVED (/tmp/dd-gabinete-duo), BUILD=1 recompila, RESEED=1 vuelve a instalar y sembrar la biblioteca,
# ONLY="mesa ficha" toma solo esas pantallas, SHEET_ONLY=1.
#
# Cada modo:
#   cerrado-vertical    pantalla de afuera (466 × 678), de pie
#   cerrado-horizontal  pantalla de afuera acostada (678 × 466)
#   abierto-horizontal  pantalla de adentro como queda al abrirlo (951 × 669, el pliegue de arriba abajo)
#   abierto-vertical    pantalla de adentro girada (669 × 951)
# Todo con la orientación de verdad del aparato (la pone duopose al mover la bisagra); el iPhone normal
# se gira con `-screenshot.turn`, porque simctl no gira el aparato.
#   iphone-vertical     iPhone 17 Pro de pie (402 × 874); iphone-horizontal, acostado
# Un simulador a la vez: al pasar del Duo al iPhone (o al revés) apago el anterior.
set -euo pipefail
cd "$(dirname "$0")/.."

DUO=${DEVICE:-DC313F4E-7347-43E4-A6FE-EEFFC77925C0}
IPHONE=${IPHONE:-AA51EDFA-EE03-4EF3-AA2F-B79EBFD49523}
DEVICE=
DERIVED=${DERIVED:-/tmp/dd-gabinete-duo}
BUNDLE=mx.iracheta.gabinete
ROOT=/tmp/gabinete-duo-estudio
ROUND=0
MODES=()
while [ $# -gt 0 ]; do
  case $1 in
    --ronda) ROUND=$2; shift 2 ;;
    todos) MODES+=(cerrado-vertical cerrado-horizontal abierto-vertical abierto-horizontal); shift ;;
    comparar) MODES+=(iphone-vertical iphone-horizontal); shift ;;
    hoja) SHEET_ONLY=1; shift ;;
    *) MODES+=("$1"); shift ;;
  esac
done
OUT="$ROOT/ronda-$ROUND"
mkdir -p "$OUT"

# Las pantallas, en el orden de la hoja: nombre|título en español|espera|argumentos.
# El lector necesita más espera: pinta el libro y luego corre su demostración (6 s).
SCREENS=$(cat <<'EOF'
bienvenida-1-hola|Bienvenida · hola|5|-screenshot.screen welcome
bienvenida-2-lugar|Bienvenida · dónde vive tu Gabinete|5|-screenshot.screen welcome -screenshot.step place
bienvenida-3-libros|Bienvenida · tus libros|5|-screenshot.screen welcome -screenshot.step books
bienvenida-4-readwise|Bienvenida · Readwise|5|-screenshot.screen welcome -screenshot.step readwise
mesa|Mesa|6|-screenshot.tab reading
biblioteca-portadas|Biblioteca · portadas (con «Por revisar»)|6|-screenshot.tab library
biblioteca-lista|Biblioteca · lista A–Z|6|-screenshot.tab library -library.layout Lista -library.sort Título
biblioteca-autor|Biblioteca · lista por autor|6|-screenshot.tab library -library.layout Lista -library.sort Autor
biblioteca-leyendo|Biblioteca · filtro Leyendo|6|-screenshot.tab library -screenshot.filter Leyendo
biblioteca-series|Biblioteca · filtro Series|6|-screenshot.tab library -screenshot.filter Series
biblioteca-duplicados|Biblioteca · posibles duplicados|6|-screenshot.tab library -screenshot.filter Posibles%20duplicados
ficha|Ficha del libro|7|-screenshot.tab library -screenshot.screen detail -screenshot.book Fundación
ficha-larga|Ficha · título larguísimo|7|-screenshot.tab library -screenshot.screen detail -screenshot.book Memorias
editar-datos|Editar datos (escribir a mano)|7|-screenshot.tab library -screenshot.screen edit -screenshot.book Fundación
buscar-otros-datos|Buscar con otros datos|12|-screenshot.tab library -screenshot.screen candidates -screenshot.book Rayuela
portada-internet|Elegir portada de internet|12|-screenshot.tab library -screenshot.screen cover -screenshot.book Rayuela
por-revisar|Por revisar|7|-screenshot.tab library -screenshot.screen review
por-revisar-elegir|Por revisar · elegir varios|8|-screenshot.tab library -screenshot.screen review -screenshot.demo reviewChoose
serie|Serie|7|-screenshot.tab library -screenshot.screen series
estante|Estante guardado|7|-screenshot.tab library -screenshot.screen shelf
cuaderno-notas|Cuaderno · notas|6|-screenshot.tab notebook
cuaderno-subrayados|Cuaderno · subrayados|6|-screenshot.tab notebook -screenshot.screen highlights
nota|Nota · lectura|7|-screenshot.tab notebook -screenshot.screen note
nota-edicion|Nota · edición|7|-screenshot.tab notebook -screenshot.screen noteEdit
diario-semana|Diario · semana|7|-screenshot.tab reading -screenshot.screen diary
diario-mes|Diario · mes|7|-screenshot.tab reading -screenshot.screen diary -screenshot.part Mes
buscar-vacio|Buscar · vacío|6|-screenshot.tab search
buscar-resultados|Buscar · con resultados|7|-screenshot.tab search -screenshot.query Cortázar
lector-paginas|Lector · páginas, con controles|10|-screenshot.openFirst YES
lector-pagina-limpia|Lector · página sin controles|10|-screenshot.openFirst YES -screenshot.hideChrome YES
lector-continuo|Lector · continuo|10|-screenshot.openFirst YES -screenshot.hideChrome YES -reader.flow scrolled
lector-hendidura|Lector · Hendidura|14|-screenshot.openFirst YES -screenshot.demo slit
lector-guia|Lector · guía de renglón|16|-screenshot.openFirst YES -screenshot.hideChrome YES -screenshot.demo guide
lector-aa|Lector · herramientas Aa|11|-screenshot.openFirst YES -screenshot.screen appearance
lector-indice|Lector · índice|11|-screenshot.openFirst YES -screenshot.screen contents
lector-buscar|Lector · buscar en el libro|13|-screenshot.openFirst YES -screenshot.screen booksearch
lector-marcas|Lector · marcas|11|-screenshot.openFirst YES -screenshot.screen marks
lector-seleccion|Lector · barra de selección|14|-screenshot.openFirst YES -screenshot.demo selection
resumen-sesion|Resumen de la sesión|7|-screenshot.screen summary
ajustes|Ajustes · arriba (apariencia y lectura)|7|-screenshot.tab notebook -screenshot.screen settings
ajustes-gabinete|Ajustes · tu Gabinete|8|-screenshot.tab notebook -screenshot.screen settings -screenshot.demo settingsCabinet
ajustes-datos|Ajustes · datos de los libros|8|-screenshot.tab notebook -screenshot.screen settings -screenshot.demo settingsMiddle
ajustes-final|Ajustes · conexiones y colofón|8|-screenshot.tab notebook -screenshot.screen settings -screenshot.demo settingsEnd
ajustes-reglas|Ajustes · Reglas|8|-screenshot.tab notebook -screenshot.screen settings -screenshot.demo settingsRules
ajustes-conexion|Ajustes · una conexión (Readwise)|8|-screenshot.tab notebook -screenshot.screen settings -screenshot.demo settingsConnection
ajustes-calibre|Ajustes · traer de Calibre|8|-screenshot.tab notebook -screenshot.screen settings -screenshot.demo settingsCalibre
icloud-bajando|iCloud · bajando tu biblioteca|7|-screenshot.tab library -screenshot.cloud downloading
icloud-no-bajo|iCloud · ya no la espero|7|-screenshot.tab library -screenshot.cloud gaveUp
EOF
)
# Variantes: oscuro y letra más grande (AX5) de unas cuantas.
DARK="mesa biblioteca-portadas ficha lector-paginas cuaderno-notas ajustes"
BIG="mesa biblioteca-lista ficha lector-paginas buscar-resultados ajustes"

title_of() { # nombre de archivo → título
  local base=${1%-oscuro}; base=${base%-ax5}
  local title; title=$(printf '%s\n' "$SCREENS" | awk -F'|' -v n="$base" '$1==n {print $2}')
  case $1 in *-oscuro) title="$title · oscuro" ;; *-ax5) title="$title · letra AX5" ;; esac
  printf '%s' "$title"
}

sheet() {
  python3 - "$OUT" "$SCREENS" "$DARK" "$BIG" <<'PY'
import html, os, sys
out, screens, dark, big = sys.argv[1], sys.argv[2], sys.argv[3].split(), sys.argv[4].split()
modes = [("iphone-vertical", "iPhone normal · de pie", "402 × 874"),
         ("iphone-horizontal", "iPhone normal · acostado", "874 × 402"),
         ("cerrado-vertical", "Cerrado · de pie", "466 × 678"),
         ("cerrado-horizontal", "Cerrado · acostado", "678 × 466"),
         ("abierto-vertical", "Abierto · de pie", "669 × 951"),
         ("abierto-horizontal", "Abierto · acostado", "951 × 669")]
rows = []
for line in screens.strip().splitlines():
    name, title = line.split("|")[:2]
    rows.append((name, title))
    if name in dark: rows.append((name + "-oscuro", title + " · oscuro"))
    if name in big: rows.append((name + "-ax5", title + " · letra AX5"))
counts = {m: sum(os.path.exists(f"{out}/{m}/{n}.png") for n, _ in rows) for m, _, _ in modes}
parts = ["""<!doctype html><html lang="es"><meta charset="utf-8"><title>Gabinete en el iPhone Duo · ronda %s</title>
<style>
body{font:15px -apple-system,system-ui,sans-serif;margin:24px;background:#f4f1ea;color:#222}
h1{font-size:22px;margin:0 0 4px}p.nota{color:#555;max-width:70em;margin:0 0 16px}
nav{columns:4;font-size:13px;margin:0 0 24px}nav a{display:block;color:#355}
section{margin:0 0 36px;border-top:1px solid #d8d2c4;padding-top:12px}
h2{font-size:17px;margin:0 0 10px}
.fila{display:grid;grid-template-columns:.7fr 1.2fr .8fr 1.1fr 1.1fr 1.5fr;gap:14px;align-items:start}
figure{margin:0}figcaption{font-size:12px;color:#666;margin-bottom:4px}
img{width:100%%;height:auto;border-radius:10px;box-shadow:0 1px 4px #0002;background:#000}
.falta{font-size:12px;color:#a33;padding:24px 8px;border:1px dashed #c99;border-radius:10px;text-align:center}
</style>
<h1>Gabinete en el iPhone Duo · ronda %s</h1>
<p class="nota">Cada pantalla en un iPhone normal (para comparar) y en los cuatro modos del Duo, lado a lado. Simulador «Gabinete Duo» (iPhone Duo, iOS 27.2) con la
bisagra y la orientación de verdad (nada aproximado): cerrado es la pantalla de afuera; abierto, la de adentro, con el
pliegue al centro (de arriba abajo acostada, de lado a lado de pie). El iPhone normal (17 Pro, «Gabinete») se gira con
la app (<code>-screenshot.turn</code>). Toca una captura para verla completa.<br>
Capturas por modo: %s.</p><nav>""" % (os.path.basename(out), os.path.basename(out),
    " · ".join(f"{label} {counts[m]}" for m, label, _ in modes))]
for name, title in rows:
    parts.append(f'<a href="#{name}">{html.escape(title)}</a>')
parts.append("</nav>")
for name, title in rows:
    parts.append(f'<section id="{name}"><h2>{html.escape(title)}</h2><div class="fila">')
    for m, label, size in modes:
        path = f"{m}/{name}.png"
        thumb = f"mini/{m}/{name}.jpg"
        cap = f"<figcaption>{label} · {size}</figcaption>"
        if os.path.exists(f"{out}/{path}"):
            src = thumb if os.path.exists(f"{out}/{thumb}") else path
            parts.append(f'<figure>{cap}<a href="{path}"><img loading="lazy" src="{src}" alt="{html.escape(title)}, {label}"></a></figure>')
        else:
            parts.append(f'<figure>{cap}<div class="falta">sin captura</div></figure>')

    parts.append("</div></section>")
open(f"{out}/index.html", "w").write("\n".join(parts))
print(f"Hoja: {out}/index.html")
PY
}

if [ -n "${SHEET_ONLY:-}" ]; then sheet; exit 0; fi
[ ${#MODES[@]} -gt 0 ] || { sed -n 2,20p "$0"; exit 1; }

APP="$DERIVED/Build/Products/Debug-iphonesimulator/Gabinete.app"
if [ -n "${BUILD:-}" ] || [ ! -d "$APP" ]; then
  while [ "$(pgrep -x xcodebuild | wc -l)" -ge 2 ]; do sleep 10; done
  xcodebuild -project Lectora.xcodeproj -scheme Lectora_iOS -configuration Debug -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$DERIVED" build CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES -quiet
fi

# La herramienta que mueve la bisagra, compilada para el simulador con su permiso adentro.
POSE="$DERIVED/duopose"
if [ ! -x "$POSE" ] || [ scripts/duo/duopose.m -nt "$POSE" ]; then
  clang -target arm64-apple-ios27.0-simulator -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" -fobjc-arc \
    -framework Foundation scripts/duo/duopose.m -o "$POSE" \
    -Wl,-sectcreate,__TEXT,__entitlements,scripts/duo/duopose.entitlements
  codesign -s - -f "$POSE" 2>/dev/null
fi
# La orientación del aparato se fija al mover la bisagra: primero a la pose contraria y luego a la pedida,
# para que el giro cuente. Abierto, «landscapeLeft» deja la pantalla de adentro de pie (669 × 951) y
# «portrait», acostada (951 × 669): la bisagra manda.
pose() { # closed|open, orientación
  local other=open; [ "$1" = open ] && other=closed
  xcrun simctl spawn "$DEVICE" "$POSE" -position="$other" -deviceOrientation="$2" -duration=0 -wait
  xcrun simctl spawn "$DEVICE" "$POSE" -position="$1" -deviceOrientation="$2" -duration=0 -wait
  sleep 2
}

# Prende el simulador pedido (uno a la vez) y deja la biblioteca de muestra sembrada.
use_device() {
  local wanted=$1 other
  [ "$DEVICE" = "$wanted" ] && return
  [ "$wanted" = "$DUO" ] && other=$IPHONE || other=$DUO
  if [ -n "$DEVICE" ]; then xcrun simctl shutdown "$DEVICE" 2>/dev/null || true; fi
  # Si el otro simulador de Gabinete está prendido (otra sesión), espero.
  while xcrun simctl list devices booted | grep -q "$other"; do
    echo "El simulador $other está prendido (otra sesión); espero un minuto…"; sleep 60
  done
  DEVICE=$wanted
  xcrun simctl boot "$DEVICE" 2>/dev/null || true
  xcrun simctl bootstatus "$DEVICE" -b >/dev/null
  xcrun simctl ui "$DEVICE" content_size large
  xcrun simctl status_bar "$DEVICE" override --time 9:41 --batteryState discharging --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
  seed
}

# Biblioteca de muestra (una vez por simulador; RESEED=1 la rehace): más de 15 libros para el índice
# A–Z, una serie, un título larguísimo, uno con emoji, uno en árabe, un duplicado y uno sin datos.
seed() {
  local DATA
  DATA=$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE" data 2>/dev/null || true)
  if [ -z "${RESEED:-}" ] && [ -n "$DATA" ] && [ -f "$DATA/Documents/.duo-estudio" ]; then
    xcrun simctl install "$DEVICE" "$APP"; return
  fi
  echo "Instalo y siembro la biblioteca de muestra…"
  xcrun simctl uninstall "$DEVICE" "$BUNDLE" 2>/dev/null || true
  xcrun simctl install "$DEVICE" "$APP"
  DATA=$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE" data)
  SEED="$DATA/Documents/Semilla"; mkdir -p "$SEED"
  mk() { python3 scripts/make-sample-epub.py "$SEED/$1" "${@:2}"; }
  mk 01-fundacion.epub --title "Fundación" --author "Isaac Asimov" --series "Fundación" --index 1 --isbn 9788497599245 --year 1951
  mk 02-fundacion-imperio.epub --title "Fundación e Imperio" --author "Isaac Asimov" --series "Fundación" --index 2 --isbn 9788497593069 --year 1952
  mk 03-segunda-fundacion.epub --title "Segunda Fundación" --author "Isaac Asimov" --series "Fundación" --index 3 --year 1953
  mk 04-rayuela.epub --title "Rayuela" --author "Julio Cortázar" --year 1963
  mk 05-rayuela-otra.epub --title "Rayuela" --author "Julio Cortázar" --year 1963
  mk 06-bestiario.epub --title "BESTIARIO (Spanish Edition)" --author "Cortázar, Julio" --year 1951
  mk 07-pedro-paramo.epub --title "Pedro Páramo" --author "Juan Rulfo" --year 1955
  mk 08-ficciones.epub --title "Ficciones" --author "Jorge Luis Borges" --year 1944
  mk 09-pride.epub --title "Pride and Prejudice" --author "Jane Austen" --language en --year 1813
  mk 10-ciudad.epub --title "La ciudad y los perros" --author "Mario Vargas Llosa" --year 1963
  mk 11-larguisimo.epub --title "Memorias de un hombre que leía demasiado en las noches largas de invierno y otras historias de la biblioteca de su abuela" --author "Rodrigo Hernández de la Fuente y Sotomayor" --year 2019
  mk 12-emoji.epub --title "Café ☕️ y libros 📚 para días lentos" --author "Lucía Mar" --year 2021
  mk 13-arabe.epub --title "ألف ليلة وليلة" --author "مجهول" --language ar --year 1704
  mk 14-cien.epub --title "Cien años de soledad" --author "Gabriel García Márquez" --year 1967
  mk 15-aleph.epub --title "El Aleph" --author "Jorge Luis Borges" --year 1949
  mk 16-tunel.epub --title "El túnel" --author "Ernesto Sabato" --year 1948
  mk 17-casa.epub --title "La casa de los espíritus" --author "Isabel Allende" --year 1982
  mk 18-quijote.epub --year 1605
  xcrun simctl launch "$DEVICE" "$BUNDLE" -screenshot.seed YES >/dev/null
  # Importa y busca cada libro en Open Library y Google Books.
  sleep 100
  xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
  touch "$DATA/Documents/.duo-estudio"
}

shoot() { # carpeta, nombre, pantalla (primary/primary-1), espera, argumentos…
  local dir=$1 name=$2 display=$3 wait=$4; shift 4
  if [ -n "${ONLY:-}" ] && ! [[ " $ONLY " == *" ${name%-oscuro} "* || " $ONLY " == *" ${name%-ax5} "* ]]; then return; fi
  xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$DEVICE" "$BUNDLE" "$@" >/dev/null
  sleep "$wait"
  # Con la Mac ocupada la app tarda en pintar: se repite mientras la captura salga casi vacía.
  local tries=0 file="$dir/$name.png"
  while :; do
    xcrun simctl io "$DEVICE" screenshot ${display:+--display="$display"} "$file" >/dev/null 2>&1 || true
    [ "$(stat -f%z "$file" 2>/dev/null || echo 0)" -gt 60000 ] || [ $tries -ge 10 ] && break
    tries=$((tries + 1)); sleep 2
  done
  mkdir -p "$OUT/mini/$(basename "$dir")"
  sips -Z 700 -s format jpeg "$file" --out "$OUT/mini/$(basename "$dir")/$name.jpg" >/dev/null 2>&1 || true
  echo "  $(basename "$dir")/$name"
}

for mode in "${MODES[@]}"; do
  case $mode in
    iphone-vertical) device=$IPHONE; position=; display=; turn=(-screenshot.turn portrait) ;;
    iphone-horizontal) device=$IPHONE; position=; display=; turn=(-screenshot.turn landscape -screenshot.turnAfter 3) ;;
    cerrado-vertical) device=$DUO; position=closed; orientation=portrait; display=primary; turn=() ;;
    cerrado-horizontal) device=$DUO; position=closed; orientation=landscapeLeft; display=primary; turn=() ;;
    abierto-vertical) device=$DUO; position=open; orientation=landscapeLeft; display=primary-1; turn=() ;;
    abierto-horizontal) device=$DUO; position=open; orientation=portrait; display=primary-1; turn=() ;;
    *) echo "Modo desconocido: $mode"; exit 1 ;;
  esac
  echo "== $mode"
  use_device "$device"
  xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
  [ -z "$position" ] || pose "$position" "$orientation"
  dir="$OUT/$mode"; mkdir -p "$dir"
  while IFS='|' read -r name title wait args; do
    [ -n "$name" ] || continue
    # shellcheck disable=SC2086
    set -- ${args//%20/@@}
    local_args=(); for a in "$@"; do local_args+=("${a//@@/ }"); done
    shoot "$dir" "$name" "$display" "$wait" -appearance.mode light ${turn[@]+"${turn[@]}"} ${local_args[@]+"${local_args[@]}"}
    if [[ " $DARK " == *" $name "* ]]; then
      shoot "$dir" "$name-oscuro" "$display" "$wait" -appearance.mode dark ${turn[@]+"${turn[@]}"} ${local_args[@]+"${local_args[@]}"}
    fi
  done <<< "$SCREENS"
  # Letra más grande (AX5) para unas cuantas.
  xcrun simctl ui "$DEVICE" content_size accessibility-extra-extra-extra-large
  while IFS='|' read -r name title wait args; do
    [[ " $BIG " == *" $name "* ]] || continue
    set -- ${args//%20/@@}
    local_args=(); for a in "$@"; do local_args+=("${a//@@/ }"); done
    shoot "$dir" "$name-ax5" "$display" "$wait" -appearance.mode light ${turn[@]+"${turn[@]}"} ${local_args[@]+"${local_args[@]}"}
  done <<< "$SCREENS"
  xcrun simctl ui "$DEVICE" content_size large
  xcrun simctl terminate "$DEVICE" "$BUNDLE" 2>/dev/null || true
done

# Al terminar: la app fuera, la letra normal y el simulador apagado (KEEP=1 lo deja como está).
if [ -n "$DEVICE" ] && [ -z "${KEEP:-}" ]; then
  xcrun simctl ui "$DEVICE" content_size large
  xcrun simctl shutdown "$DEVICE" 2>/dev/null || true
fi
sheet
