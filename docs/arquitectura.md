# Gabinete: arquitectura y decisiones

> **Estado:** decidido · **Fecha:** 18 nov 2026 · Complementa el [PRD](PRD.md). Cuando
> el PRD y este documento no coinciden, manda este.

Gabinete es, por ahora, **un producto para una persona** (su autor) que más adelante se
compartirá. Sirve para **libros y PDF propios, sin DRM**: lo que compras en Kindle no se
lee aquí (sus subrayados sí llegan, por Readwise).

## El dibujo

```
                     iCloud Drive / Gabinete            ← el centro: tus archivos
                     ├── Biblioteca/   forma de Calibre + .lectora/ (registros)
                     └── Notas/        Markdown
                        ▲          ▲            ▲
          App iPhone ───┘   App Mac ┘     Calibre · Obsidian (invitados)
                                  │
                                  └── (después) web servida por el Mac

   Cada app habla directo, con tus llaves, con:
   Readwise ⇄ subrayados · Hardcover → qué lees · Open Library / Google → datos · OpenRouter → IA
```

## Decisiones

### D1. Sin servidor propio. Nunca.
No hay un servidor de Gabinete: ni para sincronizar, ni para cuentas, ni para la web. Todo
lo que la app sabe vive en tu carpeta y en tus dispositivos. Los servicios externos se
llaman directo desde cada app con tu llave. Cualquier propuesta que necesite un servidor
nuestro queda fuera.

### D2. El centro es la carpeta `Gabinete/` en iCloud Drive
- `Biblioteca/` con la forma de Calibre (`Autor/Título (id)/archivo + cover.jpg + metadata.opf`).
- `Biblioteca/.lectora/`: registros por dispositivo (JSONL, solo se agregan líneas),
  reglas, lo completado, por revisar y, después, las sesiones de lectura.
- `Notas/`: Markdown normal, legible por Obsidian o cualquier editor.
- Si borras Gabinete, todo sigue ahí y se abre con Calibre y Obsidian.

### D3. Gabinete es el dueño del catálogo; Calibre es invitado
Calibre guarda su catálogo en una base SQLite (`metadata.db`) que se corrompe si dos lados
la escriben o si iCloud la sincroniza a medias. Por eso:
- **Migración única** desde tu `metadata.db` (B4).
- Después, Gabinete escribe cada `metadata.opf` al día. Si un día vuelves a Calibre, su
  «Restaurar base de datos» la reconstruye desde esos archivos: no pierdes nada.
- Abrir Calibre sobre la carpeta de iCloud está permitido para **consultar o convertir**,
  con la carpeta en «Mantener descargado» y sin editar datos en los dos lados.

**Hecho:** Ajustes › Gabinete › «Traer mi biblioteca de Calibre…». `CalibreLibrary` lee
una copia de `metadata.db` (libros, autores, series, etiquetas, editorial, idioma,
calificación, sinopsis, identificadores con el uuid de Calibre, formatos y los subrayados
del visor); `CalibreMigrationPlan` separa lo nuevo, lo que ya estaba (mismo uuid, o título
y autor) y lo que no tiene archivo; la copia conserva la carpeta y el número de Calibre si
están libres. Los subrayados de Calibre se pintan en el texto al abrir el libro (se buscan por su cita).

### D4. Readwise: el lugar central de los subrayados, en las dos direcciones
Readwise es buen producto (su lector no) y debe poderse **entrar y salir sin perder nada**.
- **Gabinete → Readwise:** cada subrayado (cita, nota, posición, fecha y enlace
  `gabinete://subrayado/<id>`) se manda con la API oficial. Se guarda su `readwise_id`.
- **Readwise → Gabinete:** se traen los subrayados de otras fuentes (Kindle, Apple Books,
  Reader…) desde la última sincronización. Si el libro está en tu biblioteca se ancla en el
  EPUB por la cita; si no se puede, queda «sin anclar», nunca se pierde. Los de libros que
  no tienes aparecen en el Cuaderno con su título, sin archivo.
- **Sin duplicados:** cada subrayado lleva su origen. Lo que nació en Gabinete no se
  reimporta; las ediciones y los borrados viajan en ambos sentidos con su fecha (gana el
  cambio más reciente).
- **Salida libre:** exportar todo el Cuaderno a Markdown y al CSV de Readwise. **Entrada
  libre:** importar todo Readwise la primera vez.

**Hecho (sin probar contra Readwise real):** `LectoraCore/Connectors/Readwise.swift` y
`App/Shared/Library/Connectors.swift`. Los nuevos se mandan en un envío; las notas
editadas y los borrados, uno por uno; lo que llega se empareja por `readwise_id` o por
el enlace `gabinete://`. Lo que llega de un libro que no tienes queda con su título
(«fuera de tu biblioteca»). Los que llegan sin posición (de Readwise o de Calibre) se buscan por su cita la primera vez que abres el libro y, si aparecen, se pintan y quedan con su lugar.

### D5. Hardcover: de ida
Gabinete es la verdad; Hardcover es el registro público de lectura.
- Al abrir un libro: «Leyendo»; mientras lees: el avance; al terminar: «Leído» con fecha y,
  si quieres, calificación.
- Cada libro se reconoce en Hardcover por ISBN o título y autor, con el mismo motor de
  búsqueda de metadatos; su id se guarda como identificador (`hardcover:`) en el OPF.
- Su API está en beta: el conector va aislado para que una ruptura no afecte nada más.

**Hecho (sin probar contra Hardcover real):** `LectoraCore/Connectors/Hardcover.swift`.
El avance sale de la posición de lectura; se manda cuando cambia al menos 1 %.

### D6. Llaves propias hoy; iniciar sesión después
- Hoy pegas tus llaves (Readwise, Hardcover, OpenRouter). Se guardan en el **Llavero con
  sincronización de iCloud**: las pones una vez y sirven en el iPhone y el Mac.
- Más adelante, «iniciar sesión» donde el servicio lo permita sin un servidor nuestro
  (OAuth con PKCE). Tu identidad en Gabinete es tu Apple ID; no hay cuentas de Gabinete.

### D7. Un trabajo, un dispositivo
Sin servidor, el iPhone y el Mac podrían mandar lo mismo a Readwise o Hardcover. Cada
envío se anota como trabajo en el registro compartido; un dispositivo lo **toma** (con su
nombre y hora) y el otro lo respeta. Si no lo termina en un tiempo razonable, otro lo
retoma. Esto se construye **antes** de los conectores.

### D8. Web: después, servida por tu Mac (lista, no construida)
Una página web no puede leer iCloud Drive, y no habrá servidor (D1). La web será la app de
Mac sirviendo una página en tu red privada (por ejemplo Tailscale), para leer desde la
computadora del trabajo mientras el Mac esté prendido. Para que esté lista sin construirla:
- La lógica vive en `LectoraCore`, sin depender de la interfaz (ya es la regla).
- El lector ya es web (foliate-js + `reader.js`): el mismo motor sirve en un navegador.
- Todo cambio (subrayados, avance, sesiones) pasa por los registros, nunca solo por la
  pantalla: la web escribirá por el Mac en esos mismos registros.

## Fases

**A. Cerrar la app de iPhone (y Mac) para tu uso diario**
1. Coordinación entre dispositivos (D7).
2. Sesiones de lectura y diario (diseñados).
3. Migración de Calibre y primer arranque (D3).
4. Herramientas del lector: índice, buscar en el libro, subrayados del libro.
5. Readwise en las dos direcciones (D4) y Hardcover de ida (D5), con su pantalla de
   Conexiones.
6. Instalarla en tu iPhone (cuenta de desarrollador de Apple).

**B. El ecosistema:** el Mac como administrador (tabla tipo Calibre), convivencia con
Calibre, Kindle (`My Clippings.txt`, enviar a Kindle) y la web servida por el Mac (D8).

**C. IA y audiolibro** (al final, como se acordó).

**D. Compartir:** iniciar sesión en los servicios, bienvenida para otras personas y
distribución.
