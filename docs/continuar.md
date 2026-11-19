# Continuar el trabajo (paquete de la sesión del 18–19 nov 2026)

Para retomar en el Mac con Claude Code: abre esta carpeta y di
«Lee docs/continuar.md y sigue». Todo lo de esta sesión está en la rama `app-esqueleto`.

## Cómo trabajar aquí
- Reglas: `CLAUDE.md`, `docs/sistema-diseno.md` (obligatorio), `docs/entrega.md` (cómo
  decir «listo»), `docs/arquitectura.md` (decisiones D1–D8 y fases; manda sobre el PRD).
- Antes de subir: `swift test --package-path Packages/LectoraCore` (incluye
  `DesignRulesTests`) y `scripts/lint-design.sh`.
- En el Mac ya se puede lo que la nube no podía: `brew install xcodegen`,
  `./scripts/fetch-foliate.sh`, `xcodegen generate`, abrir `Lectora.xcodeproj` y correr en
  el simulador o en tu iPhone. Capturas: `./scripts/screenshots.sh out/prueba`
  (opciones de arranque en `App/Shared/LaunchOptions.swift`).
- CI (`.github/workflows/ci.yml`): núcleo y compilación iPhone/Mac en cada push. Las
  capturas (`capturas.yml`) ahora son solo a mano, para no llenar el correo.
- Commits en español; terminan con las líneas `Co-Authored-By` y `Claude-Session`.

## Dónde quedó
Fase A (cerrar la app de iPhone) casi completa. Hecho y en verde en CI hasta `80d836d`:
coordinación entre dispositivos (JobBoard, D7), sesiones y diario, notas en el Cuaderno,
herramientas del lector (índice, buscar, subrayados), Readwise de ida y vuelta y Hardcover
de ida (sin probar contra los servicios reales), migración de Calibre, bienvenida.

Último trabajo (`4173da4` + arreglo `9193c9c`, CI pendiente al empaquetar):
1. Subrayados sin posición (Calibre, Kindle vía Readwise) se anclan buscando su cita al
   abrir el libro: `reader.js` `anchor(items)`, `ReaderController.anchorPending()`
   (intentados en UserDefaults `subrayados.anclajeIntentado`).
2. Marcadores guardados en el registro (`LectoraCore/Model/Bookmark.swift`,
   `EntityKind.bookmark`, `LibraryStore` add/remove), cinta en el lector y la sección
   Lector › Marcas (`ReaderToolsSheet`).
3. Audiolibro escondido: `Features.audiobook` (Guiada, Escuchar, audífonos de la Mesa,
   mini reproductor) hasta la fase C.

## Primero, al llegar al Mac
1. Ver que CI de `9193c9c` pasó (el fallo de `4173da4` era solo un `import LectoraCore`
   que faltaba en `ReaderView.swift`). Si no, arreglar.
2. Correr la app en el simulador y comprobar en claro y oscuro: la cinta (poner, quitar,
   que siga al cambiar la letra), Lector › Marcas, y que no aparezcan los botones del
   audiolibro. Con un EPUB que tenga subrayados de Calibre: que se pinten al abrir.
3. Probar Readwise y Hardcover con tus llaves reales (Ajustes › Conexiones). Es lo único
   de la fase A que solo se ha probado contra respuestas escritas a mano.
4. Migración con tu `metadata.db` real (Ajustes › Gabinete › Traer de Calibre).
5. Instalar en tu iPhone (cuenta de desarrollador, fase A.6).

## Lo que sigue (propuesto)
- «Buscar en todo»: notas y subrayados además de libros.
- Editor de notas con formato en vivo.
- Fase B: el Mac como administrador (tabla tipo Calibre), convivencia con Calibre,
  Kindle (`My Clippings.txt`, enviar a Kindle), web servida por el Mac (D8).

## Lienzos y sistema de diseño (artifacts de claude.ai)
- Identidad: https://claude.ai/artifact/68U8tq9yioAXrcS4iQKGAm
- Diario de lectura: https://claude.ai/artifact/EFtPKrZotji3c7J7vqMVmN
- Sistema de diseño: https://claude.ai/artifact/UyHzDh55DSnZ8WH6HDg8Ng

Identidad cerrada: v2 con toques verdes sutiles (brand en botón principal, avance y
pestaña; accent verde hoja), Cinzel solo en la marca y los rótulos, oscuro neutro. No
reabrir.
