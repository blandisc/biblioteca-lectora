# Gabinete

Para leer y pensar: lector, manejador de biblioteca (un Calibre moderno) y notas en Markdown, en iPhone y Mac. Sin servidor: tu Gabinete es una carpeta tuya (por ejemplo en iCloud Drive) con `Biblioteca/` (forma de Calibre) y `Notas/`. Antes se llamaba «Biblioteca Lectora»; el código interno conserva ese nombre (`LectoraCore`, `Lectora.xcodeproj`) por ahora.

## Documentación
- [PRD v4.0](docs/PRD.md): decisiones de arquitectura, catálogo de funcionalidades priorizado y fases.
- [Visión de producto](docs/vision-producto.md)
- Investigación: [Calibre](docs/investigacion/01-calibre.md) · [Servidores de biblioteca](docs/investigacion/02-servidores-biblioteca.md) · [Lectores](docs/investigacion/03-lectores.md) · [PDF y cómics](docs/investigacion/04-pdf-y-comics.md) · [IA e insights](docs/investigacion/05-ia-e-insights.md) · [Reader y Readwise](docs/investigacion/06-readwise-reader.md) · [IA en dispositivo y nube](docs/investigacion/07-ia-dispositivo-y-nube.md)

## Desarrollo

Requisitos: un Mac con Xcode 16 o posterior y [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
./scripts/fetch-foliate.sh   # descarga foliate-js (MIT) fijado a un commit
xcodegen generate            # genera Lectora.xcodeproj
open Lectora.xcodeproj       # esquemas: Lectora_iOS y Lectora_macOS
```

Antes de correr en tu iPhone, cambia `PRODUCT_BUNDLE_IDENTIFIER` en `project.yml` y elige tu equipo de firma en Xcode.

| Carpeta | Qué contiene |
|---|---|
| `Packages/LectoraCore` | Núcleo multiplataforma: modelo, reloj híbrido y registro de cambios para la sincronización sin servidor. Pruebas: `swift test --package-path Packages/LectoraCore` |
| `App/Shared` | App SwiftUI para iPhone y Mac: lector (WKWebView + foliate-js) y pantalla provisional de la prueba S1 |
| `App/Resources/Reader` | `reader.html` y `reader.js`: el puente entre foliate-js y la app |
| `.github/workflows/ci.yml` | Pruebas del núcleo y compilación para iPhone y Mac en cada push |
