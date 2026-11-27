#!/usr/bin/env bash
# Regla del sistema de diseño (docs/sistema-diseno.md): nada en la app usa números,
# colores, fuentes, animaciones ni esperas sueltos; todo sale de Theme y de Components.
# Revisa todo App/Shared menos lo que diga scripts/design-sources.txt (con su porqué),
# con los patrones de scripts/design-patterns.txt: los mismos que DesignRulesTests.
# Uso: scripts/lint-design.sh
set -uo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
import glob, re, sys

def table(path):
    return [line.rstrip("\n").split("\t", 1) for line in open(path, encoding="utf-8")
            if line.strip() and not line.startswith("#")]

excluded = [path for path, _ in table("scripts/design-sources.txt")]
files = [f for f in sorted(glob.glob("App/Shared/**/*.swift", recursive=True))
         if not any(f.startswith(path) for path in excluded)]
found = 0
for message, pattern in table("scripts/design-patterns.txt"):
    regex, hits = re.compile(pattern), []
    for name in files:
        debug = 0  # lo de `#if DEBUG` (capturas y demos) no se ve en la app
        for number, line in enumerate(open(name, encoding="utf-8").read().split("\n"), 1):
            code = line.strip()
            if code.startswith("#if"):
                debug += 1 if debug or code == "#if DEBUG" else 0
                continue
            if code.startswith("#endif") and debug:
                debug -= 1
                continue
            if debug or code.startswith("//") or "ds-exception:" in line:
                continue
            if regex.search(line):
                hits.append(f"{name}:{number}: {code[:140]}")
    if hits:
        found += len(hits)
        print(message, *hits, sep="\n")
if found:
    sys.exit(1)
print(f"Sistema de diseño: sin valores sueltos en {len(files)} archivos.")
PY
