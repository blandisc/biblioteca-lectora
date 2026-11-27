# Gabinete: fallas encontradas leyendo el código (prueba adversarial)

Repo: `biblioteca-lectora/.claude/worktrees/gabinete-continuacion-verificacion-7f1ee5` (commit cb0a649).
Solo lectura. Las pruebas de apoyo están en `/tmp/gab-audit/` (`probe/`, `fs.swift`, `fs2.swift`, `self.swift`).

**Línea base:** `swift test --package-path Packages/LectoraCore` da **159 pruebas, 0 fallas**.

Rutas relativas a `App/Shared/` (app) o a `Packages/LectoraCore/Sources/LectoraCore/` (core).
**CONFIRMADO** quiere decir que lo reproduje con un programa o que se sigue del código y de cómo se comporta el sistema de archivos, sin depender de nada más. **PLAUSIBLE** quiere decir que depende de cómo se porte iCloud o de cuándo pasen las cosas.

---

## CRÍTICO (cierre de la app o pérdida de datos)

### C1. «Mover mi Gabinete ahí» borra una carpeta `Biblioteca` o `Notas` que ya esté en el destino — CONFIRMADO
`Library/LibraryStore.swift:124` y `:209-216`. `move(toCabinet:)` solo se niega si existe `Biblioteca/.lectora`. Luego `coordinatedCopy` hace `removeItem(at: to)` antes de copiar (`.forReplacing`).
- **Escenario A:** eliges en iCloud una carpeta que ya tiene `Notas/` (por ejemplo, una bóveda de Obsidian) o una `Biblioteca/` propia sin `.lectora`. Las dos se borran **sin papelera** y se cambian por las del dispositivo. Lo comprobé en `/tmp`: `importante.md` desaparece.
- **Escenario B (PLAUSIBLE):** en un iPhone nuevo, iCloud todavía no ha bajado la carpeta `.lectora` del Gabinete de la Mac. `hasLibrary` da falso y se ofrece «Mover». La copia borra la biblioteca entera de la Mac en iCloud y pone encima la del iPhone, que está vacía.
- **Lo que ve el usuario:** sus notas, o la biblioteca de la Mac, desaparecen.
- **Arreglo:** negarse a mover si el destino ya tiene `Biblioteca` o `Notas` (o copiar a un nombre nuevo), y nunca usar `removeItem` sobre el destino.

### C2. Los estantes, reglas, «no son duplicados», «Por revisar» y «completados» se pisan entre dispositivos y se borran al abrir — CONFIRMADO (lógica) / PLAUSIBLE (momento)
`LibraryStore.swift:166-188, 224-230, 913-941`.
- `loadReviews()` solo corre en `init` y en `open(cabinet:)`. Corre **justo después** de `reload()` y **antes** de `refreshFromCloud()`. `refreshFromCloud` vuelve a leer el registro, pero **nunca** los `.json`.
- `reviews`, `filled` y `pendingLookup` se filtran con `book(id:) != nil`. Si los registros aún no bajaron, `books` está vacío y todo queda filtrado. El siguiente `save()` escribe el diccionario vacío encima del archivo.
- `estantes.json`, `reglas.json` y `no-duplicados.json` se escriben enteros desde la memoria. Ejemplo: la Mac lleva abierta todo el día con `[A]`. En el iPhone creas el estante B. En la Mac renombras A y se guarda `[A']`: **B se pierde**. Lo mismo pasa con las reglas que aprende `rename()`.
- **Lo que ve el usuario:** desaparecen estantes, reglas de autores, la bandeja «Por revisar» y «Lo que se completó solo».
- **Arreglo:** volver a leer los `.json` en `refreshFromCloud`/`reload`, no filtrar antes de tener el catálogo, y guardar cada estante o regla como entidad del registro de cambios (que ya tiene `EntityKind.shelf`) en vez de un archivo entero.

### C3. Una lectura fallida de un registro deja la biblioteca vacía — CONFIRMADO (lógica) / PLAUSIBLE (disparador)
`core/Sync/ChangeLog.swift:63-71` y `LibraryStore.swift:226`.
- `readAll()` lanza un error si **un solo** archivo `.jsonl` no se puede leer, por ejemplo un archivo «sin datos» de iCloud estando sin conexión en la Mac. `reload()` hace `try?` y aplica un estado vacío: `books = []`.
- **Lo que ve el usuario:** la biblioteca queda vacía. Si importa de nuevo, salen duplicados (la detección por huella se compara contra `books`). Además, C2 borra «Por revisar» y «completados».
- **Arreglo:** leer archivo por archivo, saltarse el que falle sin descartar los demás, y no publicar un estado vacío cuando antes había libros.

### C4. El registro propio puede reemplazarse si iCloud lo desalojó del iPhone — PLAUSIBLE
`core/Sync/ChangeLog.swift:40-47`. Si `<deviceID>.jsonl` está desalojado y solo queda `.<id>.jsonl.icloud`, `fileExists(ownFile)` da falso. Entonces `data.write(.atomic)` crea un archivo **nuevo** con solo los cambios recientes. iCloud lo ve como conflicto, y la versión «ganadora» puede ser la corta.
- **Lo que ve el usuario:** desaparecen en todos los dispositivos los libros que se importaron en ese iPhone.
- **Arreglo:** antes de escribir, comprobar si existe el marcador `.icloud`, bajar el archivo con coordinación (`NSFileCoordinator`) y solo entonces agregar al final.

### C5. Un número de tomo enorme o «inf» cierra la app en cada arranque, en los dos dispositivos — CONFIRMADO
`Model/ShelfBook.swift:103`: `value.rounded() == value ? String(Int(value))`.
- **Escenario:** en la ficha (iPhone `MetadataEditorView.swift:166` o Mac `MacBookInspector.swift:224`) escribes «inf», «1e20» o «99999999999999999999» como número del tomo. `Double(...)` lo acepta. También puede llegar en el `group-position` o `calibre:series_index` de un EPUB (`reader.js:676` solo descarta valores no finitos; `1e300` pasa).
- Pasa lo mismo con un `calibre_id` gigante en el registro: `core/Model/Book.swift:157` hace `Int($0)`. Lo reproduje en `probe`: *Fatal error: Double value cannot be converted to Int*.
- **Lo que ve el usuario:** la app se cierra al reconstruir la estantería y sigue cerrándose en cada arranque. El dato está en el registro sincronizado, así que **también se cierra la otra máquina**.
- **Arreglo:** usar `Int(exactly:)` o limitar el rango (0–9999) al leer y al escribir el número de tomo y el `calibre_id`.

### C6. Juntar duplicados a medias deja formatos y archivos fuera del catálogo — CONFIRMADO (lógica)
`LibraryStore.swift:762-815`. Por cada «otro» se mueven sus archivos y se escribe su lápida (`_deleted`). Solo **al final** se guarda `keep` con sus `extraFiles` nuevos.
- **Escenario:** un `moveItem` falla porque ya existe un archivo con ese nombre, o el `update` final lanza `folderTaken`. Por ejemplo, `merged()` toma otro autor y la carpeta cambia de nombre.
- **Lo que ve el usuario:** «No se pudo juntar». Los otros libros ya desaparecieron del catálogo y sus PDF quedaron en la carpeta del que se queda sin que el catálogo los conozca. En el iPhone el formato repetido se borra sin papelera, pero hoy esta función solo existe en la Mac.
- **Arreglo:** hacer primero todos los movimientos y el `update(keep)`, escribir las lápidas al final, y deshacer los movimientos si algo falla.

---

## ALTO

### A1. Cada edición reescribe **todos** los campos del libro, así que una copia vieja pisa lo que hizo el otro dispositivo — CONFIRMADO
`LibraryStore.swift:986-991` usa `book.changes(clock:)` (los 17 campos con marca nueva). La regla de que «gana el último por campo» deja de servir.
- **Prueba** (`probe` A): el iPhone marca «Leído». La Mac, sin haber sincronizado, agrega una etiqueta. Resultado: `toRead`, y el «Leído» se pierde.
- Lo mismo con `tidy()`, que reescribe toda la biblioteca, `rename`, `applyRules`, `identify` y el editor del iPhone, que guarda el `draft` de cuando se abrió. Si la Mac juntó un PDF en `extraFiles` y el iPhone guarda una ficha vieja, el PDF sale del catálogo.
- También infla el registro: un «Ordenar» con 10 000 libros agrega unos 170 000 renglones.
- **Arreglo:** que `record` escriba solo los campos que cambiaron frente al libro actual del estado.

### A2. No se puede corregir mayúsculas de autor o título, y una búsqueda segura se pierde sin aviso — CONFIRMADO
`LibraryStore.swift:369-371`. `standardizedFileURL` distingue mayúsculas, pero APFS e iCloud no. `fileExists(newFolder)` da verdadero porque es la misma carpeta, y se lanza `folderTaken`.
- Lo comprobé: `movesFolder = true` y `fileExists = true`.
- **Escenarios:** «gabriel garcía márquez» → «Gabriel García Márquez» en la ficha, en «Renombrar o juntar» (`rename`, que es justo el caso de uso de CB-2) o en el autocompletado de `identify`.
- **Lo que ve el usuario:** «Ya hay otro libro con ese título y autor». En el lote todos fallan. En `identify`, el `try?` se traga el error y además se limpia «Por revisar» (`:488-491`).
- **Arreglo:** comparar con `localizedCaseInsensitiveCompare` o por identificador de archivo, y renombrar en dos pasos (a un nombre temporal y luego al final).

### A3. Deshacer «Renombrar autor» (⌘Z) apunta a formatos extra que ya no existen — CONFIRMADO (lógica)
`LibraryStore.swift:392-400` y `:676-679`. Al renombrar, `extraFiles` pasa a «T - Nuevo.pdf» en el disco. `restore(original)` usa el `extraFiles` viejo («T - Viejo.pdf»). Como `wanted == extra`, no se mueve nada, y el catálogo queda con «T - Viejo.pdf» aunque el disco tiene «T - Nuevo.pdf».
- **Lo que ve el usuario:** el PDF desaparece de la ficha y queda como archivo huérfano.
- **Arreglo:** en `update`, tomar los `extraFiles` del libro actual (`original`) y renombrarlos por extensión.

### A4. Editar título o autor de un libro que no está bajado de iCloud falla en el iPhone — PLAUSIBLE
`LibraryStore.swift:375-384`. Se mueve la carpeta y luego se busca `oldFile` por su nombre real. En iOS solo existe `.nombre.icloud`, así que `moveItem` lanza un error y se revierte. `tidy()` ya tiene en cuenta ese marcador (`:434`), pero `update` no.
- **Lo que ve el usuario:** un error de archivo inexistente al guardar la ficha, al renombrar o al aplicar reglas en libros que solo están en la nube.
- **Arreglo:** si existe el marcador `.icloud`, renombrar el marcador o coordinar la descarga antes de renombrar.

### A5. Desde el iPhone no se puede abrir el Gabinete que ya existe en iCloud — PLAUSIBLE
`Screens/SettingsScreen.swift:151` y `Screens/WelcomeScreen.swift:98` llaman a `hasLibrary(in: folder)` **antes** de `startAccessingSecurityScopedResource()`. En iOS, `fileExists` fuera del sandbox da falso, y se ofrece «Mover mi Gabinete ahí». `move()` sí pide acceso, ve `.lectora` y lanza `alreadyHasLibrary`.
- **Lo que ve el usuario:** «Esa carpeta ya tiene una biblioteca… Ábrela», pero no hay ningún botón para abrirla. Se queda atorado.
- **Arreglo:** llamar a `CabinetLocation.startAccessing(folder)` antes de decidir qué botón mostrar.

### A6. «Detener» no detiene una búsqueda en lote que se inició después — CONFIRMADO (lógica)
`LibraryStore.swift:841-862`. `stopBatch()` pone `batchTask = nil`, pero la tarea vieja sigue esperando su `identify`. Al terminar, ejecuta `self?.batchTask = nil` y `batch?.record(...)` sobre el lote **nuevo**.
- **Lo que ve el usuario:** cuentas equivocadas, dos lotes al mismo tiempo (más presión sobre Open Library) y un botón Detener que ya no hace nada.
- **Arreglo:** cada tarea guarda su propio identificador y solo limpia `batchTask`/`batch` si sigue siendo la vigente.

### A7. El registro crece sin límite y se lee entero en el hilo de la interfaz — CONFIRMADO (lógica)
`LibraryStore.swift:964-976` y `:224-229`. Cada vez que la página se asienta (1,5 s, `ReaderController.swift:548-553`) se agregan 4 cambios de unos 300 bytes. No hay compactación. `reload()` decodifica **todas** las líneas con `JSONDecoder` en el `@MainActor` al arrancar y cada vez que la app vuelve al frente (más 3 s).
- Con un año de lectura son decenas o cientos de MB.
- **Lo que ve el usuario:** la app se congela segundos al abrirse o al volver a ella.
- **Arreglo:** guardar la posición con menos frecuencia y fuera del registro general (o compactar), y leer y decodificar en segundo plano.

### A8. Trabajo de O(n) a O(n²) por cada cambio publicado (10 000 libros) — PLAUSIBLE (no medido)
- `AppModel.swift:36` hace `rebuildShelf()` en **cada** `objectWillChange`: cada página asentada, cada inserción en `identifying`, cada paso del lote. `ShelfBook.init` hace 2 consultas al disco por libro (`coverURL` y `isDownloaded`).
- `MacLibraryWindow.swift:150` llama a `duplicateGroups()` dentro del `body` de la barra lateral. `:193`/`:275` llama a `incompleteBooks()`, que hace un `fileExists` por libro. `SavedShelf.contains` vuelve a analizar la consulta por cada libro y por cada estante (`:162`).
- **Lo que ve el usuario:** la Mac se traba al leer o durante un lote grande.
- **Arreglo:** calcular duplicados, incompletos y conteos de estantes en el store, cuando cambian los libros, y guardar el resultado.

### A9. Los subrayados no viven en el Gabinete, y juntar duplicados deja huérfanos los del otro dispositivo — PLAUSIBLE
`Reader/AnnotationStore.swift:67-70` guarda en Application Support de cada dispositivo. `merge` (`LibraryStore.swift:793-798`) solo pasa los subrayados de la Mac. Los del iPhone siguen apuntando al libro que ya tiene lápida.
- **Lo que ve el usuario:** después de juntar en la Mac, en el iPhone desaparecen de la ficha los subrayados del libro que se juntó.
- **Arreglo:** mover el registro de subrayados a `.lectora/` (como el catálogo) o hacer que el iPhone, al leer la lápida, reasigne los subrayados a quien se quedó.

### A10. Si falla la migración de Calibre se puede borrar una carpeta ajena — PLAUSIBLE
`LibraryStore.swift:1088-1092` y `:1117-1119`. Cuando el número de Calibre ya está tomado, se calcula una carpeta nueva **sin** revisar que exista en el disco. Si `copyItem` falla porque ya existe (otro dispositivo la creó y su registro no ha llegado), el `catch` hace `removeItem(at: to)` y borra la carpeta del otro libro.
- **Arreglo:** buscar un número libre con un bucle sobre el disco, como hace `importFile`, y en el `catch` borrar solo lo que esta corrida creó.

---

## MEDIO

- **M1. Título vacío sin ISBN cuenta como «sin internet».** `core/Lookup/MetadataService.swift:110`: con 0 preguntas, `failed == asked` da `.unreachable`. CONFIRMADO (`probe` B). El libro queda pendiente para siempre y **en un lote detiene todo y marca el resto como pendiente** (`LibraryStore.swift:846-851`). Se llega con «Buscar con otros datos» sin título ni ISBN, o desde la ficha de la Mac. Arreglo: `asked > 0 && failed == asked`.
- **M2. Un fallo aislado (429 en las dos fuentes para un solo libro) detiene el lote entero.** `LibraryStore.swift:846`. Arreglo: detenerse solo después de N fallos seguidos o si `NWPathMonitor` dice que no hay red.
- **M3. Calibre con varios formatos: solo se registra el preferido.** `LibraryStore.swift:1098-1106` nunca llena `extraFiles`. Los otros formatos se copian a la carpeta pero no aparecen en el catálogo. CONFIRMADO (lógica). Arreglo: llenar `extraFiles` con `entry.formats`.
- **M4. El formato que se junta no queda en la detección de duplicados.** `importFile` (`:293`, `:312-313`) compara la huella y la extensión solo con `filePath`. Si vuelves a importar el mismo PDF que juntaste, entra otra vez. Arreglo: guardar las huellas de `extraFiles`.
- **M5. Mover el Gabinete a una subcarpeta de sí mismo** (por ejemplo «Gabinete › Notas») hace una copia recursiva hasta topar el límite de ruta. CONFIRMADO en `/tmp`: cientos de niveles `Notas/Notas/...` y luego un error. No se pierde nada, pero llena el disco o iCloud de basura. Arreglo: negarse si el destino está dentro del origen o el origen dentro del destino.
- **M6. Lo que se escribe durante un `move(toCabinet:)` se pierde.** Solo se espera a `lastImport` (`:125`). El lote, `identify`, la posición de lectura y la migración siguen escribiendo en el origen, que se borra al final. Arreglo: pausar el lote y bloquear escrituras mientras `moving`.
- **M7. Mismo `deviceID` en dos aparatos** (restaurar un respaldo en un iPhone nuevo): `AnnotationStore.swift:73-79` lo guarda en UserDefaults, que viaja en el respaldo. Dos dispositivos escriben el mismo `.jsonl` y aparecen conflictos de iCloud. Arreglo: guardarlo en el llavero con `ThisDeviceOnly` o regenerarlo si cambia `identifierForVendor`.
- **M8. Mismo número de Calibre en dos dispositivos a la vez** (`:319-323`). Con el mismo título y autor, comparten carpeta. Al juntar o borrar uno se va la carpeta del otro, y Calibre ve números repetidos. PLAUSIBLE.
- **M9. Si se guarda el OPF o el registro después de mover la carpeta** (`:408-409`) y algo falla, el disco ya cambió pero el catálogo sigue con la ruta vieja: el libro queda «perdido» hasta un «Ordenar».
- **M10. Libro grande en el lector:** `Reader/ReaderSchemeHandler.swift:43` hace `Data(contentsOf:)` del archivo completo en el hilo principal y luego lo copia al proceso web. Con un PDF o CBZ de 300 MB en iPhone, la app se congela y puede cerrarse por falta de memoria. Arreglo: leer en segundo plano y entregar por partes.
- **M11. Ficha de la Mac:** «Autores, separados por comas» (`MacBookInspector.swift:222`). Si escribes «Cortázar, Julio», salen dos autores, y el iPhone separa con «&». Arreglo: un solo separador («&», como Calibre).
- **M12. Cambias de libro en la tabla con cambios sin guardar y se pierden sin aviso** (`MacBookInspector.swift:30`).

## BAJO

- **B1.** `CalibreLayout.sanitize` corta a 100 caracteres, no a bytes. Un título con 100 emojis compuestos da un nombre de 2 505 bytes y error 514 al importar. CONFIRMADO (los títulos largos en CJK y devanagari sí funcionan).
- **B2.** Un descarte de «No son el mismo» A–B vuelve a salir si aparece un C parecido a los dos (`DuplicateFinder.swift:37-40`, `probe` C: `[3]`).
- **B3.** `MacBookRow.stars`: `String(repeating:count: Int(rating.rounded()))` se cierra con una valoración negativa (de un OPF raro con `calibre:rating` negativo).
- **B4.** `FilledField.restore` separa autores con « & » y etiquetas con «, ». Un autor o etiqueta que contenga esos separadores se parte al deshacer.
- **B5.** `progress` es compartido entre `runImport` y `migrateFromCalibre`. Si corren juntos, la barra se reinicia o desaparece antes de tiempo.
- **B6.** Lote durante un cambio de Gabinete: escribe IDs ajenos en `por-buscar.json` y `por-revisar.json` de la biblioteca nueva. Se filtran al cargar, pero ensucian.
- **B7.** `merge` pone `cfi = nil` en los subrayados que pasan. Si su ID ya estaba en `subrayados.anclajeIntentado.v2`, no se vuelven a anclar nunca. Los marcadores pasan con un CFI de otro archivo.
- **B8.** `NotesStore.add` con un `fileName` cuya nota aún no está en memoria sobrescribe el archivo con solo «# Título + cita».
- **B9.** `ReaderSchemeHandler` revisa la ruta con `hasPrefix`, así que `…/Reader` también acepta `…/ReaderX`. Hoy es inofensivo.

## Revisado sin falla
- `dismissDuplicates`: `group[(i+1)...]` en el último elemento da un trozo vacío y no se cierra.
- `DuplicateFinder.groups`: `$0[0]` solo se usa con grupos de 2 o más.
- `ranked[0]` está protegido.
- `Book.authorSort` con `last!` está protegido.
- `ImageSize` con alto 0 no se cierra.
- `guideBand` siempre recibe alto ≥ 1.
- `slitNextSection` al final del libro devuelve `null`.
- `anchored` con `cfi` nulo se ignora.
- `RequestPacer` funciona.
- 404, 429 y 5xx se distinguen correctamente.
- `AppModel.shelfByID` usa `uniqueKeysWithValues` con IDs únicos.
- Copiar un EPUB de 300 MB en la importación ya va fuera del hilo principal.
