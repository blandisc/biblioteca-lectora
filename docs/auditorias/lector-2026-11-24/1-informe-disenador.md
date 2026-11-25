# Gabinete · Pantalla de lectura: análisis de armonía, tipografía, interacción y movimiento

Fecha: 24 nov 2026 · Material: `/tmp/gab-ux/` (15 capturas, 5 videos) y el código del worktree `gabinete-continuacion-verificacion-7f1ee5` (solo lectura).

**Cómo medí.**
- **Capturas.** Perfil de píxeles por renglón y por columna con un script propio en `/tmp/gab-ux/trabajo/`. Toda medida va en pt (px ÷ 3).
- **Videos.** Saqué *todos* los cuadros reales con su tiempo exacto. El simulador graba un cuadro solo cuando la pantalla cambia, así que un hueco entre cuadros durante una animación es un cuadro que no se pintó.
- **Qué es medida y qué no.** Cuando digo «medí», es medida. Cuando digo «infiero», es interpretación.

**Límites.**
- Es un simulador con compilación de depuración (Debug), no un iPhone. Los tiempos de carga y los cuadros perdidos pueden ser peores aquí que en el teléfono, y hay que confirmarlos en un aparato.
- No puedo sentir el tacto: arrastrar con el dedo, la vibración o la respuesta al soltar una hoja.
- El «asomo» del panel (las primeras 3 veces) no aparece en el video: ya se había gastado.

---

## Resumen ejecutivo

La pantalla de lectura tiene una base sólida y poco común.
- **Lo bueno.** Texto simétrico al píxel, folio centrado exacto, buenos contrastes en los 4 fondos y un sistema de tokens con pruebas. Los cambios evitan con cuidado que se lean dos textos encimados, y «Reducir movimiento» está bien resuelto.
- **Lo que más se siente.** Lo débil no está en la idea, sino en tres cosas:
  1. **Cortes en el movimiento.** La primera vuelta de «Hoja» no se dobla: deja ver papel vacío 0,13 s y la página nueva salta. «El pie dice» se dibuja fuera del vidrio al subir.
  2. **La entrada al libro.** De 4 a 5 s de «Abriendo el libro…», con un pie que dice «0 %» y una tarjeta con «0 palabras».
  3. **Espacios en tres medidas distintas.** Botones a 16 pt, texto del libro a 28 pt y tarjeta a 32 pt, con un ritmo vertical poco jerárquico en la tarjeta y en «Aa».
- **Para quien lee mucho.** La letra por omisión es chica (renglón de 21 pt, estimo unos 14–15 pt). El justificado, en una columna de ~45 caracteres, abre espacios de hasta 12 pt entre palabras.

| Eje | Calificación | En una línea |
|---|---|---|
| Armonía y espacios | **6/10** | Simetría lateral impecable; alineaciones y ritmo vertical sin una sola regla |
| Tipografía | **7/10** | Buena familia y jerarquía; letra base chica y justificado con «ríos» |
| Interacciones | **7/10** | Zonas claras y coherentes con Libros de Apple; varios toques por debajo de 44 pt |
| Animaciones | **6/10** | Curvas bien pensadas en el código; en pantalla hay cortes, cuadros perdidos y una cola lenta al deslizar atrás |
| Consistencia | **6/10** | El sistema existe y se prueba, pero la doc y el código no dicen lo mismo en 4 puntos, y el índice no toma el tema |

---

## Medidas de base (para verificar todo lo demás)

**Leyendo en Páginas** (capturas 01–04: noche, papel, blanco y negro dan las mismas medidas):

| Qué | Medida |
|---|---|
| Capítulo arriba | y 77,0–88,3 pt; centrado en x 110,3–291,7 (centro 201,0; pantalla 201) |
| Primer renglón de texto | empieza en y 106,3 pt |
| Último renglón | termina en y 787,3 pt |
| Pie | y 835,0–846,3 pt; centro x 200,7 |
| Margen del texto | 28,3 pt a la izquierda y 28,7 a la derecha (simétrico) |
| Paso entre renglones | 21,0 pt (de 319 a 382 px) |
| Altura de la «x» | 7,7–8,0 pt |

**Leyendo en Continuo** (capturas 05–06):

| Qué | Medida |
|---|---|
| Capítulo | y 66,3–77,3 pt |
| Margen del texto | 30,3–31,3 pt a cada lado (2–3 pt más que en Páginas) |

**Tarjeta al tocar el centro** (captura 07):

| Qué | Medida |
|---|---|
| Vidrio a los lados | 16 pt de la orilla |
| Borde de abajo | en y ≈ 839,3 pt, es decir 34,7 pt sobre la orilla |
| Textos | empiezan en x 32,3–33,0 pt |

**Botones de arriba:** de y 54,0 a 97,7 pt, o sea 43,7 pt de alto.

---

## Hallazgos

### H1 · La primera vuelta de «Hoja» no se dobla, y a media vuelta se pierden cuadros — **Alta**

- **Estado:** Páginas, estilo Hoja.
- **Qué pasa.** En la primera vuelta tras abrir el libro, el texto desaparece y queda papel liso. No aparece el doblez. Luego la página nueva aparece de golpe. En las vueltas siguientes sí hay doblez, pero con huecos de 75 ms (unos 4 cuadros sin pintar) en la mitad del recorrido.
- **Evidencia:**
  - `videos/hoja.mp4`: t = 11,450 con texto; de t = 11,472 a 11,592 papel vacío (cuadros 11,472 · 11,505 · 11,512 · 11,592); t = 11,597 página nueva completa. Son 0,13 s de página en blanco sin ningún cuadro de doblez.
  - Segunda vuelta: cuadros en 12,317 · 12,340 · 12,343 → **hueco** → 12,418 · 12,442.
  - Tercera vuelta: 13,985 → **hueco** → 14,060.
  - Código: `PageCurl.swift:440-505` (Core Image dobla la foto completa en cada cuadro y crea una imagen nueva con `createCGImage` en el hilo principal); `PageCurl.swift:155-161` (hacia adelante, la hoja se arma sobre papel liso).
- **Por qué importa.** La vuelta de hoja es la animación que más se repite en la app, cientos de veces por libro. Un parpadeo blanco o un salto rompe la ilusión de papel justo en la primera impresión.
- **Infiero la causa** (no puedo comprobarla sin Instruments). Core Image compila sus filtros la primera vez que se usan («arranque en frío»). Además, dibujar a 2× con `createCGImage` en cada cuadro es caro. En el simulador se nota más. En el iPhone puede ser menor, pero hay que medirlo.
- **Recomendación:**
  1. «Calentar» el doblez al abrir el libro: dibujar un cuadro fuera de la pantalla con `MatteCurl.render` en cuanto haya página.
  2. Usar un `CIContext` sobre Metal (la vía rápida de la tarjeta gráfica) y pintar directo en una capa Metal, en vez de crear un `UIImage` por cuadro.
  3. Si sigue habiendo huecos, bajar `curlScale` de 2 a 1,5 solo mientras la hoja se mueve.
  4. Si el doblez no está listo, la hoja debe quedarse quieta, nunca mostrar papel vacío.
  5. Medir en un iPhone con Instruments («Animation Hitches»).

### H2 · «El pie dice» se dibuja fuera del vidrio al subir la tarjeta — **Alta**

- **Estado:** tarjeta subida.
- **Qué pasa.** Mientras la tarjeta crece, los mosaicos del pie entran «desde abajo» y quedan *debajo del borde del vidrio*, flotando sobre la página, durante unos 0,15 s.
- **Evidencia:**
  - `videos/panel.mp4` t = 10,745, 10,792 y 10,843 (recorte `trabajo/p_panel2.png`): en 10,792 el mosaico elegido «Página» y su palomita están bajo el borde del panel; en 10,843 la leyenda «Página» está fuera.
  - Código: `ReaderView.swift:594` usa `.transition(.opacity.combined(with: .move(edge: .bottom)))`, y el panel (`ReaderView.swift:604-608`) no recorta su contenido a su forma.
- **Por qué importa.** Es el único momento en que el «vidrio» deja de parecer un objeto. Se ve como una falla, no como un diseño.
- **Recomendación:**
  - Recortar el contenido a la forma del panel: `.clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))` antes de `.glassPanel`.
  - Cambiar `.move(edge: .bottom)` por `.opacity` con un `offset(y: 8)` (ya existe `Space.s`), como hacen los mosaicos.

### H3 · Al abrir el libro salen controles vacíos y un pie que dice «0 %» — **Media-alta**

- **Estado:** carga del libro.
- **Qué pasa:**
  - **Con controles** (el caso normal). Mientras carga se ven los botones de arriba y la tarjeta con «Agentes del imperio», la barra en cero, «0 %» y «0 palabras». Cuando llega el capítulo, la tarjeta cambia de alto de golpe, en un solo cuadro.
  - **Sin controles.** El pie dice «0 %» durante toda la carga. Al terminar, el «0 %» y la «Página 27» se funden encimados.
- **Evidencia:**
  - `videos/panel.mp4`: t = 4,12–4,43 aparece la tarjeta con «0 %» y «0 palabras» sobre «Abriendo el libro…» (`trabajo/p_panel_s.png`); t = 8,297 cambia de golpe (diferencia de 22 en un cuadro).
  - `videos/hoja.mp4`: t = 3,41–8,49 «0 %» abajo; t = 8,557 los dos pies encimados (secuencia `hoja.png`).
  - Código: `ReaderView.swift:24` (`showsChrome = !LaunchOptions.hidesReaderChrome`: los controles salen visibles por omisión) y `ReaderView.swift:323-326` (sin dato, el pie cae a porcentaje).
- **Por qué importa.** «0 %» en un libro que vas al 3 % se lee como «perdiste tu lugar» (regla 09-R6 de la casa: un número no debe poder malinterpretarse). La entrada al libro marca el tono, la regla del «pico y el final» (15-M6).
- **Recomendación:**
  - Abrir siempre sin controles.
  - No pintar el pie ni la tarjeta hasta que exista `controller.folioLocation`: el folio va con opacidad 0 y entra con `Motion.standard` cuando hay dato.
  - Durante la carga, dejar solo el título del libro arriba y «Abriendo el libro…».

### H4 · La letra por omisión es chica para un iPhone — **Media-alta**

- **Estado:** leyendo, en los dos modos.
- **Qué pasa.** El renglón mide 21,0 pt y el interlineado configurado es 1,5, así que la letra efectiva es de unos 14 pt. Con la altura de la «x» medida (7,7–8,0 pt), estimo entre 14 y 15 pt.
  - Esto pasa porque `fontScale: 1` significa «el tamaño que trae el libro», no un tamaño de la app.
  - Esto es *inferencia*: el libro podría traer otro interlineado. Pero el paso de 21 pt sí está medido.
- **Evidencia:** captura 02, renglones a 106,3 · 127,3 · 148,0 pt…; `reader.js:10` (`lineHeight: 1.5`), `reader.js:16` (`fontScale: 1 // 1 = el del libro`), `reader.js:80`.
- **Por qué importa.** El texto normal de iOS es de 17 pt. A 14–15 pt, quien lee una hora se cansa antes, y cada libro abre con un tamaño distinto según su archivo.
- **Recomendación:**
  - Normalizar la base: fijar el tamaño del cuerpo a 17–18 pt sin importar el libro, con `p { font-size: … }` relativo a un `html` fijo, y dejar que «Aa» escale desde ahí.
  - Con 1,5 de interlineado, el renglón pasa de 21 a unos 26 pt.
  - Hacerlo junto con H5: la columna tendrá menos caracteres.

### H5 · El justificado abre huecos grandes entre palabras — **Media**

- **Estado:** leyendo.
- **Qué pasa.** Con ~43–49 caracteres por renglón y texto justificado (ambos bordes rectos), el espacio entre palabras va de 4,7 pt en el renglón más apretado a 12,3 pt en el más suelto: 2,6 veces. En la pantalla se ven «ríos» blancos.
- **Evidencia:**
  - Captura 02: mediana de 7,7 pt; 10,7 pt en el 10 % más suelto; máximo 12,3 pt (renglón en y = 398 pt).
  - Captura 07: «Plauto  y  Aristóteles  –así  como  del  filósofo».
  - Código: `reader.js:11` (`justify: true`), `reader.js:97` (`-webkit-hyphenate-limit-lines: 2`, que impide más de 2 guiones seguidos y obliga a abrir espacios).
- **Por qué importa.** Los ríos rompen el ritmo del ojo. En una columna angosta, el justificado sin guiones agresivos es el defecto editorial más visible.
- **Recomendación:**
  - Subir `hyphenate-limit-lines` de 2 a 3.
  - Agregar en «Aa» un interruptor «Justificar», como Libros y Kindle. Para iPhone recomiendo que venga apagado (bandera irregular a la derecha con guiones).
  - Si se queda justificado, al subir la letra (H4) la columna tendrá unos 38 caracteres y los ríos crecerán.

### H6 · La carga tarda de 4 a 5 s y la página aparece sin transición — **Media**

- **Estado:** abrir un libro.
- **Qué pasa:**
  - «Abriendo el libro…» dura 5,1 s en `hoja.mp4` (t = 3,41 → 8,49) y 4,3 s en `panel.mp4` (t = 4,0 → 8,3).
  - Luego todo el texto aparece en un solo cuadro (t = 8,49 → 8,557). En cambio, al pasar hoja o al cambiar de modo todo tiene un relevo cuidado.
- **Límite.** Es Debug en el simulador. En un iPhone puede ser mucho menos, y hay que medirlo.
- **Recomendación:**
  - Que la primera página entre con el mismo relevo de `dissolve` (`Reader.flowIn` 0,45 s subiendo `flowRise` 6 pt).
  - Si en el iPhone pasa de 1 s, mostrar la portada o el «Donde lo dejaste» como placeholder: esa frase ya está guardada (`savePosition(... excerpt:)`).

### H7 · Tres márgenes distintos: botones, texto y tarjeta no se alinean — **Media**

- **Estado:** tarjeta y botones sobre la página (capturas 07–11).
- **Qué pasa.** Hay tres líneas verticales que casi coinciden pero no:
  - El vidrio de los botones y de la tarjeta empieza a **16 pt** de la orilla.
  - El texto del libro empieza a **28,3 pt**.
  - El texto de la tarjeta empieza a **32,3–33,0 pt**.
  - El contenido de «Aa» empieza a **31,7 pt** (captura 12).

  El ojo ve el «Capítulo 1» de la tarjeta 4 pt más adentro que el texto que tiene encima.
- **Evidencia:** captura 07: título de la tarjeta en x 32,3; «Pág. 27» en x 33,0; texto del libro en x 28,3. Código: `ReaderView.swift:606` (interior `Space.l` 16) y `:623` (`chromeInset` 16), que suman 32 pt.
- **Por qué importa.** La regla de simetría de la app (`sistema-diseno.md:20`, «gutter» 28 en toda pantalla) se cumple en el texto pero no en los controles. Con tres líneas casi iguales, la pantalla se siente «casi alineada», que es peor que claramente distinta.
- **Recomendación.** Pasar `Reader.chromeInset` de 16 a 12 y el interior de la tarjeta de 16 a 16 (sin cambio): el contenido cae en 28 pt, igual que el texto y el `gutter`.
  - El radio interior concéntrico sigue siendo 28 − 16 = 12 (`Radius.inset`).
  - Los botones de arriba quedan a 12 pt, alineados con el vidrio de abajo.

### H8 · Ritmo vertical de la tarjeta: huecos parecidos donde debería haber jerarquía — **Media**

- **Estado:** tarjeta (07) y tarjeta subida (10–11).
- **Qué pasa (medido en la captura 07):**
  - Del título del capítulo a la perilla: **9,3 pt**.
  - De la perilla a «Pág. 27 de 842»: **26,0 pt**.
  - De «Pág.» al borde de abajo: **26,6 pt**.
  - Arriba, del borde al rótulo «CAPÍTULO 1»: ~27,6 pt.

  La página, que describe a la barra, queda más lejos de ella que el título.
- **Tarjeta subida (captura 10):**
  - De la leyenda «Porcentaje» al borde de abajo: solo **11,4 pt** (827,3 → ≈838,7), con un radio de 28 pt.
  - Dentro hay huecos de **42,7 pt** (de «Pág.» a «EL PIE DICE»). Esto rompe 06-R2: el margen interior de un contenedor debe ser mayor o igual a su hueco más grande.
  - De cada mosaico a su leyenda hay **6,7 pt**, y de la leyenda al mosaico siguiente **9,0 pt**. La leyenda queda casi a la misma distancia de los dos y no queda claro de quién es.
- **Evidencia:** `ReaderView.swift:542-567` (barra de 32 pt + fila de mínimo 44 pt centrada, que mete ~16 pt de aire), `:570-593` (`Space.s` en todo), `:607` (abajo `Space.m` = 12).
- **Recomendación:**
  - De la barra a la página, 8 pt: dejar el toque de 44 pt con `contentShape` y un `padding(.vertical, -Space.s)`, el mismo truco que usa la ✕ en `HighlightCard`.
  - De cada mosaico a su leyenda, 4 pt, y entre filas de mosaicos, 16 pt (`verticalSpacing: Space.l`).
  - Interior de abajo de la tarjeta, 24 pt (`Space.xl`) en los dos estados.
  - Antes de «El pie dice», 24 pt con la línea fina en medio.

### H9 · En Páginas, el texto queda «alto»: poco aire arriba y mucho abajo — **Media**

- **Estado:** leyendo en Páginas.
- **Qué pasa.** Del capítulo al texto hay **18,0 pt** (88,3 → 106,3); del texto al pie, **47,7 pt** (787,3 → 835,0). El bloque de texto parece empujado hacia arriba, y cabe un renglón menos del que cabría.
- **Evidencia:** capturas 01–04; `Theme.swift:311-313` (`pageMarginTop` 40, `pageMarginBottom` 68); `ReaderView.swift:755,780` (el pie va centrado en los 68 pt).
- **Recomendación.** Separar «dónde va el pie» de «dónde termina el texto»:
  - El pie se queda donde está, centrado a 840 pt, lejos de la barra de inicio.
  - El texto puede bajar hasta ~814 pt: `marginBottom` de 68 a unos 56.
  - Resultado: el aire queda ~20 pt arriba y ~20 pt abajo, y cabe **un renglón más por página**.
  - Verificar en un iPhone chico que el pie no toque el texto.

### H10 · En Continuo con controles, el texto corre debajo de los botones — **Media**

- **Estado:** Continuo, tarjeta abierta (captura 09, de y 0 a 100 pt; recorte `trabajo/09-top.png`).
- **Qué pasa.** Al aparecer los controles desaparece la franja de papel del folio. El texto, a toda intensidad, pasa debajo de la barra de estado y de los botones de vidrio: «Gobierno (ayuntamiento) de Ancona» se lee mezclado con 🔍 Aa.
- **Evidencia:** captura 09; `ReaderView.swift:253-263` (el folio con su franja solo existe sin controles); `sistema-diseno.md:85` («Con controles no hay franja ni niebla detrás de los botones de arriba: el vidrio basta»).
- **Por qué importa.** El vidrio basta sobre papel liso (Páginas), pero no sobre texto denso.
- **Recomendación.** Solo en Continuo y con controles: mantener la franja de papel de arriba con su desvanecido (`folioFade` 56 pt, que ya existe).
- **Ojo:** contradice una decisión escrita, así que se la llevaría a Fernando como decisión, no la cambiaría sola.

### H11 · La hoja «Aa» tapa dos tercios y deja otro «Aa» encima del texto — **Media**

- **Estado:** «Aa» (capturas 12–14).
- **Qué pasa:**
  - La hoja empieza en y ≈ 300 pt en Páginas y cubre 64 % de la pantalla. En Continuo empieza en y ≈ 376 pt, porque se quita la fila de estilos de hoja.
  - Encima siguen los botones de arriba, con su propio «Aa», tapando los primeros renglones.
  - Quedan unos 9 renglones a la vista para juzgar un cambio de letra o de tamaño.
- **Evidencia:** captura 12 (grabber en y 310–314 pt; los botones siguen en y 54–98); `sistema-diseno.md:257` («sin muestra; la página de atrás ya cambia en vivo»).
- **Recomendación:**
  - Al abrir «Aa», esconder los botones y la tarjeta: `showsChrome = false` junto con `showsAppearance = true`.
  - Ofrecer dos altos: uno medio (~50 %, con Letra, tamaño y Fondo) y el completo al subirla.
  - La promesa «la página de atrás cambia en vivo» solo funciona si se ve la página.

### H12 · Varios toques por debajo de 44 pt — **Media**

- **Estado:** «Aa» y tarjeta.
- **Qué pasa (regla SB-4 de la casa: todo toque ≥ 44 × 44):**
  - **«A» chica y «A» grande** (`ReaderAppearance.swift:394,398`): botones sin marco. El área de toque es la letra misma, ~8 × 16 pt para la chica (captura 12, x 31–36 pt).
  - **Rayita de la tarjeta** (`ReaderView.swift:518`): alto mínimo de `Space.xl` = 24 pt.
  - **Barra de avance** (`Theme.Size.scrubberHeight` = 32): 32 pt de alto.
  - **Capítulo de la tarjeta, que abre el índice:** rótulo + título ≈ 40 pt (captura 07: de 716 a 752 pt de tinta, más su interlineado).
- **Recomendación:**
  - `frame(minWidth: 44, minHeight: 44)` en las dos «A».
  - `minHeight: Theme.Size.tapTarget` en la rayita: si no se quiere más alto visual, que el área sea más alta que el dibujo.
  - Barra de avance con área de 44 pt (con `contentShape`, sin cambiar el riel).

### H13 · En «Aa», el aire entre secciones es casi el mismo que entre opciones — **Media-baja**

- **Estado:** «Aa» (captura 12).
- **Qué pasa (medido):**
  - Entre secciones: de la barra de tamaño a «PÁGINA» **21 pt**; de los estilos de hoja a «FONDO» **18,7 pt**.
  - Entre elementos de una misma sección: de las leyendas de fondo al interruptor **16 pt**; de interruptor a interruptor **15,6 pt**.

  Con diferencias tan chicas, las secciones no se separan a la vista (06-M6: agrupar sale de la *diferencia* entre huecos).
- **Evidencia:** `ReaderAppearance.swift:300` (`spacing: Space.l` para todo) y `:353` (`padding(.bottom, -Space.s)` para «Fondo»).
- **Recomendación:** de rótulo a contenido 8 pt, entre elementos 12 pt y entre secciones 32 pt (`Space.xxl`). Si falta alto, mejor reducir el tamaño de los mosaicos de letra que el aire entre secciones.

### H14 · Deslizar: atrás tarda el doble que adelante y llega «arrastrándose» — **Media-baja**

- **Estado:** Páginas, estilo Deslizar.
- **Qué pasa.** Hacia adelante, el movimiento visible dura ~0,25 s, porque la hoja sale de la pantalla antes de que se note la cola del resorte. Hacia atrás dura ~0,49 s: la hoja que entra recorre sus últimos 17 pt en 0,19 s, casi quieta.
- **Evidencia (`videos/deslizar.mp4`):**
  - Adelante: cambios en t = 11,292 → 11,540 y en 12,908 → 13,145.
  - Atrás: desplazamiento medido de la hoja que entra en t = 16,527 −26 pt · 16,560 −17 · 16,612 −9 · 16,645 −6 · 16,693 −3 · 16,727 −2 · 16,747 0 (`trabajo/shift.py`).
  - Código: el resorte de `TurnMotion` es «críticamente amortiguado», es decir, frena sin rebotar. Con fuerza 15 recorre el 90 % en 0,26 s y termina en 0,51 s (`Theme.Reader.turnRest` 0,004).
- **Recomendación.** Para Deslizar, dar la vuelta por terminada antes, cuando falte ~1 %, es decir 4 pt (un `slideRest` de 0,01), o usar fuerza 18 hacia atrás. Así las dos direcciones duran ~0,3 s.

### H15 · Hoja con un toque: rápida como latigazo y doblez casi vertical — **Baja-media (gusto, inferencia)**

- **Estado:** Páginas, Hoja.
- **Qué pasa.**
  - Con fuerza 15, desde quieta, la hoja hace la mitad del viaje en 0,11 s. Visible, la vuelta dura ~0,2 s (`hoja.mp4` 12,295 → 12,460).
  - La inclinación de la esquina es de 0,1 radianes, unos 6°. El doblez se ve como una franja casi vertical que rueda («cilindro»), no como una esquina que se levanta (`hoja.png` t = 12,33–12,43).
- **Evidencia:** `Theme.swift:239` (`turnSpring` 15), `:288` (`curlTilt` 0,1); `PageCurl.swift:295`.
- **Por qué importa.** Con el dedo, 15 está bien, porque la hoja sigue tu velocidad. Con un toque no hay velocidad del dedo: toda la animación es «de la app», y a esa velocidad se pierde lo físico que la hace valer la pena.
- **Recomendación** (probar en un iPhone, no está medido):
  - Con un toque (`fromDrag == false`), fuerza 11–12: el 90 % del viaje en 0,33 s.
  - Con el dedo, dejar 15.
  - Probar `curlTilt` entre 0,2 y 0,3 para que se lea la esquina.

### H16 · Fundido: buen relevo, pero el código dice «más suave» y no lo es — **Baja**

- **Qué pasa.** El relevo funciona:
  - La nitidez del texto baja al 12 % a los ~85 ms y vuelve en ~0,25 s.
  - En total dura ~0,33 s, y nunca se leen dos textos a la vez (`fundido.mp4` 10,847–11,163 y 12,463–12,763; medido con la desviación de gris: 52 → 6 → 51).

  Pero `Theme.swift:247` describe «un resorte más suave que la hoja», y `fadeSpring` = 15,0, igual que `turnSpring`.
- **Recomendación.** O se corrige el comentario, o se baja `fadeSpring` a 11–12 para que la llegada del texto nuevo sea un poco más tranquila. Prefiero lo segundo.

### H17 · La documentación y el código no dicen lo mismo — **Baja**

- **Margen de los controles.** `Theme.swift:229` y `sistema-diseno.md:227` dicen que `chromeInset` es «igual arriba y abajo, izquierda y derecha». Medido:
  - 16 pt a los lados.
  - 34,7 pt abajo, porque la tarjeta respeta el área segura.
  - Los botones empiezan 54 pt bajo la orilla de arriba.
- **Duración de una vuelta.** `sistema-diseno.md:245` dice «unos 0,45 s»; `Theme.swift:236` dice «unos 0,55 s»; el cálculo da 0,51 s hasta el reposo y 0,26 s al 90 %.
- **Botón «Listo» del índice.** `sistema-diseno.md:134` dice que los botones de la barra van «en tinta», pero `.pushedScreen` aplica `.tint(Theme.accent)` (`Components.swift:52`) y en la captura 15 sale verde.
- **Recomendación.** Una sola fuente de verdad. Que la prueba de diseño compare estos números con la doc, o que la doc cite el token sin repetir el valor.

### H18 · El índice y la tarjeta no toman el color del tema de lectura — **Baja**

- **Qué pasa:**
  - En «Noche cálida» (página #2B2420), el índice abre con el papel oscuro neutro de la app: píxel medido (22, 21, 20), es decir #161514. «Aa» sí toma el tema (`ReaderAppearance.swift:231-232`).
  - El título de la tarjeta usa la tinta neutra de la app (medido 236, 233, 226) sobre una página de tinta cálida (#E8D9C4).
- **Evidencia:** captura 15; captura 07 (título de la tarjeta frente al texto del libro).
- **Recomendación.** Pasar `palette.background` como `presentationBackground` también a `ReaderToolsSheet`. En temas cálidos, teñir el `ink` del vidrio con la tinta del libro (`palette.textColor`).

### H19 · «El pie dice» puede prometer algo que no muestra — **Baja**

- **Qué pasa.**
  - «Tiempo del libro» con «Calculando…» se puede elegir. Si lo eliges, el pie muestra **porcentaje** sin avisar (`ReaderView.swift:313` y `:322-326`).
  - La muestra dice «35 min para el capítulo», pero el pie real dirá «35 min para terminar el capítulo» (`ReaderView.swift:316`). La doc promete la muestra «tal como se leerá» (`sistema-diseno.md:238`).
- **Recomendación:**
  - Mientras no haya dato, que la opción se vea desactivada (`.disabled`) con una nota corta: «Lee unos minutos y aparece».
  - Que el pie real use el mismo texto corto que la muestra.

### H20 · «188 palabras ›» no dice de qué — **Baja**

- **Qué pasa.** En la tarjeta, la línea de la sesión quita «Esta sesión ·» (`Components.swift:1298`, `compact`). Queda «188 palabras ›», que puede leerse como «palabras del capítulo».
- **Detalle extra.** La misma página se escribe «Pág. 27 de 842» en la tarjeta y «Página 27 de 842» en el pie y en la muestra.
- **Recomendación.** «Hoy · 188 palabras ›» o «Sesión · 188 palabras ›», y una sola forma para la página («Pág.» o «Página»).

### H21 · El lomo termina en una línea visible junto al texto — **Baja**

- **Qué pasa.** La sombra del lomo es un degradado lineal (cambia de oscuro a claro a ritmo constante) que termina en seco a 26 pt. Ahí se forma un borde vertical apenas visible, a 2 pt de donde empieza el texto (28,3 pt).
- **Evidencia:** captura 01, renglón y = 50 pt: luminancia 26 → 37 en línea recta de x 0 a 26 pt y plana después (en papel: 229 → 246). Código: `PageCurl.swift:571-573` (dos paradas lineales) y `Theme.swift:324` (`spineWidth` 26).
- **Recomendación.** Usar 4 paradas con caída suave (por ejemplo, opacidad 1 · 0,45 · 0,15 · 0 en 0 · 0,3 · 0,6 · 1), o bajar el ancho a 20 pt para que el final quede lejos del texto.

### H22 · El margen del texto cambia 2–3 pt entre Páginas y Continuo — **Baja**

- **Medido:** 28,3 / 28,7 pt en Páginas (capturas 01–04) frente a 30,3–31,3 pt en Continuo (05–06).
- **Por qué importa.** Al cambiar de modo, la columna se angosta ~5 pt y el texto se vuelve a repartir en renglones.
- **Recomendación.** Igualar el margen lateral en los dos modos del renderizador (el `gap` de foliate) para que la columna mida lo mismo.

### H23 · Los tokens del lector están fuera de la escala de la casa y nadie los revisa — **Baja**

- **Qué pasa.** La escala común (SB-2: 4·8·16·24·32·48·64) solo se revisa en `Theme.Space`: el `patron` de `sistema-base.json` busca `xxs|xs|…|inline`. Los valores de `Theme.Reader` quedan fuera de la escala y de la revisión: `pageMarginTop` 40, `pageMarginBottom` 68, `folioTop` 18, `folioInset` 60, `folioFade` 56 y `fadeDrift` 12. Lo mismo `gutter` 28.
- **Recomendación.** Extender el revisor a `Theme.Reader` y escribir sus excepciones con su porqué (por ejemplo, «68: centra el pie sobre la barra de inicio»), como pide la regla 16 de la casa.

### H24 · Detalles de «Aa» — **Baja**

1. **Interruptor sin explicación.** «Noche cálida al atardecer» aparece desactivado sin decir por qué cuando el fondo no es «Auto» (`ReaderAppearance.swift:378`). Recomendación: una línea gris debajo, «Solo con fondo Auto», o esconderlo.
2. **Estilos que se ven iguales.** Los cuatro estilos de hoja se ven idénticos si no están elegidos, porque solo se mueve el elegido (`ReaderAppearance.swift:471`). La muestra mide 18 × 24 pt (`Theme.Size.turnPreview`). Recomendación: darle a cada mosaico un dibujo quieto distinto (esquina doblada, dos hojas corridas, media hoja tenue, rayo) y subir la muestra a 24 × 32.
3. **Texto al ras.** «Sin animación» mide 75 pt en un mosaico de ~78 pt (captura 12): queda a 1,5 pt de cada orilla.
4. **Demasiado verde.** Tres controles verdes en la misma hoja (barra de tamaño y dos interruptores). La identidad pide «verde con mesura» (`sistema-diseno.md:98`).
5. **Un espacio usado como tamaño de letra.** El tamaño de la muestra de cada letra sale de un token de *espacio*: `item.preview(size: Theme.Space.xl)` (`ReaderAppearance.swift:309`). Debería tener su propio token.

### H25 · El número de página no cambia en cada vuelta — **Baja (comprobar)**

- **Qué pasa.** Dos pantallas seguidas dicen «Página 28 de 842»:
  - `hoja.mp4` t = 12,18: texto «nombre, sino de la Vieja Bar…».
  - t = 12,71: texto «ble, y eran tratados…».

  Infiero que es la página de la edición impresa, no la pantalla. Es válido, pero quien pasa hoja y ve el mismo número puede creer que no avanzó.
- **Recomendación.** Si es la página impresa, decirlo cuando se repite: «Pág. 28 · sigue» o «p. 28 (impresa)». O preferir por omisión «Tiempo del capítulo», que ya es la opción por omisión del código (`ReaderView.swift:36`).

---

## Interacciones: lo revisado y que está bien

- **Zonas de toque.** Franjas izquierda y derecha iguales del 28 % (`Theme.swift:228`): 112,6 pt cada una, con 176,9 pt al centro. En Continuo, cualquier toque muestra u oculta los controles, como Libros (`ReaderView.swift:196`). Son claras y coherentes.
- **Arrastres.** La barra y la tarjeta no se pelean el arrastre: se espera 6 pt antes de decidir la dirección (`Components.swift:1406-1413`). No puedo sentirlo, pero la lógica está bien.
- **Cerrar.** Solo con el botón de arriba (`interactiveDismissDisabled`), para que deslizar desde la orilla pase hoja y no cierre el libro.
- **Descubribilidad.** Tocar el pie abre la tarjeta ya subida en «El pie dice». Es un atajo excelente pero invisible. Las 3 «asomadas» de la tarjeta (`ReaderView.swift:614-622`) ayudan, aunque no las pude ver en video.

## Lo que ya está bien y no hay que tocar

- **Simetría y centrado del texto.** Margen de 28,3 / 28,7 pt en Páginas, igual al `gutter` de toda la app. Folio y pie centrados al punto (201,0 frente a 201).
- **Contraste en los 4 fondos (calculado):**

  | Fondo | Cuerpo | Folio (74 %) |
  |---|---|---|
  | Papel | 16,1 : 1 | 7,0 : 1 |
  | Blanco | 17,2 : 1 | 7,3 : 1 |
  | Noche cálida | 11,0 : 1 | 6,7 : 1 |
  | Negro | 10,6 : 1 | 6,0 : 1 |

  Sobre el vidrio, «Pág. 27» mide 5,6 : 1 en noche y 6,8 : 1 en papel. Todos pasan 4,5 : 1. Ninguna letra baja de 12 pt (SB-3).
- **Jerarquía tipográfica con propósito.** New York para lo del libro, SF para datos (con cifras de ancho fijo, `monospacedDigit`) y Cinzel solo en rótulos. La tarjeta lo aplica bien: «CAPÍTULO 1» en Cinzel, el título en New York, la página en SF.
- **«Nunca dos textos encimados».** Se cumple en el fundido (mínimo de 12 % de nitidez a mitad del relevo) y al cambiar Páginas↔Continuo (`paginas-continuo.mp4` 14,06–14,63 y 16,69–17,23: el texto viejo se va, queda papel un instante y llega el nuevo, ~0,55 s).
- **«Aa» al cambiar de modo.** Primero se desvanece la fila de estilos y luego se acorta la hoja (`ReaderAppearance.swift:265-278`). Al volver, los mosaicos entran en cascada. Nada se cruza (`paginas-continuo.mp4` 13,87–14,06 y 16,39–16,69).
- **Resorte sin rebote que respeta la velocidad del dedo** (`Components.swift:169-191`), exacto aunque se pierda un cuadro. Es la base correcta para que la hoja se sienta física.
- **«Reducir movimiento».** Hoja y Deslizar pasan a fundido (`ReaderController.swift:146-147`). El fundido no se corre de lado (`PageCurl.swift:274`). El cambio de modo no anima (`PageCurl.swift:112`). La muestra de «Aa» se queda quieta (`Components.swift:238`).
- **Elegidos que no dependen solo del color.** La muestra del pie elegida lleva filo de tinta *y* palomita.
- **Un sistema que se prueba solo** (`DesignRulesTests`), con decisiones fechadas. Muy pocas apps personales lo tienen.

---

## Top 5 de recomendaciones (impacto contra esfuerzo)

1. **Recortar el contenido de la tarjeta a su vidrio** (H2). Una línea de código; quita la falla más visible al subirla.
2. **Entrar al libro sin controles y sin «0 %»** (H3 + H6): controles escondidos al abrir, pie y tarjeta solo con dato, y la primera página con el mismo relevo de 0,45 s que el cambio de modo. Esfuerzo bajo; mejora la primera impresión de cada sesión.
3. **Hoja sin parpadeo ni saltos** (H1): calentar el doblez al abrir, `CIContext` sobre Metal y nunca papel vacío. Medir antes y después en un iPhone. Esfuerzo medio; toca la animación que más se repite.
4. **Letra base de 17–18 pt y justificado opcional** (H4 + H5): base fija de la app, `hyphenate-limit-lines` en 3 e interruptor «Justificar», apagado en iPhone. Esfuerzo bajo-medio; es lo que más cansa al leer una hora.
5. **Una sola línea de alineación y ritmo en tarjeta y «Aa»** (H7 + H8 + H13 + H12): `chromeInset` 12, contenido en 28 pt, barra a página 8 pt, interior de abajo 24 pt, secciones de «Aa» a 32 pt y toques de 44 pt. Esfuerzo bajo; cumple la regla 16 de la casa, porque cada medida queda como token con su prueba.

---

### Archivos de trabajo (para verificar)

`/tmp/gab-ux/trabajo/`:
- Scripts de medida: `perfil.py`, `zona.py`, `movs.py`, `shift.py`, `pick.py`.
- Cuadros reales de cada video con su tiempo: `raw/<video>/` y su `t.txt`.
- Recortes citados: `p_t1.png` (vueltas de Hoja), `p_desl.png` (Deslizar), `p_panel2.png` (mosaicos fuera del vidrio), `p_panel_s.png` (tarjeta durante la carga), `09-top.png`, `pie_hoja.png`.

Son temporales: se pueden borrar al cerrar la revisión.
