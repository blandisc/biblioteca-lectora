#!/usr/bin/env bash
# Descarga foliate-js (MIT) fijado a un commit y copia solo los módulos que usa
# el lector a App/Resources/Reader/foliate/. Se excluye el adaptador de PDF
# (PDF.js, ~13 MB): en Apple los PDF se leen con PDFKit.
set -euo pipefail

FOLIATE_REPO="https://github.com/johnfactotum/foliate-js"
FOLIATE_COMMIT="78914aef4466eb960965702401634c2cb348e9b1"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/App/Resources/Reader/foliate"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git -C "$WORK" init -q
git -C "$WORK" remote add origin "$FOLIATE_REPO"
git -C "$WORK" fetch -q --depth 1 origin "$FOLIATE_COMMIT"
git -C "$WORK" checkout -q FETCH_HEAD

rm -rf "$DEST"
mkdir -p "$DEST/vendor"
for file in view.js epub.js epubcfi.js paginator.js fixed-layout.js progress.js \
            overlayer.js text-walker.js footnotes.js search.js tts.js \
            comic-book.js fb2.js mobi.js LICENSE; do
  cp "$WORK/$file" "$DEST/$file"
done
cp "$WORK/vendor/zip.js" "$WORK/vendor/fflate.js" "$DEST/vendor/"
echo "$FOLIATE_COMMIT" > "$DEST/COMMIT"
echo "foliate-js $FOLIATE_COMMIT copiado en $DEST"
