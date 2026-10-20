# Diseño — versión elegida: v7 «Nativo con oficio»

Componentes nativos de Apple (Human Interface Guidelines, Liquid Glass en iOS 26) con
pocos detalles propios bien cuidados: fondo cálido, títulos en serif, portadas con lomo
y un solo color de acento reservado para tus marcas.

Prototipo navegable: lienzo de UI (página «✓ Elegida — v7 Nativo con oficio»). Las
versiones v1–v6 y v8 quedan como archivo.

## Tokens (`App/Shared/Design/Theme.swift`)

| Token | Valor | Uso |
|---|---|---|
| `groupedBackground` | `#F2F1EE` | Fondo de todas las pantallas (gris cálido, no el gris frío del sistema) |
| `surface` | `#FFFFFF` | Tarjetas y listas agrupadas |
| `paper` | `#FBFAF7` | Página del lector |
| `ink` | `#1C1B19` | Texto, botón principal, barras de progreso, `tint` de la app |
| `secondaryInk` | `#77746D` | Texto secundario |
| `track` | `#E6E3DC` | Pista de las barras de progreso |
| `pencil` | `#B8372A` | **Solo** tus marcas: subrayados, notas, cinta de marcador |
| `cardRadius` | 22 pt | Esquinas de tarjetas (continuas) |

Tipografía: SF Pro para la interfaz; New York (`.serif`) para títulos grandes, títulos
de libro y citas.

## Reglas

- El vidrio (Liquid Glass) va solo en la capa de controles: barra de pestañas, botones
  flotantes y paneles del lector. Nunca sobre el contenido. En iOS/macOS < 26 se usa
  `.ultraThinMaterial`.
- El rojo lápiz nunca decora la interfaz; si aparece, es algo que hiciste tú.
- Un botón principal por pantalla (cápsula de tinta). El resto, botones del sistema.
- Las portadas tienen lomo (sombra a la izquierda) y sombra suave: se leen como objetos.

## Pantallas

| Pantalla | Archivo | Qué tiene |
|---|---|---|
| Leyendo | `Home/HomeView.swift` | Título grande, botón de cuenta, tarjeta del libro actual (portada con cinta, «Cap. · min para terminarlo», progreso, «Seguir leyendo» + escuchar), fila «En tu mesa» |
| Biblioteca | `Library/LibraryView.swift` | Menú ordenar (Recientes, Título, Autor, Avance + «Solo descargados»), «+», resumen, Portadas/Lista, menú contextual |
| Cuaderno | `Notebook/NotebookView.swift` | Repaso / Libros / Temas |
| Buscar | `Search/SearchView.swift` | Pestaña de búsqueda aparte (iOS 18+ `Tab(role: .search)`) |
| Lector | `Reader/ReaderView.swift` | Papel a sangre; al tocar el centro aparecen: cerrar, Aa + marcador, panel inferior con capítulo, %, deslizador e Índice/Buscar/Guiada/Escuchar |

## Pendiente de diseño en código

- Datos reales (LectoraCore) en lugar de `SampleLibrary`.
- Hoja «Aa», índice, modo guiado y escuchar.
- Menú nativo al subrayar con trazo de lápiz.
- iPhone Duo: dos columnas al desplegar (biblioteca + libro, o dos páginas).
