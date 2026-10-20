#!/usr/bin/env python3
"""Crea un EPUB de muestra (texto de dominio público) para las capturas."""
import sys
import zipfile

CHAPTERS = [
    ("Capítulo primero", [
        "En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda.",
        "El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera.",
        "Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque por conjeturas verosímiles se deja entender que se llamaba Quejana.",
        "Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad.",
    ]),
]

# Más capítulos con el mismo texto, para que el libro tenga un largo realista
# y el porcentaje de avance se vea como en un libro de verdad.
ORDINALS = ["segundo", "tercero", "cuarto", "quinto", "sexto", "séptimo", "octavo", "noveno", "décimo"]
CHAPTERS += [(f"Capítulo {o}", CHAPTERS[0][1] * 3) for o in ORDINALS]
CHAPTERS[0] = (CHAPTERS[0][0], CHAPTERS[0][1] * 3)


def xhtml(title, paragraphs):
    body = "\n".join(f"<p>{p}</p>" for p in paragraphs)
    return f"""<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="es" lang="es">
<head><title>{title}</title></head>
<body><h2>{title}</h2>
{body}
</body></html>"""

def main(out, title="Don Quijote de la Mancha", author="Miguel de Cervantes",
         language="es", series=None, index=None, isbn=None, year=None):
    with zipfile.ZipFile(out, "w") as z:
        z.writestr("mimetype", "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        z.writestr("META-INF/container.xml", """<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
<rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>""", compress_type=zipfile.ZIP_DEFLATED)
        items, spine, nav = [], [], []
        for i, (chapter, paragraphs) in enumerate(CHAPTERS, 1):
            z.writestr(f"OEBPS/c{i}.xhtml", xhtml(chapter, paragraphs), compress_type=zipfile.ZIP_DEFLATED)
            items.append(f'<item id="c{i}" href="c{i}.xhtml" media-type="application/xhtml+xml"/>')
            spine.append(f'<itemref idref="c{i}"/>')
            nav.append(f'<li><a href="c{i}.xhtml">{chapter}</a></li>')
        z.writestr("OEBPS/nav.xhtml", f"""<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="es">
<head><title>Índice</title></head>
<body><nav epub:type="toc"><ol>{''.join(nav)}</ol></nav></body></html>""", compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("OEBPS/content.opf", f"""<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:identifier id="id">urn:lectora:{abs(hash(title))}</dc:identifier>
<dc:title>{title}</dc:title>
<dc:creator>{author}</dc:creator>
<dc:language>{language}</dc:language>
{f'<dc:identifier>urn:isbn:{isbn}</dc:identifier>' if isbn else ''}
{f'<dc:date>{year}</dc:date>' if year else ''}
{f'<meta name="calibre:series" content="{series}"/><meta name="calibre:series_index" content="{index or 1}"/>' if series else ''}
<meta property="dcterms:modified">2026-01-01T00:00:00Z</meta>
</metadata>
<manifest><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>{''.join(items)}</manifest>
<spine>{''.join(spine)}</spine>
</package>""", compress_type=zipfile.ZIP_DEFLATED)

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("out")
    parser.add_argument("--title", default="Don Quijote de la Mancha")
    parser.add_argument("--author", default="Miguel de Cervantes")
    parser.add_argument("--language", default="es")
    parser.add_argument("--series")
    parser.add_argument("--index")
    parser.add_argument("--isbn")
    parser.add_argument("--year")
    args = parser.parse_args()
    main(args.out, args.title, args.author, args.language, args.series, args.index, args.isbn, args.year)
