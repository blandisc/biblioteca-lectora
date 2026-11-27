# Gabinete en el iPhone: revisión a mano de diseño y pruebas para romperla

- **Fecha:** 26 nov 2026
- **Simulador:** «Gabinete» (iOS 27, iPhone 17 Pro)
- **Compilación:** Debug del worktree `gabinete-continuacion-verificacion-7f1ee5`
- **Capturas:** las 20 más claras están en `/tmp/gab-audit/ios/`, a 1x.

## Cómo se probó

- **Para tocar la pantalla de verdad:** armé en `/tmp` un pequeño programa de pruebas de interfaz que toca, desliza y escribe sobre la app instalada. No cambié el repo y ya lo borré.
- **Lo que se probó:** claro, oscuro, la letra más grande de iOS (AX5) y Aumentar contraste.
- **Datos de prueba:**
  - un título de 201 letras con 4 autores;
  - «Ciencia/Ficción 🚀»;
  - un título vacío;
  - un autor escrito «Apellido, Nombre»;
  - un título árabe;
  - «Q»;
  - Rayuela repetido;
  - la serie Dune con tomos 1, 2, 2.5 y 10;
  - 0 libros;
  - 73 libros.
- **Cierres inesperados:** no hubo. No apareció ningún informe de cierre de Gabinete en DiagnosticReports. Los avisos graves del registro son ruido del sistema.
- **Lo que no se pudo probar:**
  - seleccionar texto real con el dedo (solo el modo de demostración);
  - el globo «Guiada» con toque;
  - el arrastre de la hoja;
  - «Mover a iCloud».

Severidad: **Crítico** (rompe o bloquea), **Alto** (engaña o casi no se puede usar), **Medio** (molesta o no cumple el sistema de diseño), **Bajo** (detalle).

---

## 1. Bienvenida (primer arranque, 3 pasos)

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| Medio | Con la letra más grande, el título «Para leer y pensar» queda **más chico que el párrafo**: el título de pantalla no crece con el tamaño de texto de iOS. Pasa en todas las pantallas (Biblioteca, Cuaderno, Buscar, Por revisar, Diario). | Ajustes de iOS › letra AX5 › abrir la app sin libros | `mesa-ax5-texto-cortado.png` (mismo efecto) |
| Bajo | Dos salidas en cada paso: «Ir a la biblioteca» arriba y «Empezar sin libros» o «Ahora no» abajo. No se ve cuál es la buena. | Empezar › Paso 2 | — |
| Bajo | Palabras técnicas en el primer contacto: «Markdown», «forma de Calibre», «readwise.io/access_token». | Pasos 1 y 3 | — |
| Bajo | Con la letra más grande, «Empezar» queda fuera de la vista y hay que desplazarse para encontrarlo. | AX5 | — |

**Ideas**
- Que el título crezca con la letra de iOS, con un tope, para no invertir el orden de importancia.
- Dejar una sola salida discreta por paso.
- En el paso 3, un botón «Terminar» claro en vez de solo «Ahora no».

## 2. Mesa

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| **Alto** | Con la letra más grande, **todo se sale por los dos lados**: «GABI/NETE» se parte, la fecha se corta a la derecha y el título y el autor se cortan a la izquierda («on Quijote», «iguel de Cervantes»). | Letra AX5 › Mesa | `mesa-ax5-texto-cortado.png` |
| Medio | «En la mesa» bajo cada portada dice solo «Nuevo · Frank H…», sin título y cortado. Tres libros de Dune parecen el mismo. | Mesa › desplazar | — |
| Medio | Antes de abrir el libro, la Mesa decía «Empezar a leer · Listo para leer» del Quijote, mientras el Diario ya mostraba 3 sesiones «de 19 % a 29 %». Hay que confirmar si en la vida real puede haber sesiones sin avance (con datos de ejemplo). | Datos de ejemplo › Mesa vs. Diario | — |
| Bajo | La comilla «» de «Donde lo dejaste» cuelga fuera del margen. Es a propósito (ME-2), pero en oscuro casi toca la orilla. | Oscuro › Mesa | — |

**Ideas**
- En «En la mesa», poner el título debajo de la portada, no el estado.
- Con letra grande, dejar que «GABINETE» y la fecha se acomoden en dos renglones en vez de salirse.

## 3. Biblioteca (cuadrícula y lista)

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| Medio | **La cifra no cambia con el filtro.** Dice «17 LIBROS» en Series (6 libros) y en «Sin descargar» (0 libros). | Biblioteca › Series o Sin descargar | `biblioteca-filtro-cortado-conteo-fijo.png` |
| Medio | **El filtro elegido queda cortado:** «Sin de…» con su raya verde. La barra no se recorre hasta la opción elegida. | Tocar «Sin descargar» | `biblioteca-filtro-cortado-conteo-fijo.png` |
| Medio | El botón de vista lista o portadas mide **20 × 14 puntos** de área tocable (la regla SB-4 pide 44 × 44). | Ver el elemento «Ver como lista» | — |
| Medio | En «Series» con vista de lista, los libros no van juntos por serie ni en su orden. Dune sale 1, 10, 2, 2.5 al ordenar por autor. | Lista › Series › Autor | — |
| Medio | No se avisa de los **duplicados**: los dos Rayuela salen lado a lado igual, también en Buscar y en «Se completaron solos». | Importar el mismo EPUB dos veces | — |
| Medio | Las portadas reales que no miden 2:3 se salen de su columna. Rayuela mide 118 de ancho contra 104 de las demás y empieza en x = 21 en vez del margen de 28. | Cuadrícula | — |
| Medio | Biblioteca vacía: solo dice «Toca + …». No hay botón «Añadir libros», cuando la Mesa y el Cuaderno vacíos sí lo tienen. Además se ven filtros, «0 LIBROS» y el orden sin nada que ordenar. | Instalar de cero › Biblioteca | — |
| Bajo | «Sin descargar» aparece aunque la biblioteca viva en el iPhone: es un filtro que siempre sale vacío. | — | — |
| Bajo | «BUSCANDO DATOS EN INTERNET…» ocupa dos renglones en el conteo mientras importa. | Importar 73 libros | — |
| Bajo | Índice A–Z: muestra todas las letras aunque no haya libros con ellas y no da respuesta al tocar una letra vacía. | Lista por título | — |
| Bajo | Lo que lee VoiceOver repite el título: «Dune, de Frank Herbert, Dune, Nuevo · Frank Herbert». La pila de una serie lee «, de » vacío. | — | — |
| Bajo | Con 73 libros importados juntos, «Recientes» los ordena por el nombre de archivo (9, 8, 7, 60, 6…). | — | — |

**Ideas**
- Que el conteo diga «6 de 17 libros» con filtro.
- Ocultar los filtros que no aplican.
- En la cuadrícula de Series, mostrar los tomos por orden.
- Marcar los posibles duplicados con un rótulo, como ya hace la Mac.

## 4. Ficha del libro

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| **Alto** | **Datos de otro libro aplicados solos.** «Dune: tomo diez» (serie Dune, tomo 10) recibió portada, sinopsis, año 1965, editorial e ISBN del primer Dune. Aparece en «Se completaron solos», es decir, la app lo dio por seguro. | Importar «Dune: tomo diez» › ficha | `ficha-datos-equivocados-tomo-diez.png` |
| **Alto** | Un EPUB con título vacío se importa como «**a03**» (el nombre del archivo) y **pierde su autor** («Anónimo» pasa a «Autor desconocido», carpeta «Desconocido»). | Importar EPUB sin título | — |
| Medio | Un título de 201 letras ocupa 9 renglones y empuja «Leer» fuera de la pantalla. | Ficha del libro largo | — |
| Medio | Al desplazar, la portada se ve nítida detrás de la barra de estado y de los botones de vidrio, sin el difuminado de iOS. | Ficha › desplazar | `ficha-datos-equivocados-tomo-diez.png` (arriba) |
| Bajo | «Nº 7», «Nº 16» (el número interno de Calibre) no le dice nada a quien lee. | — | — |
| Bajo | La portada dibujada corta al autor: «AUTOR DESCONOCI…». | Ficha de a03 | — |

**Ideas**
- Limitar el título a 3 o 4 renglones con «más».
- No completar solo cuando el título encontrado no coincide exactamente (sobre todo con serie o número distinto).
- Si el título viene vacío, usar el primer encabezado del libro o pedirlo.

## 5. Editar datos (Escribir a mano)

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| **Alto** | **Los campos no dicen qué son.** Con datos llenos se ve «Dune: tomo diez / Frank Herbert / Dune / 10 / Penguin… / 1965 / 9788…». No se sabe cuál es la serie, cuál el número y cuál el año. «Tu biblioteca: Ciencia ficción» tampoco dice que son etiquetas. | Ficha › Editar › Escribir a mano | `editar-datos-campos-sin-nombre.png` |
| Medio | La hoja no tiene título (el sistema de diseño pide «Editar datos»). | Mismo | `editar-datos-campos-sin-nombre.png` |
| Medio | Vocabulario distinto: aquí el estado es «Por leer», en los filtros de la Biblioteca es «Sin empezar» y la Mesa dice «Listo para leer». | — | — |
| Bajo | «Descartar cambios» aparece activo aunque no haya cambios. | — | — |

**Ideas**
- Usar `FieldRow`: el nombre a la izquierda y el valor a la derecha, igual que en Ajustes.

## 6. Elige los datos y Buscar con otros datos

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| **Alto** | «Dune» (1965) aparece como «**Muy probable · Mismo título y autor**» para «Dune: tomo diez». La razón es falsa. | Editar › Buscar datos en internet | `elige-datos-mismo-titulo-falso.png` |
| Medio | El título de la hoja «Buscar con otros datos» queda en «**Buscar…**» entre «Cerrar la búsqueda» y «Buscar». Son dos «Buscar» y uno cortado. | Elige los datos › Buscar con otros datos | `buscar-otros-datos-titulo-cortado.png` |
| Bajo | «Tus datos ahora» y «Encontrados en internet» van en letra del sistema; el resto de la app usa rótulos en versalitas. | — | — |
| Bajo | Para «a03» salen guías de viaje japonesas como «Dudoso». Faltaría un «No encontré nada que se parezca». | — | — |

## 7. Por revisar

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| Medio | Con 60 libros sin datos en internet, el buzón llega a **65** y hay que entrar uno por uno. No existe «Conservar mis datos en todos». | Importar 73 libros | — |
| Bajo | Los títulos largos se cortan en un renglón: «El extraordinario y larguísimo…». | — | — |

**Ideas**
- Una acción en lote («Dejar todos como están») y agrupar por motivo («No los encontré»).

## 8. Serie

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| Bajo | «4 libros» va en letra normal; en la Biblioteca el conteo va en versalitas («17 LIBROS»). | Biblioteca › Dune | — |
| Bajo | La pantalla es solo una lista: no muestra portada ni avance de la serie. «Libro 2.5» funciona bien. | — | — |

## 9. Estantes guardados

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| Medio | Al guardar, el nombre ya trae la búsqueda («Cor») sin seleccionar. Lo que escribes se pega detrás: «**CorCortázar…**». | Buscar «cor» › Guardar estos libros como estante › escribir | — |
| Bajo | La confirmación de «Borrar estante» sale como globo con la flecha apuntando a la lista, no a «Editar». | Estante › Editar › Borrar | — |

## 10. Buscar (pestaña)

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| Medio | **`autor:` con dos palabras no funciona.** «autor:Autora 3» da 21 libros (incluye Autora 6, por el «3» del título); debían ser 9. | Buscar › «autor:Autora 3» | `buscar-autor-operador-falla.png` |
| Medio | Con la letra más grande, el texto de ejemplo del campo no crece, pero los resultados sí. | AX5 › Buscar | — |
| Bajo | El extracto de una nota encontrada muestra el Markdown tal cual: «# Ideas sueltas El cuento…». | Buscar «cor» | — |
| Bajo | VoiceOver dice «Buscar otra vez «X», 1 resultados» (`Components.swift:2809` no usa `counted`). | Leer el código | — |
| Bajo | «BÚSQUEDAS RECIENTES», «LIBROS» y «ABIERTOS HACE POCO» van en Cinzel; «BUSCA EN TU GABINETE» y «SIN RESULTADOS PARA…» van en versalitas del sistema. Hay dos estilos de rótulo en la misma pantalla. | — | — |

El vacío y el «sin resultados» se ven bien y explican qué hacer.

## 11. Cuaderno: notas y nota

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| Medio | Un `[[Libro inexistente]]` se ve como enlace verde igual que uno bueno y **no hace nada al tocarlo**. En la lista sale como etiqueta verde «LIBRO INEXISTENTE». Pasa también con «Bestiario» y «Ficciones» en las notas de ejemplo. | Nota › Editar › Escribir › «[[Libro inexistente]]» › Listo › tocar | `nota-enlace-a-libro-inexistente.png` |
| Medio | Al editar se ve el Markdown crudo («# Título», «[[…]]»); al leer, ya formateado. El salto es brusco, y una nota nueva empieza con «#». | Nota nueva | — |
| Bajo | «6 NOTAS · EN NOTAS» suena raro. Arriba de la nota se ve la ruta del archivo («Notas/El silencio en Rulfo.md»). | — | — |
| Bajo | «Editar» abre un menú (Escribir / Borrar nota). En la ficha del libro «Editar» también es un menú, pero con otras opciones. | — | — |

El vacío está bien («Sin notas todavía» + «Nota nueva»).

## 12. Cuaderno: subrayados

Sin problemas graves. El vacío explica cómo subrayar.

**Ideas**
- Agrupar por libro cuando hay muchos subrayados.

## 13. Diario (semana, mes, año) y sesión pasada

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| Medio | El mes dice «**Noviembre De 2026**»: la «De» va con mayúscula. | Diario › Mes | `diario-mes-sin-dias-De-mayuscula.png` |
| Medio | El calendario del mes **no tiene encabezado de días** (L M M J V S D). No se sabe en qué día empieza la semana. | Diario › Mes | `diario-mes-sin-dias-De-mayuscula.png` |
| Medio | Año: el rótulo «LIBROS TERMI…» queda cortado. | Diario › Año | `diario-ano-rotulo-cortado.png` |
| Medio | En la sesión pasada, las barras de etapas no tienen nombre por fila (no se ve cuál es Inmersa o Ligera). Arriba sale una marquita gris suelta, y el título del libro se repite dos veces. | Diario › tocar una sesión | — |
| Medio | Con la letra más grande, «1 h 29 min» (la cifra principal) queda pequeña y el resto enorme. | AX5 › Diario | — |
| Bajo | «MMXXVI» en números romanos para el año: bonito, pero cuesta leerlo. | — | — |
| Bajo | La leyenda «Interrumpida» casi no se ve, incluso con Aumentar contraste. | — | — |
| Bajo | Los nombres de libro en las filas se cortan («Don Quijote de la Manc…») aunque sobra espacio. | — | — |
| Bajo | Lo que lee VoiceOver en la gráfica usa fechas en orden inglés: «De nov 25, 2026, 9:10:00 p.m.». | — | — |

## 14. Sesión: «Escribir sobre ella»

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| **Alto** | **Promete escribir y no te deja.** Crea una nota en silencio y muestra un aviso «Nota — Se creó la nota…» con un único botón, «Volver al diario». No abre la nota para escribir. | Diario › sesión › Escribir sobre ella | `sesion-escribir-no-abre-nota.png` |
| **Alto** | Al tocarlo **dos veces se crean dos notas iguales**. | Repetir el toque | `cuaderno-notas-duplicadas.png` |
| Bajo | El título del aviso, «Nota», es genérico. | — | — |

**Ideas**
- Abrir la nota recién creada en modo escribir.
- Si ya existe la nota de esa sesión, abrirla en vez de duplicarla.

## 15. Ajustes y sus tarjetas

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| **Alto** | Con la letra más grande, la hoja entera **se corre a la izquierda y se corta** («es», «ARIENCIA», «CTURA», «ntador»). | AX5 › Cuaderno › ⚙︎ | `ajustes-ax5-desbordado.png` |
| Medio | Al desplazar, el botón flotante «Listo» **tapa filas** («Agregar» de la clave de Google, «Fuente»). Falta el difuminado arriba. | Ajustes › desplazar al final | `ajustes-listo-tapa-filas.png` |
| Medio | «Ordenar la biblioteca» mueve carpetas en el disco **sin pedir confirmación** y sin decir antes qué va a hacer. | Ajustes › Ordenar la biblioteca | — |
| Medio | «Clave de Google Books»: solo se activa tocando la palabra «Agregar» a la derecha; tocar el nombre no hace nada. | — | — |
| Bajo | «Fuente — Open Library» parece una opción para elegir, pero no hace nada al tocarla. | — | — |
| Bajo | Mientras se mueve el Gabinete solo aparece un indicador de carga chiquito. «Mover a iCloud…» sigue activo. | Demo `-screenshot.cabinet moving` | — |

**Traer de Calibre**
- Medio: texto muy técnico («metadata.db», «metadata.opf», «Restaurar base de datos»).
- Bajo: el botón principal no va a todo lo ancho, como en la Bienvenida.

**Reglas**
- Bien: se agrega la regla y aparece «Aplicar a toda la biblioteca».
- Bajo: no hay estado vacío que explique para qué sirven.

**Conexiones (Readwise y Hardcover)**
- Bien: el error está claro («No se pudo conectar · La llave no funciona…»).
- Bajo: «readwise.io/access_token» no se puede tocar como enlace.
- Bajo: tras el error, el campo de la llave aparece vacío.

## 16. Lector: páginas y continuo

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| **Alto** | **Los botones de arriba (cerrar y marcador) tapan el primer renglón** en toda página que no empieza con un título de capítulo. En continuo también tapan el texto al abrir. | Abrir libro › pasar a la página 2 con los controles visibles | `lector-botones-tapan-texto.png`, `lector-oscuro-sigue-claro.png` |
| **Alto** | Con un título largo, la tarjeta de abajo pone el título en **13 renglones de versalitas** y cubre media página. | Abrir el libro de 201 letras | `lector-titulo-largo-tarjeta-gigante.png` |
| **Alto** | Con la letra más grande, la tarjeta queda inservible: «DON QUIJOT/E DE LA/MANCH/A», el botón «Aa» se vuelve «…» y «Pág. 1…», «21 p…» se cortan. | AX5 › abrir libro | `lector-ax5-tarjeta-rota.png` |
| Medio | Con el iPhone en oscuro, el lector abre en «Papel» (claro, brillante). El tema por omisión no es «Auto». | iOS oscuro › abrir libro | `lector-oscuro-sigue-claro.png` |
| Medio | El título árabe en la tarjeta lleva espaciado de versalitas, que **separa las letras árabes** (se rompen sus uniones). | Abrir «ألف ليلة وليلة» | `lector-arabe-titulo-espaciado.png` |
| Medio (a verificar) | Tras pasar a la página 2, el pie sigue diciendo «Pág. 1 de 17». | Tocar a la derecha › ver el pie | `lector-botones-tapan-texto.png` |
| Bajo | En el globo del pie, «Menos de 1 min para el…» queda cortado. | Tocar el pie | — |

**Ideas**
- En páginas, dejar arriba el mismo aire que ocupan los botones, o poner la franja de papel también en páginas.
- En la tarjeta, poner el título en un renglón con «…».

## 17. Lector: Índice, Buscar y Marcas

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| Bajo | En «Marcas» solo hay «Subrayados»; los marcadores no aparecen como sección aunque los haya. | — | — |

La búsqueda funciona bien: «30 resultados en 10 capítulos» y «Aquí vas · pág. 1».

## 18. Lector: «Aa» (Apariencia)

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| **Alto** | Con la letra más grande, las opciones se rompen: «Ne…», «Pági/nas», «Con/tin-/uo», «Des…», «Fun…». | AX5 › Aa | `aa-ax5-opciones-cortadas.png` |
| Bajo | «Clásica y compa…» queda cortado. | Aa | — |
| Bajo | «Noche cálida al atardecer» se ve verde claro, como desactivado, sin explicar por qué. | Aa | — |

## 19. Lector: barra de selección, Consultar, Hendidura, Renglón y Sesión

**Problemas**

| Sev. | Qué pasa | Pasos | Captura |
|---|---|---|---|
| **Alto** | Con la letra más grande, la barra de selección dice «Su…», «C…», «N…», «A…», «Co…». | AX5 › demo `selection` | — |
| Medio | **Hendidura:** el título del capítulo se pega a la primera frase («Capítulo primero En un lugar»; por palabra, «primero En un lugar»). | Demo `slit` / `slitWord` | — |
| Bajo | «A una nota» es ambiguo junto a «Nota». | — | — |
| Bajo | **Renglón:** se ve un cuadrito gris en la orilla izquierda, a la altura del renglón activo. | Demo `guide` | — |

«Consultar» (Wikipedia «hidalgo») y la tarjeta «Esta sesión» (0:07) se ven bien.

---

## Cosas que se repiten (conviene una regla por cada una)

1. **Letra grande de iOS (AX5).** Las pantallas de pestaña, Ajustes y el lector se salen o se cortan. Los títulos de pantalla no crecen mientras el resto sí. Hace falta una prueba de diseño que revise cada pantalla a AX5.
2. **Títulos largos sin tope de renglones.** Pasa en la tarjeta del lector, la ficha y el editor.
3. **Autocompletar con poca certeza:** la app aplica sola datos de otro libro.
4. **Rótulos en dos estilos** (Cinzel vs. versalitas del sistema) dentro de la misma pantalla.
5. **Los conteos ignoran el filtro.**
6. **Estado del libro con tres nombres:** «Por leer», «Sin empezar» y «Listo para leer».
