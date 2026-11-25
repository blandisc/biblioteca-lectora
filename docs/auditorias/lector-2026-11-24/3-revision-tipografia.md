# Revisión adversarial · Tipografía, espacios, retícula y contraste del lector de Gabinete

Revisor: tipografía y retícula. Fecha: 24 nov 2026.
Material: el informe `/tmp/gab-ux/informe.md`, las 15 capturas (1206 × 2622 px = 402 × 874 pt a 3×) y el código del worktree `gabinete-continuacion-verificacion-7f1ee5`. No compilé ni abrí simuladores.

**Cómo medí.**
- Rehice cada medida con mis propios scripts en `/tmp/gab-ux/trabajo-revision-tipo/` (`medir.py`, `xh.py`, `palabras.py`, `huecos.py`, `filas.py`, `vidrio.py`, `vidrio2.py`, `contraste.py`). No usé los del autor.
- Toda medida va en px de la captura y en pt (px ÷ 3).
- Para saber el tamaño real de la letra comparé las medidas de las letras con la fuente New York del sistema (`/System/Library/Fonts/NewYork.ttf`), que es la que usa el lector por omisión (`ReaderFont.newYork`, pila `ui-serif, 'New York'…`).

---

## Resumen en cinco líneas

1. El informe mide bien casi todo: márgenes, huecos de la tarjeta, contraste de la paleta y huecos entre palabras coinciden con mis medidas a ±1 pt.
2. **Pero se equivoca en la causa del hallazgo más importante (H4).** La letra no mide 14 pt: mide **≈16 pt**. Lo que está mal es el **interlineado** (el aire entre renglones): la app pide 1,5 y en pantalla sale **1,3**, porque el CSS del libro le gana al de la app. Es más grave de lo que dice el informe y se arregla distinto.
3. **La causa de los «ríos» (H5) también está mal.** No vienen del límite de 2 guiones seguidos. Vienen de renglones que empiezan con nombres propios, y WebKit (el motor que dibuja el libro) no parte palabras con mayúscula. Subir el límite a 3 no cambiaría nada en esta página.
4. **El margen de 28 pt del texto es una casualidad.** No sale del token `gutter`: foliate (la librería que pagina el libro) lo calcula como 7 % del ancho de la pantalla. En otro iPhone cambia. Eso afecta H7 y H22.
5. Varias recomendaciones chocan entre sí o con las reglas de la casa:
   - H13 añade ~48 pt a la hoja «Aa» que H11 dice que ya es muy alta.
   - H8 junta la barra y la página, mientras H12 agranda el área de toque de esa misma barra.
   - H7 y H13 proponen 12 pt, que no está en la escala de la casa (SB-2: 4·8·16·24·32·48·64).

**Cuenta.** De lo que me toca:
- 11 hallazgos CONFIRMADOS.
- 8 PARCIALES.
- 0 refutados como hallazgo completo, pero sí 3 afirmaciones dentro de ellos (la letra de 14 pt, la causa de los ríos y «los botones tapan renglones» en «Aa»).

---

## Medidas de base del informe

| Medida del informe | Mi medida | Veredicto |
|---|---|---|
| Capítulo arriba y 77,0–88,3 pt | px 232–265 → 77,3–88,3 pt (captura 02) | CONFIRMADO |
| Primer renglón en y 106,3 | px 319 → 106,3 pt | CONFIRMADO |
| Último renglón termina en 787,3 | px 2362 → 787,3 pt (con el rabo de la «p») | CONFIRMADO |
| Pie 835,0–846,3 | px 2505–2539 → 835,0–846,3 | CONFIRMADO |
| Margen 28,3 / 28,7 | tinta de x 84 a 1121 px → **28,0 / 28,0 pt** | CONFIRMADO (es aún más simétrico) |
| Paso entre renglones 21,0 pt | 33 renglones de px 319 a 2317 → 62,44 px = **20,8 pt** | PARCIAL: la diferencia de 0,2 pt importa, ver H4 |
| Altura de la «x» 7,7–8,0 | banda densa px 706–729 → 23–24 px = **7,7–8,0 pt** | CONFIRMADO |
| Vidrio a 16 pt de la orilla | borde en x 46–48 px y en 1158 px → 16,0 pt por lado | CONFIRMADO |
| Borde de abajo de la tarjeta 839,3 | px 2518 → 839,3 pt (34,7 pt sobre la orilla) | CONFIRMADO |

---

## Veredicto por hallazgo

### H4 · «La letra por omisión es chica» → **PARCIAL**. La medida y la causa están mal, y el problema real es más grave.

**Qué medí.**
- **El tamaño real es ≈16 pt, no 14.**
  - La altura de la «x» es 7,7 pt. En New York la «x» mide 0,488 de la letra completa, así que 7,7 ÷ 0,488 = 15,7 pt.
  - La «l» y la «f» suben 11,8 pt sobre la línea base (px 695–730). En New York suben 0,726 de la letra: 11,8 ÷ 0,726 = 16,2 pt.
  - Comparé cinco palabras del primer renglón con New York dibujada a 14, 15, 16, 17 y 18 pt:

    | Palabra | En la captura | A 16 pt | A 14 pt |
    |---|---|---|---|
    | «capítulo» | 177 px | 180 px | 159 px |
    | «catedralicio,» | 267 px | 274 px | 239 px |
    | «menos» | 148 px | 151 px | 132 px |
    | «otras» | 111 px | 115 px | 100 px |
    | «cinco» | 116 px | 120 px | 105 px |

  - Todo cae en **15,6–16 pt**, que es el 100 % de WebKit (`reader.js:80`: `html { font-size: ${fontScale*100}% }`).
- **El interlineado real es 1,3, no 1,5.** Un paso de 20,8 pt con letra de 16 pt da 20,8 ÷ 16 = **1,30**. El informe supuso que 1,5 se aplicaba y despejó una letra de 14. Esa cuenta es al revés.
- **Por qué pasa.**
  - `reader.js:89-99` pone `line-height` en `p, li, blockquote, dd` **sin `!important`**, y foliate pega esa hoja de estilo al final del `<head>` (`foliate/paginator.js:1001-1003`).
  - Cualquier regla del libro más específica, como `p.texto { line-height: 1.3 }` o las clases `.calibre…` típicas de los EPUB, le gana.
  - Con el color sí se usó `!important` (`reader.js:30-31`). Con el interlineado y el tamaño no.

**Por qué importa más de lo que dice el informe.**
- El interlineado que decidió la app no llega a la pantalla, y cada libro trae el suyo.
- 1,3 en una columna angosta y justificada se ve apretado y cansa en sesiones largas.
- La regla de la casa 06-R8 pide párrafos con interlineado de ≈160 %. Hoy hay 130 %.

**Sobre la recomendación de 17–18 pt.**
- **Normalizar la base es correcto.** Hoy «1 = el del libro» (`reader.js:16`): un libro con `p { font-size: .85em }` abriría a 13,6 pt.
- **18 pt es mala idea en un iPhone de 402 pt.**
  - Hoy caben 43–50 caracteres por renglón (conté «capítulo catedralicio, y al menos otras cinco» = 45 y «sentidos un lugar aislado, ir allí desde Italia no» = 50).
  - A 18 pt bajaría a ~40–44, por debajo del mínimo de 45 que la tipografía clásica pide para el justificado (y que pide la casa en 06-R10). Habría más ríos, justo lo que H5 quiere evitar.
- **No choca con el control de tamaño.** «Aa» escala de forma relativa: 0,8–1,6 en 9 pasos (`ReaderAppearance.swift:405-406`), y el 1,0 cae en el 3.er paso de 9 (se ve en la captura 12). Pero al subir la base, quien ya eligió 1,3 verá la letra más grande de un día para otro. Hay que reescalar el valor guardado.
- **Lo que el informe no dijo: cuesta renglones.**
  - Hoy caben 33 renglones por página.
  - Con 16 pt e interlineado 1,45: 30.
  - Con 17 pt e interlineado 1,4: 29.
  - Es decir, entre 10 y 15 % más vueltas de hoja. Es una decisión para Fernando, no un ajuste.

**Recomendación corregida.**
1. Forzar el interlineado con `!important` (o con una regla de más peso) en los párrafos: 1,45.
2. Fijar el tamaño base de los párrafos en la app (`p { font-size: 1rem !important }` sobre un `html` fijo), sin pisar lo que el libro hace más chico a propósito (notas, epígrafes).
3. Base de **16 pt** (lo que ya se ve) o 17 pt como máximo. 18 no.

**Severidad.** La subo a **Alta**: afecta todos los libros en cada página.

### H5 · «El justificado abre huecos grandes» → **PARCIAL**. La medida está bien; la causa y la recomendación, no.

**Qué medí** (`huecos.py`, 32 renglones justificados de la captura 02, 203 huecos entre palabras).
- El hueco más chico mide 4,7 pt. Es el espacio natural de New York a 16 pt (0,243 de la letra = 3,9 pt) más el aire propio de cada letra.
- La mediana es 7,7 pt, el 10 % más suelto mide 10,3 y el máximo 12,0 pt (renglón en y 397,7).
- El informe dice 4,7 / 7,7 / 10,7 / 12,3. **Medidas CONFIRMADAS** a ±0,4 pt.

**La causa está mal.** El informe culpa a `-webkit-hyphenate-limit-lines: 2` (`reader.js:97`). Revisé los renglones más sueltos:

| Renglón | Hueco | Palabra que no cupo al final |
|---|---|---|
| y 397,7 «sis», publicó ediciones de obras de César,» | 11,8 pt | «Plauto» (nombre propio) |
| y 418,3 «Plauto y Aristóteles –así como del filósofo» | 10,7 pt | «Marsilio» (nombre propio) |
| y 439,0 «Marsilio Ficino y el carismático predicador» | 10,8 pt | «Girolamo» (nombre propio) |
| y 501,7 «nían relaciones frecuentes con Venecia, no» | 10,9 pt | «sólo» (muy corta para partirse con mínimo de 3 + 2 letras) |

- WebKit **no parte palabras que empiezan con mayúscula**. Los tres primeros renglones sueltos vienen de nombres propios, y en el cuarto la palabra es demasiado corta.
- El renglón anterior al 397,7 terminaba en guion, pero solo uno: el límite de 2 no estaba activo.
- **Subir el límite a 3 no cambia ninguno de estos renglones.**

**El justificado sí está bien.**
- Los guiones en español funcionan: «tradi-ción», «patroci-nado», «sabe-mos», «pue-blo».
- Los libros impresos en español se componen justificados casi siempre.
- La mediana de 7,7 pt es ~1,6 veces el espacio natural. Es aceptable para una columna de 45–50 caracteres. Lo que se ve son 3 renglones sueltos seguidos, no un problema general.
- Apagarlo por omisión, como propone el informe, cambia un defecto puntual por una bandera irregular (el borde derecho dentado) en todos los libros, y rompe la idea «editorial» de la app.

**Recomendación corregida.**
1. Dejar el justificado prendido por omisión.
2. Probar `text-wrap: pretty`, que reparte mejor los renglones de un párrafo (WebKit lo trae en las versiones recientes; hay que comprobarlo en el iPhone).
3. El interruptor «Justificar» en «Aa» es opcional y de baja prioridad.
4. No tocar `limit-lines`.
5. Si se sube la letra (H4), esto empeora. Otra razón para no pasar de 17 pt.

### H7 · «Tres márgenes distintos» → **PARCIAL**. Las medidas están bien, pero la causa raíz se le escapó y la recomendación tiene un costo.

**Qué medí.**
- El vidrio está a 16,0 pt de la orilla.
- El texto de la tarjeta empieza en x 32,0–33,0 pt (captura 07: rótulo 32,7, título 32,3, perilla 32,0, «Pág.» 33,0).
- El contenido de «Aa» empieza en 31,7 pt: la hoja nace en x 23 px = 7,7 pt y tiene 24 pt de aire interior.
- El texto del libro empieza en 28,0 pt.

**Lo que no vio.** El 28 del texto **no es el `gutter`**.
- En Páginas, foliate deja un margen de `--_gap: 7%` del ancho (`foliate/paginator.js:471` y `:482-487`): 0,07 × 402 = 28,1 pt.
- En un iPhone Pro Max (440 pt) sería 30,8; en un iPhone de 375 pt, 26,3.
- Alinear la tarjeta a 28 solo funcionaría en este modelo.

**Sobre la recomendación (`chromeInset` de 16 a 12).**
- Pega el vidrio a 12 pt de la orilla, menos de lo que usa iOS 26 en sus barras flotantes.
- La tarjeta queda más cerca de las esquinas curvas de la pantalla, que en este iPhone tienen un radio mucho mayor que los 28 pt de la tarjeta, y se nota más que las esquinas no son concéntricas (es decir, que la curva de la tarjeta no sigue a la de la pantalla).
- Mueve también los botones de arriba, la barra de selección y la tarjeta de subrayado, que no tienen el problema.
- 12 no está en la escala de la casa (SB-2).

**Alternativa mejor**, para que Fernando decida:
- **A (mi recomendación).** El vidrio se queda a 16. El aire interior horizontal de la tarjeta pasa de 16 a 12 (`Space.m`, que ya existe), así que el contenido cae en 28. El margen del texto del libro se fija en **28 pt en los dos modos y en todo iPhone**, mandándolo desde la app en vez del 7 %. El radio interior concéntrico pasa a 28 − 12 = 16. Respeta la decisión escrita «gutter 28 en toda pantalla» (`sistema-diseno.md:58` y `:223`).
- **B.** Todo a 32: el texto del libro con margen de 32, igual al contenido de la tarjeta, y ningún cambio en el vidrio. Todo cae en la escala de la casa, pero pierde ~1 carácter por renglón y rompe la regla del `gutter` 28.

### H8 · Ritmo vertical de la tarjeta → **PARCIAL**. Las medidas están bien; dos recomendaciones fallan.

**Qué medí** (captura 07).
- Del borde de arriba a «CAPÍTULO 1»: 27,3 pt (el vidrio empieza en px 2067 = 689,0; el rótulo en 716,3).
- Del título a la perilla: 751,7 → 761,0 = **9,3 pt**.
- De la perilla a «Pág.»: 774,7 → 800,7 = **26,0 pt**.
- De «Pág.» al borde: 812,7 → 839,3 = **26,6 pt**.
- Todo coincide con el informe.

**Reconstrucción con el código** (suma exacta: 151 pt = 840 − 689):

| Pieza | Alto |
|---|---|
| Rayita | 24 |
| Botón del capítulo | ~39 |
| Barra | 32 |
| Fila de la página | 44 |
| Aire de abajo | 12 |

Los 26 pt alrededor de «Pág.» salen de centrar 12 pt de letra en una fila de 44: unos 16 pt de aire invisible arriba y abajo.

**Tarjeta subida** (captura 10).
- Del mosaico a su leyenda: 719,0 → 725,7 = **6,7 pt**. De la leyenda al mosaico siguiente: 736,7 → 746,0 = **9,3 pt**.
- De «Porcentaje» al borde: 827,3 → 839,7 = **12,4 pt** (el informe dice 11,4).
- Hueco con la línea fina: de «Pág.» a «EL PIE DICE», 42,7 pt.
- Todo CONFIRMADO.

**Dónde falla la recomendación.**
1. **«Del mosaico a su leyenda, 4 pt»: ya son 4 en el código** (`Components.swift:1329`, `VStack(spacing: Theme.Space.xs)`). Los 6,7 que se ven son el aire propio del renglón de la leyenda. Lo que hay que cambiar es el otro lado: el espacio entre filas del `Grid`, de 8 a 16 (`ReaderView.swift:574`).
2. **«Interior de abajo, 24 pt en los dos estados»** dejaría la tarjeta bajada con ~38 pt bajo «Pág.» (12 de más sobre los 26,6 de hoy). El problema es la diferencia entre estados (26,6 bajada contra 12,4 subida), no un número. Corrección: aire de abajo de 16 a 24 **solo cuando está subida**, o quitar el aire invisible de la fila (siguiente punto) y usar 16 en los dos.
3. **«Barra a página 8 pt con `padding(.vertical, -8)`»** choca con H12. Si la barra pasa a 44 pt de área de toque y la fila de 44 se sube 8 pt, las dos áreas se enciman en la esquina derecha, donde «188 palabras ›» es un botón. Solución sin choque:
   - «Pág. 27 de 842» es texto que no se toca.
   - Que la fila se alinee arriba (`alignment: .top`) en lugar de centrada: el texto sube junto a la barra.
   - El área de 44 del botón «palabras» crece hacia abajo, sobre el aire libre.

### H9 · «El texto queda alto» → **PARCIAL**. Las medidas están bien; la causa está a medias y el beneficio depende del tamaño de letra.

**Qué medí.**
- Del capítulo al texto: 88,3 → 106,3 = 18,0 pt.
- Del texto al pie: 787,3 → 835,0 = 47,7 pt.
- CONFIRMADO.

**Cuenta exacta.**
- La caja del texto va de 102 pt (62 de área segura + 40 de `pageMarginTop`) a 806 pt (874 − 68): son 704 pt.
- Caben 704 ÷ 20,8 = 33,8 renglones, o sea 33.
- Sobran **17,6 pt** abajo porque foliate no reparte el sobrante.

Así que la mitad del desequilibrio no es el margen, sino la fracción de renglón que no cabe. Bajar `pageMarginBottom` a 56 da un renglón más con 20,8 pt de paso, pero con otro tamaño o interlineado (sobre todo si se arregla H4) el sobrante cambia y puede volver a quedar alto.

**Recomendación corregida.** Hacer el cambio a 56 solo junto con H4 y volver a medir. Mejor todavía: que el lector reparta el sobrante, por ejemplo calculando el margen de arriba como 40 + sobrante ÷ 2.

### H11 · «La hoja "Aa" tapa dos tercios» → **PARCIAL**

- **Tamaño de la hoja.** Empieza en y ≈ 300–313 pt (captura 12; a 300 en el centro, 313 donde su esquina curva) y cubre el **64 %** de la pantalla. En Continuo empieza en 379 pt (57 %). CONFIRMADO.
- **REFUTADO:** «los botones de arriba tapan los primeros renglones». En Páginas los botones terminan en 97,7 pt y el texto empieza en 106,3. No se enciman. Quedan ~9 renglones visibles (de 106 a 300 pt).
- **El «Aa» repetido** arriba con la hoja abierta sí es real.
- **Esconder controles** al abrir «Aa»: razonable.
- **«Dos altos (medio y completo)»** contradice cómo está hecha hoy la hoja: mide exactamente su contenido, sin espacio muerto (`ReaderAppearance.swift:230-241`). Es decisión de Fernando, no un arreglo.
- **Contradicción interna del informe:** H13 propone huecos de 32 entre secciones, que suman ~48 pt a esta misma hoja.

### H12 · Toques por debajo de 44 pt → **CONFIRMADO**, con matices de severidad

- **«A» chica y «A» grande** (`ReaderAppearance.swift:394,398`): son `Text` sin marco. La chica ocupa x 31–38 pt y ~9 pt de alto de tinta (captura 12). Es el peor caso.
  - Ojo con el arreglo `frame(minWidth: 44)`: le quita ~70 pt de ancho a la barra de tamaño, que tiene 9 marcas.
  - Mejor: marco de 44 × 44 y `spacing: 0` en el `HStack`. La barra pierde ~48 pt.
- **Barra de avance:** 32 pt (`Theme.swift:146`). CONFIRMADO.
- **Botón del capítulo:** ~39 pt de alto según la suma de arriba. CONFIRMADO.
- **Rayita:** 24 pt de alto por todo el ancho (`ReaderView.swift:518`). Real, pero baja: toda la tarjeta acepta el gesto de subir y bajar (`ReaderView.swift:627-633`), así que la rayita es un atajo extra.

### H13 · Aire de «Aa» → **CONFIRMADO** el hallazgo; la recomendación no es proporcional

**Qué medí** (captura 12; mis números difieren 1–3 pt de los del informe porque mido tinta con otro umbral).
- Entre secciones: de la barra de tamaño a «PÁGINA», 19,3–22 pt; de los estilos de hoja a «FONDO», 19,0 pt.
- Dentro de una sección:
  - Del rótulo al contenido: 12,7–13,4 pt.
  - De las leyendas de fondo al primer interruptor: 19,0 pt.
  - Entre los dos interruptores: 18,0 pt.

La conclusión se sostiene: el aire entre secciones (~19–22) es casi igual al que hay dentro de una (~18–19).

**La recomendación (8 / 12 / 32) tiene dos problemas.**
- 32 entre 3 secciones suma ~48 pt de alto y agrava H11.
- 12 no está en la escala de la casa.

**Corrección.** Entre secciones 24 (`Space.xl`, +8 por sección), rótulo a contenido 8 y entre elementos 8.

### Contraste («Lo que ya está bien»: «todos pasan 4,5 : 1») → **PARCIAL**

- **Paleta: CONFIRMADO.** Rehice las cuentas (`contraste.py`):

  | Fondo | Cuerpo | Folio al 74 % |
  |---|---|---|
  | Papel | 16,1 | 7,1 |
  | Blanco | 17,2 | 7,3 |
  | Noche cálida | 11,0 | 6,7 |
  | Negro | 10,6 | 6,0 |

- **Se le pasó el quinto fondo.** Con «Auto» en modo oscuro (#161514 con #DAD6CE) el cuerpo da 12,6 : 1. Pasa.
- **Sobre el vidrio no hay holgura** (`vidrio.py`, `vidrio2.py`, píxeles reales). El vidrio se aclara con el texto que tiene detrás:

  | Texto | Captura | Contraste |
  |---|---|---|
  | «Pág. 27» | 07 | 5,4 |
  | «Pág. 27» | 09 (Continuo) | **4,5** |
  | «Pág. 27» | 10 (subida) | **4,5** |
  | «CAPÍTULO 1» (Cinzel 12 pt) | 07 | **4,5** |
  | «EL PIE DICE» | 10 | **4,5** |
  | Leyendas de los mosaicos | 10 | 5,5 |

  Los textos de 72 % de tinta (`Emphasis.glassText`) quedan justo en el límite en Noche cálida, y es letra chica.
- **«Calculando…»** (pie sin dato, 55 %) da 3,8 : 1 en papel y 4,4 en noche. Como la opción está desactivada, WCAG lo permite, pero es información que conviene leer.
- **Riel de la barra de avance:** 1,8 : 1 sobre el vidrio (px de luminancia 116 contra 78). Los controles piden 3 : 1 (WCAG 1.4.11). La perilla sí se ve bien.

**Recomendación.** Subir `glassText` a ~0,8 en temas oscuros. Comprobarlo sobre Continuo, donde el vidrio cae sobre texto denso.

### Hallazgos menores de mi foco

| Hallazgo | Veredicto | Evidencia |
|---|---|---|
| H18 · tinta neutra en la tarjeta | CONFIRMADO | Título de la tarjeta (236, 233, 226) contra el texto del libro (232, 217, 196) en la captura 07. |
| H19 · la muestra dice distinto que el pie | CONFIRMADO | `ReaderView.swift:316` cambia «para terminar» por «para» solo en la muestra. |
| H20 · «Pág.» contra «Página» | CONFIRMADO, baja | La abreviatura en la tarjeta es defendible por espacio. |
| H21 · lomo con quiebre | CONFIRMADO, baja | Fila de px 150 en la captura 01: de 26 a 38 de luminancia en línea recta hasta x ≈ 78 px (26 pt), luego plano. Muy sutil. |
| H22 · margen distinto entre modos | CONFIRMADO, y encontré la causa exacta | Páginas usa 7 % del ancho (28,1 pt); Continuo usa `g/(1−g)` = 7,53 % (`foliate/paginator.js:700-718`) = 30,3 pt, igual a lo medido. Arreglo: el mismo margen fijo en pt en los dos modos (ver H7, opción A). |
| H23 · tokens del lector fuera de la escala | CONFIRMADO | Ojo: el propio informe propone más valores fuera de escala (12 en H7 y H13, 56 en H9). |
| H24.1 · interruptor sin explicación | CONFIRMADO | |
| H24.2 · estilos de hoja iguales | CONFIRMADO | Los 4 íconos son idénticos en la captura 12. |
| H24.3 · «Sin animación» al ras | CONFIRMADO | La leyenda casi toca las orillas de su mosaico. |
| H24.5 · un espacio usado como tamaño de letra | CONFIRMADO | `ReaderAppearance.swift:309`. |
| H24.4 · «demasiado verde» | PARCIAL | Es gusto. Que los interruptores tomen el color de acento es lo normal en iOS. |

**Fuera de mi foco.** H2 (el pie se dibuja fuera del vidrio) es real por código: no hay `clipShape` en `ReaderView.swift:604-608` y la transición es `.move(edge: .bottom)` en `:594`. La recomendación es correcta.

---

## Lo que el informe omitió

1. **El interlineado decidido no se aplica.** Detalle en H4. Es el hallazgo tipográfico más grande de la pantalla y rompe 06-R8.
2. **El margen del texto depende del modelo de iPhone.** Detalle en H7 y H22. Ninguna alineación con la tarjeta se sostiene hasta fijarlo en pt.
3. **Tamaño de texto de iOS (Dynamic Type).**
   - Ni el libro ni las piezas fijas lo consideran: no hay ninguna referencia a `dynamicTypeSize` ni a `UIFontMetrics` en `App/`.
   - Quien tiene la letra grande en su iPhone abre el libro a 16 pt.
   - Con letra grande, los mosaicos del pie (alto fijo de 64 pt, `Components.swift:1347`) y las filas de una sola línea de la tarjeta se cortan.
   - No lo verifiqué en captura: queda como riesgo, con código como evidencia.
4. **El vidrio queda justo en 4,5 : 1** en Noche cálida, y el riel de la barra en 1,8 : 1 (ver Contraste).
5. **Una recomendación choca con otra:** H8 contra H12 (área de la barra) y H13 contra H11 (alto de «Aa»).
6. **El capítulo se escribe con dos letras distintas.** En el pie superior va en SF (`ReaderView.swift:749`, `.caption`) y en la tarjeta en New York (`.rowTitle`). Si la regla es «New York para lo del libro», el título del capítulo es del libro. Baja.
7. **Viudas sí, huérfanas no.** El CSS controla las viudas (`widows: 2`), pero no las huérfanas (`orphans`). Viuda: el último renglón de un párrafo que queda solo al principio de una página. Huérfana: el primer renglón de un párrafo que queda solo al final de una página. Baja, una línea de CSS.

---

## Mi top 5 corregido

1. **Que el interlineado y el tamaño que decide la app se apliquen de verdad** (H4 corregido).
   - Interlineado de 1,45 forzado en los párrafos y base fija de 16 pt (17 como máximo, no 18).
   - Hoy sale 1,3 y cambia con cada libro.
   - Fernando decide entre aire y renglones por página: 33 hoy, 30 con 16 pt y 1,45.
2. **Un solo margen de texto en pt, igual en Páginas y Continuo y en todo iPhone, y la tarjeta alineada a él** (H7 + H22, opción A).
   - El texto del libro a 28 fijo, el vidrio a 16 y el interior de la tarjeta a 12.
   - Quita el «casi alineado» y el salto de columna al cambiar de modo.
3. **Ritmo y toques de la tarjeta resueltos juntos** (H8 + H12 + H2).
   - Recortar el contenido al vidrio.
   - Barra con área de 44.
   - «Pág.» alineada arriba de su fila, sin enciman áreas.
   - 16 pt entre filas de mosaicos.
   - Aire de abajo parejo entre bajada y subida.
   - `glassText` a ~0,8 en oscuro.
4. **«Aa» más corta y más clara** (H11 + H13 + H12).
   - Esconder los botones de arriba al abrirla.
   - Secciones separadas por 24 y elementos por 8, para que el alto no crezca.
   - «A» chica y «A» grande con área de 44.
5. **Justificado: mejorarlo, no apagarlo** (H5 corregido).
   - Mantenerlo por omisión.
   - Probar `text-wrap: pretty` en el iPhone.
   - Olvidar `limit-lines`.
   - Revisar cómo queda después del punto 1. Dejar «Justificar» en «Aa» como opción secundaria.

---

### Archivos de esta revisión

- Scripts y medidas en `/tmp/gab-ux/trabajo-revision-tipo/`, temporales; se pueden borrar al cerrar la revisión.
- No toqué el repo ni el trabajo del autor.
