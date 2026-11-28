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
  reglas, lo completado, por revisar y las sesiones de lectura. Nada de lo que guardas se
  pierde por cómo se escribe: una línea cortada no se pega a la siguiente (`LineFile`), lo que
  guardas mientras el registro se lee se aplica encima de la lectura (`WritesDuringRead`), la
  posición se guarda también al cerrar el libro o salir de la app, y cada aparato tiene su
  propio id aunque venga de un respaldo (`DeviceIdentity`, M7). Un archivo de `.lectora/` que
  no se puede leer no se toca y te lo digo una vez (auditoría de medios; `AuditoriaMediosTests`).
- Lo que iCloud todavía no baja nunca se pisa ni se borra: la app pide bajarlo, espera y te
  dice que vuelvas a intentar; mover el Gabinete primero baja lo que falta y, si no baja, no
  mueve nada (auditoría 1; `AuditoriaUnoTests`, y solo `ChangeLog`,
  `SessionLog`, `NoteFolder` y `SideFile` escriben en la carpeta). Lo que guardo mientras
  iCloud baja no se pierde aunque cierres la app: espera en el dispositivo, con su Gabinete
  (`PendingWrites`, nunca dentro de la carpeta), y se escribe solo en cuanto baja, al volver
  a la app o al abrirla; si algo se iba a tirar después (juntar duplicados), no se tira
  (auditoría 2; `AuditoriaDosTests`). Un registro que iCloud no ha bajado no es uno vacío (la
  biblioteca dice «Bajando tu biblioteca» y vuelve a leer), mover el Gabinete primero escribe lo
  que esperaba y lo que espera solo crece renglón por renglón (auditoría 3).
- Lo que guardas se guarda sobre lo de ahora: después de esperar a internet o a otro trabajo,
  cada cambio vuelve a leer el libro y toca solo su dato (Hardcover revertía tus ediciones); si
  no se pudo guardar, lo encontrado se queda pendiente o en «Por revisar», nunca se tira; y un
  registro que no se pudo leer no vacía la biblioteca. Deshacer tampoco deja las cosas a medias
  (auditoría 6): si otro trabajo de toda la biblioteca corre, no toco nada, te digo por qué y el
  deshacer se queda para después; y regresa solo los datos que ese cambio tocó, sobre el libro de
  ahora (`Book.revertingEdits`). Lo que se quedó sin guardar por un trabajo largo se busca de nuevo
  en cuanto termina, y dice «espera», no «sin conexión»; y si mientras esperaba a internet abriste otro
  Gabinete o el libro ya no está, no se escribe nada (`stillHere`, auditoría 9). Mover el Gabinete no borra lo tuyo ni lo
  de otro aparato: copia a carpetas de trabajo hermanas (`StagedMove`), todas de esa corrida, y
  solo al final las pone en su lugar sin pisar lo que haya llegado; si falla quita solo esas para
  que puedas volver a intentarlo; la copia se comprueba ni de menos ni de más, y su último repaso
  va en segundo plano: lo que escribes mientras lo anota `WriteJournal` y se copia justo antes
  del cambio (auditorías 5 y 6; `AuditoriaCincoTests`, `AuditoriaSeisTests`). Igual al añadir un libro
  o traerlo de Calibre: se arma en una carpeta de trabajo hermana y entra a su lugar sin reemplazar
  (`FolderMove.placeNew`); si algo falla, solo se quita lo que puse yo, nunca lo que llegó de otro
  aparato con ese nombre (auditoría 9; `AuditoriaNueveTests`).
- Una carpeta, y tampoco una nota («ideas.md» junto a «Ideas.md», `NoteFolder.freeName`, auditoría 9),
  nunca tiene una gemela que solo cambia en mayúsculas: iCloud y la Mac no las distinguen y el iPhone sí. Si ya existe con otras mayúsculas, el libro entra a ella y el
  catálogo guarda el nombre que tiene en el disco (`FolderMove.createFolder`,
  `moveBookFolder`; auditoría 2, `AuditoriaDosTests`, también en un disco sensible). Tampoco
  al deshacer un cambio de carpeta; una ruta guardada antes con otras mayúsculas se corrige al
  abrir y «Ordenar» junta las gemelas que quedaron de antes (auditoría de medios). «Ordenar»,
  abrir la app y traer de Calibre no se congelan aunque tengas miles de libros: el disco se lee
  una vez por carpeta (`SpellingIndex`), los libros se arman una vez al final y la corrección al
  abrir corre fuera del hilo de la interfaz (auditoría 3; `AuditoriaTresTests`, 5,000 libros y
  1,500 autores leyendo la carpeta de los autores una sola vez, también al mover libros).
- Mientras ordeno o muevo tu Gabinete, lo que cambias no se pierde ni se revierte: un solo
  trabajo de toda la biblioteca a la vez («Ordenar», mover el Gabinete, traer de Calibre,
  añadir libros; `WorkLock`): lo que añades espera su turno, lo demás te dice por qué espera;
  cada libro se vuelve a leer del registro justo antes de ordenarlo, y lo que guardas mientras
  copio el Gabinete (la página, una sesión, una nota) pasa a la copia antes de borrar la vieja
  (auditoría 4; `AuditoriaCuatroTests`). Si iCloud no baja un registro, te enseño lo que sí
  llegó y dejo de esperar con un aviso, sin quitar ningún libro.
- Pendiente (A7, diseño): el registro crece con cada página asentada (4 cambios cada vez). La
  compactación sería que cada dispositivo reescriba solo su `<id>.jsonl` con el último cambio
  de cada campo y todas las lápidas (gana el último por campo, así que el estado no cambia),
  de forma atómica, coordinada con iCloud y solo con su registro bajado; y que la posición se
  guarde menos seguido. No se hizo aún: reescribir un archivo que iCloud sincroniza necesita
  probarse con dos aparatos de verdad, no solo en `swift test`.
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
