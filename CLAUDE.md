# Gabinete (antes Lectora): reglas del proyecto

- Interfaz en español; código y comentarios en español, como el resto del repo.
- **Sistema de diseño obligatorio** (docs/sistema-diseno.md): las pantallas no usan
  números, colores ni fuentes sueltos; usan `Theme`, las fuentes de `Font` y los
  componentes de `App/Shared/Design/Components.swift`. **Nada se crea suelto**: si falta
  algo, se agrega al sistema y a su catálogo en el documento. `DesignRulesTests` (en
  `swift test`) lo verifica en CI; excepciones con `// ds-exception: <motivo>` y su fila
  en «Excepciones».
- Pulida del 19 nov 2026, cada una con su prueba en `DesignRulesTests`: nunca se suman
  tokens («s + xxs»): la medida que falte se nombra en `Theme`; toda pantalla usa su receta
  (`.screen()`, `.pushedScreen()` o `.formScreen()`: papel de fondo y botones de la barra en tinta, como iOS); el ícono verde va al final del
  encabezado; ningún texto dice «pronto» ni «próximamente»; saltar o no hacer nada («Ahora no», «Empezar sin libros») nunca es el botón oscuro; los grises de texto
  pasan el contraste mínimo sobre el papel; todo porcentaje sale de `percentText`.
- Antes de decir «listo»: `docs/entrega.md` (medir, claro y oscuro, y el informe con
  «comprobado», «hecho sin comprobar» y «no hecho»).
- Nombre visible: **Gabinete**. El código interno conserva «Lectora» (`LectoraCore`,
  `Lectora.xcodeproj`, `.lectora/`) hasta un renombre aparte; en textos de la app, Gabinete.
- Interoperabilidad con Calibre: la carpeta de la biblioteca mantiene la forma de Calibre
  (`Gabinete/Biblioteca/Autor/Título (id)/archivo + cover.jpg + metadata.opf`). No romper ese formato.
- Notas: Markdown normal en `Gabinete/Notas/`, legible fuera de la app. Gabinete nunca cambia el nombre de tus notas por su cuenta: el archivo se renombra solo cuando tú cambias el título (si ya hay otra nota con ese nombre, va como «Ideas 2»), y el título se lee siempre igual (lo que quita la vista previa no toca el título; una cerca de código no es título); si no, se rompen sus enlaces en Obsidian (auditorías 7 y 8, `testNotesNeverRenameThemselves`, `testRenamingToATakenTitleUsesTheNextName`).
- Sin servidor: el catálogo y los subrayados viven en los registros de LectoraCore.
- Pruebas con fechas: no supongas UTC. Arma las fechas en el calendario local (`Calendar.current`);
  CI corre `swift test` también con `TZ=America/Mexico_City` para atraparlo.
- Números que llegan del lector web (avance, progreso): siempre por `readingFraction`
  (foliate da NaN en secciones de dos páginas y la app se cerraba). Lo vigila `DesignRulesTests`.
- Una posición «está en la página» si cae entre su principio y su final (reader.js, con CFI);
  nunca compares el principio exacto ni el avance: cambian al volver a paginar.
- Sin advertencias de Xcode (26 nov 2026): GitHub compila el iPhone, el Mac y LectoraCore
  tratando cada advertencia como error; si aparece una, se arregla, no se apaga.
- Antes de subir: `swift test` en `Packages/LectoraCore` (en CI) y `scripts/lint-design.sh`.
