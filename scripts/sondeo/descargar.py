#!/usr/bin/env python3
"""Baja respuestas reales de Open Library y Google Books para el corpus de
prueba y mide las portadas. Corre en la CI (que sí tiene red) y deja todo en
una carpeta que se publica en la rama `sondeo`, para afinar la búsqueda de
metadatos con datos reales y escribir pruebas con respuestas guardadas.

Uso: descargar.py corpus.json carpeta_salida
"""
import hashlib
import io
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from PIL import Image

AGENTE = "Lectora/0.2 (https://github.com/blandisc/biblioteca-lectora)"
OL_CAMPOS = ",".join([
    "key", "title", "subtitle", "author_name", "author_key", "first_publish_year", "edition_count",
    "language", "subject", "cover_i", "cover_edition_key", "publisher", "isbn", "series_name",
    "series_position", "ratings_average",
    "editions", "editions.key", "editions.title", "editions.subtitle", "editions.language",
    "editions.isbn", "editions.publisher", "editions.publish_date", "editions.cover_i",
])
IDIOMA_OL = {"es": "spa", "en": "eng"}


def pedir(url, binario=False):
    """GET con reintentos ante 429/5xx. Devuelve (estado, bytes, segundos)."""
    espera = 2
    for intento in range(3):
        inicio = time.time()
        try:
            req = urllib.request.Request(url, headers={"User-Agent": AGENTE})
            with urllib.request.urlopen(req, timeout=15) as resp:
                datos = resp.read()
                return resp.status, datos, round(time.time() - inicio, 2)
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503) and intento < 2:
                time.sleep(espera)
                espera *= 2
                continue
            return e.code, e.read() if not binario else b"", round(time.time() - inicio, 2)
        except Exception as e:  # red, tiempo de espera
            if intento < 2:
                time.sleep(espera)
                espera *= 2
                continue
            return 0, str(e).encode(), round(time.time() - inicio, 2)
        finally:
            time.sleep(0.2)


def medir_portada(url):
    estado, datos, segundos = pedir(url, binario=True)
    info = {"url": url, "estado": estado, "bytes": len(datos), "segundos": segundos}
    if estado == 200 and datos:
        info["sha1"] = hashlib.sha1(datos).hexdigest()[:12]
        try:
            img = Image.open(io.BytesIO(datos))
            info["ancho"], info["alto"] = img.size
            info["formato"] = img.format
        except Exception as e:
            info["error"] = str(e)
    return info


def guardar(carpeta, nombre, estado, datos, segundos, url, indice):
    ruta = os.path.join(carpeta, nombre + ".json")
    try:
        contenido = json.loads(datos)
    except Exception:
        contenido = {"_texto": datos.decode("utf-8", "replace")[:2000]}
    with open(ruta, "w") as f:
        json.dump(contenido, f, ensure_ascii=False, indent=1)
    indice.append({"nombre": nombre, "url": url, "estado": estado, "segundos": segundos})
    return contenido


def main():
    corpus = json.load(open(sys.argv[1]))
    salida = sys.argv[2]
    os.makedirs(salida, exist_ok=True)
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=4) as grupo:
        resumen = list(grupo.map(lambda caso: procesar(caso, salida), corpus))
    with open(os.path.join(salida, "resumen.json"), "w") as f:
        json.dump(resumen, f, ensure_ascii=False, indent=1)


def procesar(caso, salida):
    inicio_caso = time.time()
    carpeta = os.path.join(salida, caso["id"])
    os.makedirs(carpeta, exist_ok=True)
    indice = []
    titulo, autores, idioma, isbn = caso["title"], caso["authors"], caso.get("language"), caso.get("isbn")
    autor = autores[0] if autores else None

    def ol(nombre, params):
        params = dict(params, limit="10", fields=OL_CAMPOS)
        if idioma in IDIOMA_OL:
            params["lang"] = idioma
        url = "https://openlibrary.org/search.json?" + urllib.parse.urlencode(params)
        return guardar(carpeta, nombre, *pedir(url), url, indice)

    def gb(nombre, q, lang=None):
        params = {"q": q, "maxResults": "10", "printType": "books"}
        if lang:
            params["langRestrict"] = lang
        url = "https://www.googleapis.com/books/v1/volumes?" + urllib.parse.urlencode(params)
        return guardar(carpeta, nombre, *pedir(url), url, indice)

    ol_titulo = ol("ol-titulo", {"title": titulo, **({"author": autor} if autor else {})})
    ol_q = ol("ol-q", {"q": " ".join([titulo] + autores)})
    gb_q_titulo = f'intitle:"{titulo}"' + (f' inauthor:"{autor}"' if autor else "")
    gb_titulo_idioma = gb("gb-titulo-idioma", gb_q_titulo, idioma) if idioma else None
    gb_titulo = gb("gb-titulo", gb_q_titulo)
    gb_q = gb("gb-q", " ".join([titulo] + autores))
    if isbn:
        gb("gb-isbn", f"isbn:{isbn}")
        url = f"https://openlibrary.org/isbn/{isbn}.json"
        guardar(carpeta, "ol-isbn", *pedir(url), url, indice)

    docs = (ol_titulo.get("docs") or []) + (ol_q.get("docs") or [])
    if docs and docs[0].get("key"):
        url = f"https://openlibrary.org{docs[0]['key']}.json"
        guardar(carpeta, "ol-obra", *pedir(url), url, indice)

    portadas = []
    vistas = set()
    for doc in docs[:2]:
        ids = [doc.get("cover_i")] + [e.get("cover_i") for e in (doc.get("editions") or {}).get("docs", [])]
        for cid in ids:
            if cid and cid not in vistas:
                vistas.add(cid)
                portadas.append(dict(medir_portada(f"https://covers.openlibrary.org/b/id/{cid}-L.jpg?default=false"),
                                     fuente="ol", obra=doc.get("key")))
    items = []
    for r in (gb_titulo_idioma, gb_titulo, gb_q):
        items += (r or {}).get("items") or []
    for item in items[:3]:
        gid = item.get("id")
        if not gid or gid in vistas:
            continue
        vistas.add(gid)
        links = item.get("volumeInfo", {}).get("imageLinks") or {}
        thumb = links.get("thumbnail")
        variantes = {"sin-imagen": not thumb}
        if thumb:
            seguro = thumb.replace("http://", "https://")
            variantes["miniatura"] = medir_portada(seguro)
            variantes["zoom0"] = medir_portada(seguro.replace("&edge=curl", "").replace("zoom=1", "zoom=0"))
            variantes["zoom1"] = medir_portada(seguro.replace("&edge=curl", ""))
        variantes["fife"] = medir_portada(
            f"https://books.google.com/books/publisher/content/images/frontcover/{gid}?fife=w800-h1200&source=gbs_api")
        portadas.append({"fuente": "gb", "id": gid, "variantes": variantes})
    with open(os.path.join(carpeta, "portadas.json"), "w") as f:
        json.dump(portadas, f, ensure_ascii=False, indent=1)
    with open(os.path.join(carpeta, "indice.json"), "w") as f:
        json.dump(indice, f, ensure_ascii=False, indent=1)
    print(caso["id"], round(time.time() - inicio_caso), "s", [(i["nombre"], i["estado"], i["segundos"]) for i in indice], flush=True)
    return {"id": caso["id"], "peticiones": indice}


if __name__ == "__main__":
    main()
