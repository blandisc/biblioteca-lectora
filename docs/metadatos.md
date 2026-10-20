# Datos de los libros desde internet

Cómo Lectora completa y corrige los datos de un libro (código en
`Packages/LectoraCore/Sources/LectoraCore/Lookup/`).

## Fuentes

- **Open Library**: la fuente principal, sin clave. Se pide la búsqueda general
  (`q`) con `lang=<código de dos letras>`. Así, a cada obra la acompaña la
  edición en el idioma del libro: «Fundación» encuentra la obra «Foundation» y
  trae la edición de Plaza & Janés.
- **Google Books**: solo con una clave propia (Ajustes › Datos de los libros).
  Sin clave, la cuota diaria compartida está agotada casi siempre (lo confirmó
  el sondeo).

## Orden de búsqueda

1. Si el libro tiene un ISBN válido (con dígito de control), se busca la obra
   que contiene esa edición.
2. Título y autor.
3. Solo el título, por si el autor del archivo está mal.

Se detiene en cuanto hay un candidato seguro. Al final se pide la sinopsis de
la obra del mejor candidato.

## Cuándo se aplica solo

Se aplica sin preguntar cuando se cumplen las tres condiciones:

- la confianza es al menos 0.85;
- el título y el autor son seguros, o el ISBN es el mismo y el título cuadra;
- ningún otro libro *distinto* tiene una confianza casi igual. Otra edición o
  un duplicado del mismo libro no cuentan.

En cualquier otro caso, el libro va a **Por revisar** con los candidatos. Si no
hubo internet, el libro queda pendiente (no va a revisar) y se vuelve a buscar
al abrir la app.

Al aplicarse solo, se **llenan únicamente los campos vacíos**. Lo que trae el
archivo y lo que escribiste no se toca. La editorial y el ISBN solo se toman de
una edición en tu idioma. La sinopsis solo se pone si está en el idioma del libro.

Si eliges un candidato en Por revisar, sus datos reemplazan a los tuyos. Antes
de aplicarlo ves la vista previa campo por campo y decides si usar también su
portada. Tu forma de escribir el título y el autor se conserva si es el mismo
texto (tu versión con acentos no se cambia por una sin acentos).

## Limpieza

- **Géneros:** las materias de Open Library (en varios idiomas, con basura como
  «Accessible book») se convierten en pocos géneros en español, por votos
  (`GenreMap`).
- **Sinopsis:** sin HTML, enlaces ni Markdown.
- **Títulos:** sin «- 1. ed.», sin MAYÚSCULAS y con la serie en su campo
  («Juego de tronos (Canción de hielo y fuego 1)»).
- **Autores en otro alfabeto:** «Лев Толстой» se cambia por su forma latina si
  Open Library la conoce. Si no, el autor no se da por distinto: se pregunta.
- **Portadas:** se verifican (que exista, que sea vertical y que no sea
  miniatura) y hay alternativas por si la primera falla.

## Sondeo

`scripts/sondeo/corpus.json` tiene 46 libros difíciles: ediciones en español,
apellidos dobles, títulos sucios, un ISBN falso, un libro inexistente y un
autor equivocado. Con cada cambio a la búsqueda, la CI (`sondeo.yml`) corre la
búsqueda real de la app contra Open Library y publica un informe en la rama
`sondeo`. Escribe `[crudo]` en el mensaje del commit para guardar también las
respuestas crudas, que sirven para escribir pruebas
(`Tests/LectoraCoreTests/Fixtures`).
