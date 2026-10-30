# Gabinete (antes Lectora): reglas del proyecto

- Interfaz en español; código y comentarios en español, como el resto del repo.
- **Sistema de diseño obligatorio** (docs/sistema-diseno.md): las pantallas no usan
  números, colores ni fuentes sueltos; usan `Theme`, las fuentes de `Font` y los
  componentes de `App/Shared/Design/Components.swift`. Si falta algo, se agrega al
  sistema y se documenta. `scripts/lint-design.sh` lo verifica en CI.
- Nombre visible: **Gabinete**. El código interno conserva «Lectora» (`LectoraCore`,
  `Lectora.xcodeproj`, `.lectora/`) hasta un renombre aparte; en textos de la app, Gabinete.
- Interoperabilidad con Calibre: la carpeta de la biblioteca mantiene la forma de Calibre
  (`Gabinete/Biblioteca/Autor/Título (id)/archivo + cover.jpg + metadata.opf`). No romper ese formato.
- Notas: Markdown normal en `Gabinete/Notas/`, legible fuera de la app.
- Sin servidor: el catálogo y los subrayados viven en los registros de LectoraCore.
- Antes de subir: `swift test` en `Packages/LectoraCore` (en CI) y `scripts/lint-design.sh`.
