#!/usr/bin/env python3
"""La hoja de contactos del estudio del Duo: cada pantalla en el iPhone normal y en los cuatro modos.

Uso (lo llama scripts/duo-estudio.sh): hoja.py <carpeta de la ronda> <pantallas> <oscuras> <AX5>

- Si existe la ronda anterior, cada captura se puede ver contra la de antes: «Esta ronda»,
  «Ronda anterior» o «Las dos» (una sobre otra), con un botón arriba.
- Las otras opciones de cada decisión (`alternativas/<código>/<modo>/<pantalla>.png`, con su
  `LEEME.txt`: primer renglón el título, lo demás qué cambia) van al final, junto a la recomendada.
- Si en la ronda hay `critica-A.md`, `critica-B.md` o `cambios.md`, se enlazan arriba.
"""
import glob
import html
import os
import re
import sys

out, screens, dark, big = sys.argv[1], sys.argv[2], sys.argv[3].split(), sys.argv[4].split()
round_name = os.path.basename(out.rstrip("/"))
match = re.match(r"ronda-(\d+)$", round_name)
previous = None
if match and int(match.group(1)) > 0:
    candidate = os.path.join(os.path.dirname(out.rstrip("/")), f"ronda-{int(match.group(1)) - 1}")
    if os.path.isdir(candidate):
        previous = candidate

modes = [("iphone-vertical", "iPhone normal · de pie", "402 × 874"),
         ("iphone-horizontal", "iPhone normal · acostado", "874 × 402"),
         ("cerrado-vertical", "Cerrado · de pie", "466 × 678"),
         ("cerrado-horizontal", "Cerrado · acostado", "678 × 466"),
         ("abierto-vertical", "Abierto · de pie", "669 × 951"),
         ("abierto-horizontal", "Abierto · acostado", "951 × 669")]
labels = {m: label for m, label, _ in modes}

rows = []
for line in screens.strip().splitlines():
    name, title = line.split("|")[:2]
    rows.append((name, title))
    if name in dark:
        rows.append((name + "-oscuro", title + " · oscuro"))
    if name in big:
        rows.append((name + "-ax5", title + " · letra AX5"))
titles = dict(rows)


def image(folder, mode, name, rel):
    """La miniatura (o la captura) de una pantalla, relativa a la hoja; None si no hay."""
    for path in (f"mini/{mode}/{name}.jpg", f"{mode}/{name}.png"):
        if os.path.exists(os.path.join(folder, path)):
            return rel + path
    return None


rel_previous = os.path.relpath(previous, out) + "/" if previous else ""
counts = {m: sum(os.path.exists(f"{out}/{m}/{n}.png") for n, _ in rows) for m, _, _ in modes}
links = [f'<a href="{name}">{label}</a>' for name, label in
         (("critica-A.md", "Crítica A"), ("critica-B.md", "Crítica B"), ("cambios.md", "Qué cambió"))
         if os.path.exists(os.path.join(out, name))]

parts = [f"""<!doctype html><html lang="es"><meta charset="utf-8">
<title>Gabinete en el iPhone Duo · {round_name}</title>
<style>
body{{font:15px -apple-system,system-ui,sans-serif;margin:24px;background:#f4f1ea;color:#222}}
h1{{font-size:22px;margin:0 0 4px}}p.nota{{color:#555;max-width:70em;margin:0 0 12px}}
nav{{columns:4;font-size:13px;margin:0 0 24px}}nav a{{display:block;color:#355}}
.barra{{position:sticky;top:0;background:#f4f1ea;padding:8px 0;z-index:2;display:flex;gap:8px;align-items:center;flex-wrap:wrap}}
.barra button{{font:inherit;padding:4px 12px;border-radius:14px;border:1px solid #bbb;background:#fff;cursor:pointer}}
.barra button.on{{background:#0f4a35;color:#fff;border-color:#0f4a35}}
.barra .links a{{margin-left:12px;color:#0f4a35}}
section{{margin:0 0 36px;border-top:1px solid #d8d2c4;padding-top:12px}}
h2{{font-size:17px;margin:0 0 10px}}h3{{font-size:15px;margin:16px 0 6px}}
.fila{{display:grid;grid-template-columns:.7fr 1.2fr .8fr 1.1fr 1.1fr 1.5fr;gap:14px;align-items:start}}
.alt{{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:14px;align-items:start}}
figure{{margin:0}}figcaption{{font-size:12px;color:#666;margin-bottom:4px}}
img{{width:100%;height:auto;border-radius:10px;box-shadow:0 1px 4px #0002;background:#000}}
.antes{{display:none;outline:3px solid #c9a227}}
body.ver-antes .ahora{{display:none}}body.ver-antes .antes{{display:block}}
body.ver-dos .antes{{display:block;margin-top:6px}}
.etq{{display:none;font-size:11px;color:#8a6d10}}body.ver-dos .etq,body.ver-antes .etq{{display:block}}
.falta{{font-size:12px;color:#a33;padding:24px 8px;border:1px dashed #c99;border-radius:10px;text-align:center}}
</style>
<h1>Gabinete en el iPhone Duo · {round_name}</h1>
<p class="nota">Cada pantalla en un iPhone normal (para comparar) y en los cuatro modos del Duo, lado a lado.
Simulador «Gabinete Duo» (iPhone Duo, iOS 27.2) con la bisagra y la orientación de verdad: cerrado es la pantalla
de afuera; abierto, la de adentro, con el pliegue al centro (de arriba abajo acostada, de lado a lado de pie). Los
datos son los mismos en todas las capturas y rondas. Toca una captura para verla completa.<br>
Capturas por modo: {" · ".join(f"{label} {counts[m]}" for m, label, _ in modes)}.</p>
<div class="barra">"""]
if previous:
    parts.append(f"""<button class="on" data-ver="">Esta ronda</button>
<button data-ver="ver-antes">{html.escape(os.path.basename(previous))}</button>
<button data-ver="ver-dos">Las dos</button>""")
parts.append(f'<span class="links">{"".join(links)}<a href="#alternativas">Alternativas</a></span></div><nav>')
for name, title in rows:
    parts.append(f'<a href="#{name}">{html.escape(title)}</a>')
parts.append("</nav>")

for name, title in rows:
    parts.append(f'<section id="{name}"><h2>{html.escape(title)}</h2><div class="fila">')
    for m, label, size in modes:
        now = image(out, m, name, "")
        before = image(previous, m, name, rel_previous) if previous else None
        cap = f"<figcaption>{label} · {size}</figcaption>"
        if now or before:
            body = [cap]
            if now:
                body.append(f'<a class="ahora" href="{m}/{name}.png"><img loading="lazy" src="{now}" alt="{html.escape(title)}, {label}"></a>')
            else:
                body.append('<div class="falta ahora">sin captura</div>')
            if before:
                body.append(f'<div class="etq">ronda anterior</div><a class="antes" href="{before.replace("mini/", "").replace(".jpg", ".png")}">'
                            f'<img loading="lazy" src="{before}" alt="{html.escape(title)}, {label}, ronda anterior"></a>')
            parts.append(f"<figure>{''.join(body)}</figure>")
        else:
            parts.append(f'<figure>{cap}<div class="falta">sin captura</div></figure>')
    parts.append("</div></section>")

# Las alternativas de cada decisión.
parts.append('<section id="alternativas"><h2>Alternativas (detrás de opciones de Debug)</h2>')
codes = sorted(d for d in glob.glob(f"{out}/alternativas/*") if os.path.isdir(d))
if not codes:
    parts.append('<p class="nota">Sin alternativas en esta ronda.</p>')
for folder in codes:
    code = os.path.basename(folder)
    readme = os.path.join(folder, "LEEME.txt")
    lines = open(readme).read().strip().splitlines() if os.path.exists(readme) else [code]
    parts.append(f'<h3 id="alt-{html.escape(code)}">{html.escape(code)} · {html.escape(lines[0])}</h3>')
    if len(lines) > 1:
        parts.append(f'<p class="nota">{html.escape(" ".join(lines[1:]))}</p>')
    parts.append('<div class="alt">')
    for path in sorted(glob.glob(f"{folder}/*/*.png")):
        mode = os.path.basename(os.path.dirname(path))
        shot = os.path.splitext(os.path.basename(path))[0]
        rel = os.path.relpath(path, out)
        mini = os.path.join(folder, "mini", mode, shot + ".jpg")
        src = os.path.relpath(mini, out) if os.path.exists(mini) else rel
        chosen = image(out, mode, shot, "")
        cap = f"{labels.get(mode, mode)} · {html.escape(titles.get(shot, shot))}"
        parts.append(f'<figure><figcaption>{cap} · esta opción</figcaption><a href="{rel}"><img loading="lazy" src="{src}"></a>')
        if chosen:
            parts.append(f'<figcaption>la recomendada</figcaption><a href="{mode}/{shot}.png"><img loading="lazy" src="{chosen}"></a>')
        parts.append("</figure>")
    parts.append("</div>")
parts.append("</section>")
parts.append("""<script>
document.querySelectorAll('.barra button').forEach(b => b.onclick = () => {
  document.body.className = b.dataset.ver;
  document.querySelectorAll('.barra button').forEach(o => o.classList.toggle('on', o === b));
});
</script>""")
open(f"{out}/index.html", "w").write("\n".join(parts))
print(f"Hoja: {out}/index.html")
