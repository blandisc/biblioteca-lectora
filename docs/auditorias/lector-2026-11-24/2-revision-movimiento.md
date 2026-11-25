# Revisión adversarial · Movimiento, gestos, carga y rendimiento

Revisor: segundo par de ojos sobre `/tmp/gab-ux/informe.md` · 24 nov 2026
Foco: H1, H2, H3, H6, H10, H12, H14, H15, H16 y lo que toca movimiento.

**Cómo verifiqué.**
- Saqué mis propios cuadros con `ffmpeg -fps_mode passthrough` (sin inventar cuadros) y comparé píxel contra píxel cuadros seguidos. Esa comparación es la que cambia la lectura de H1.
- Leí el código del worktree. Mis recortes y scripts están en `/tmp/gab-rev/` (temporales).
- No compilé ni abrí simuladores. Todo es Debug en simulador: los tiempos absolutos no son los de un iPhone. Las *comparaciones* entre estilos dentro del mismo video sí valen.

**Resultado:** de 10 hallazgos revisados, 5 CONFIRMADOS, 5 PARCIALES y 0 REFUTADOS. Dos subafirmaciones sí quedan refutadas: el «cambio de alto de golpe» de H3 y el método de los «cuadros sin pintar» de H1. Además encontré 6 omisiones, y dos de ellas pesan más que varios hallazgos del informe.

---

## 0 · Un error de método que cambia H1

El informe dice: «un hueco entre cuadros durante una animación es un cuadro que no se pintó». Eso no está bien por dos lados:

1. Un hueco puede ser que el grabador del simulador no guardó nada, no que la app no pintó.
2. Lo más importante: el problema real **no aparece como hueco, sino como cuadros repetidos**. En `hoja.mp4` los cuadros de 12,340, 12,343 y 12,418 son **idénticos al píxel** al de 12,317: la diferencia media es 0,00 y no cambia ni un píxel. En la tercera vuelta pasa lo mismo de 13,948 a 14,060.

Eso quiere decir que la pantalla se **congeló** (el hilo principal, el que dibuja la interfaz, estuvo ocupado). No es que faltaran 4 cuadros. El congelón dura **~120 ms**, no 75. Contar huecos subestima el problema.

---

## Veredictos

### H1 · Hoja: la primera vuelta no se dobla y a media vuelta se pierden cuadros — **PARCIAL** (el síntoma es real y es peor de lo que dice; la causa principal está mal ubicada)

**Lo que confirmo:**
- **Primera vuelta.** En t = 11,450 hay texto. De 11,472 a 11,592 hay papel liso, con desviación de gris de 0,0 en toda la zona de texto: ni una sombra ni un doblez. Los 4 cuadros son idénticos entre sí. En 11,597 aparece la página nueva completa.
- **Vueltas 2 y 3.** La hoja se queda **inmóvil** ~120 ms (12,317 → 12,442 y 13,948 → 14,067) y luego **brinca** casi hasta el final (14,092: cambia el 14 % de la pantalla de un cuadro al otro).

**Lo que el informe no vio:**
1. **En todas las vueltas, debajo de la hoja hay papel vacío.** En los cuadros 12,317–12,418 y 13,948–14,060, a la derecha del doblez no hay texto, solo papel. La página nueva aparece debajo de la hoja ya en movimiento (14,067: el doblez sigue en el mismo lugar, pero ahora con texto a su derecha). No pasa solo en la primera vuelta: es de diseño. `PageCurl.swift:155-162` echa a andar la hoja hacia adelante sobre papel liso («sin esperar al libro»), y `PageCurl.swift:216-220` arma el destino como un color plano.
2. **El congelón coincide con la llegada de la página nueva, no con el doblez.** Termina justo cuando aparece el texto de abajo. En ese momento corre `prepare()` → `image(of: page.view, afterUpdates: true)` (`PageCurl.swift:180`, `:376-384`), que llama a `drawHierarchy(afterScreenUpdates: true)`. Esa función obliga al sistema a terminar de pintar todo, y con un WKWebView (la vista web donde vive el libro) adentro, eso bloquea. Además, el código **ya pide una foto a WebKit y la tira**: `webView.takeSnapshot(with: nil) { _, _ in … }` (`:169`) descarta la imagen y luego vuelve a fotografiar con el método caro.
3. **La primera vuelta: lo más probable es que la hoja se doblara entera durante un congelón.** El demo pasa hoja cada 1,5 s (`ReaderView.swift:384-388`), y las vueltas 2→3→4 salen a 1,60 y 1,56 s entre sí. Contando hacia atrás, la primera orden fue hacia t ≈ 10,75, pero la pantalla no cambió sino hasta 11,45: **~0,7 s con la página quieta**. Como el resorte se calcula con el reloj real (`Components.swift:176-181`), al soltarse el congelón la hoja ya «había llegado»: queda el papel liso de debajo hasta que llega la página (11,597). Esto es *inferencia* por el ritmo del demo, pero cuadra con la hipótesis del autor de que Core Image arranca en frío. Esa parte del informe se sostiene.
4. **Comparación que aísla la culpa.** En los mismos videos, Deslizar y Fundido van a ~60 cuadros por segundo, con huecos máximos de 22 y 20 ms. Hoja va a ~40 (cuadros cada 22–28 ms), con el congelón de 120 ms. El atraso de WebKit no frena a los otros estilos; lo caro es lo exclusivo de Hoja: fotografiar con `drawHierarchy` y el dibujo de Core Image en cada cuadro.

**Sobre las recomendaciones del informe:**
- *Calentar el doblez al abrir:* **correcta y barata.** Hay que calentar con el mismo tamaño de imagen y los mismos filtros, y sin bloquear la apertura (después del primer pintado).
- *«`CIContext` sobre Metal»:* **casi no cambia nada.** En iOS, `CIContext(options:)` ya usa la tarjeta gráfica por Metal. Lo caro es otra cosa: `createCGImage` copia el resultado de la tarjeta gráfica a la memoria normal y luego se vuelve a subir como `UIImage`, en cada cuadro. Pintar directo en una capa Metal (`CIRenderDestination`) sí quitaría esa ida y vuelta, pero es trabajo medio y va **después** de lo simple.
- *Reescribir el doblez en Metal:* **no es proporcional ahora.** Las causas simples (abajo) explican el congelón grande.
- *«Nunca mostrar papel vacío»:* bien como meta, pero **choca con lo que pidió el dueño** (que la hoja siga al dedo desde el primer toque). El informe no lo dice. La salida es distinguir el dedo del toque (ver recomendación 3).

**Mi recomendación, en orden de esfuerzo:**
1. Usar la imagen que ya devuelve `takeSnapshot` como página de destino, con el papel y el lomo compuestos en Core Image, y quitar el `drawHierarchy(afterScreenUpdates: true)` de `prepare()`. Es un cambio chico y ataca el congelón de media vuelta.
2. Calcular **una vez por vuelta** el revés de la hoja (el desenfoque y la matriz de color de `MatteCurl.render`, `:455-468`, no dependen del tiempo y hoy se recalculan en cada cuadro).
3. Con **toque** (no con dedo), no arrancar hasta tener la página nueva: cambiar `if forward && style != .none` (`:158`) por `if forward && fromDrag && style != .none`. Con el dedo se mantiene «sigue al dedo»; con el toque se espera ~0,1–0,2 s, pero nunca se ve papel vacío.
4. Calentar Core Image tras el primer pintado.
5. Mitigación barata: limitar el paso de tiempo del resorte a ~1/30 s en `step()`. Así, si hay un congelón, la hoja se detiene y sigue, en vez de detenerse y **brincar**.
6. Medir en un iPhone con Instruments («Animation Hitches»). Solo si después sigue por debajo de 60 cuadros, pintar en una capa Metal.

### H2 · «El pie dice» se dibuja fuera del vidrio — **CONFIRMADO**
- `panel.mp4`: en 10,730 y 10,745 el rótulo «EL PIE DICE» y los mosaicos quedan **debajo** del borde del vidrio, sobre el texto del libro. Siguen saliéndose hasta ~10,85 (unos 0,15–0,2 s).
- La causa está bien: `ReaderView.swift:593` (`.move(edge: .bottom)`) y un panel que no recorta su contenido (`glassPanel` en `Theme.swift:453-462` solo pone el fondo).
- **Recomendación:** correcta y barata. Con el recorte, los mosaicos «salen de detrás» del borde, que se lee como objeto físico. Cambiar además `.move` por `opacity + offset(y: 8)` es opcional: el recorte solo ya arregla la falla.
- **Severidad:** la bajaría a Media-alta. Dura 0,2 s y solo pasa al subir la tarjeta, frente a la vuelta de hoja, que pasa cientos de veces.

### H3 · Al abrir salen controles vacíos y «0 %» — **PARCIAL** (es real y es peor; una subafirmación no se sostiene)
- **Confirmo** «0 %» y «0 palabras» durante la carga (`panel.mp4` 8,16–8,26) y el porcentaje como respaldo en el código (`ReaderView.swift:322-326`).
- **No se sostiene** que «la tarjeta cambia de alto de golpe». En 8,258 → 8,275 el borde de arriba de la tarjeta no se mueve. Lo que cambia en un cuadro es el contenido: aparece «CAPÍTULO 1», se cambia el título y «0 palabras» salta a «188 palabras» sin transición. La «diferencia de 22» del informe es un cambio de píxeles, no de alto.
- **Lo que falta, y es más grave:** el pie **no pasa de «0 %» a «Página 27»: pasa por «Página 23»**, una página equivocada. Entre 8,50 y 8,85 se ven **tres textos encimados** («0 %», «Página 23 de 842», «Página 27 de 842»), y el «23» se corre de lado mientras se desvanece (recorte `/tmp/gab-rev/pie/all.png`). Arriba, «Agentes del imperio» y «1. Ulcinj…» también se encima un momento. Esto contradice el elogio del informe de que «nunca se leen dos textos encimados».
- **Recomendación corregida:** no basta con esperar a que *exista* `folioLocation`, porque su primer valor puede ser el equivocado (23). Hay que esperar a la **primera posición asentada**. Ya existe `onPositionSettled` (`ReaderView.swift:208`). «Abrir sin controles» se puede discutir: la tarjeta abierta al entrar también enseña que existe, y las 3 «asomadas» (`ReaderView.swift:612-620`) solo corren cuando la tarjeta está visible. La salida más simple es dejar la tarjeta, pero sin números hasta tener dato.

### H6 · La carga tarda 4–5 s y el texto aparece de golpe — **PARCIAL**
- **Confirmo** las medidas (el letrero dura 3,41 → 8,49 s en `hoja.mp4`) y que el texto entra en un solo cuadro (`panel.mp4` 8,296 → 8,311).
- **Pero** el demo abre la app en frío, directo al libro, en Debug: incluye arrancar el proceso de WebKit y abrir el EPUB de 842 páginas. No sirve como medida de «abrir un libro desde la biblioteca». La severidad es **no verificable** sin un iPhone en Release.
- La recomendación de dar a la primera página el mismo relevo de entrada es correcta y barata. Yo usaría unos 0,25 s, no 0,45: al abrir, quien lee ya esperó.

### H10 · En Continuo con controles, el texto corre bajo los botones — **CONFIRMADO**
- `trabajo/09-top.png`: «Gobierno… de Ancona» se lee mezclado con 🔍 Aa.
- Hacerlo decisión de Fernando es correcto. Opción extra: en iOS 26, el «borde suave» del sistema en la vista que se desplaza (`scrollView.topEdgeEffect` del WKWebView) hace esto de forma nativa. La app soporta iOS 17, así que necesitaría la franja como respaldo.

### H12 · Toques por debajo de 44 pt — **CONFIRMADO** (con una advertencia que el informe no da)
- «A» chica y «A» grande: `Text("A")` sin marco, con `.buttonStyle(.plain)` (`ReaderAppearance.swift:393-398`). El área de toque es la letra misma.
- Rayita: `minHeight: Theme.Space.xl` (24) (`ReaderView.swift:516-518`).
- Barra: `scrubberHeight` 32 (`Theme.swift:146`).
- Capítulo ≈ 40 pt: plausible, no lo medí. Es de ancho completo, así que importa menos.
- **Advertencia:** la barra de avance **salta con un solo toque** (`Components.swift:1420`: si no hubo arrastre, el toque mueve al punto tocado) y **no hay «Volver a la página 27»** (busqué; no existe). Agrandar su área a 44 pt sin esa vuelta atrás aumenta los saltos por accidente, y la tarjeta está justo donde descansa el pulgar. Primero hace falta el «volver», luego el área grande.

### H14 · Deslizar: atrás tarda el doble y llega arrastrándose — **CONFIRMADO**
- Mi medida independiente coincide: −17 pt en 16,560 → 0 en 16,747, así que los últimos 17 pt toman 0,19 s.
- La matemática del resorte también: con fuerza 15, el 50 % del viaje en 0,11 s, el 90 % en 0,26 s y el reposo en 0,51 s.
- **Sobre la recomendación:** un `slideRest` de 0,01 deja un salto final de 4 pt en un cuadro, que a esa velocidad (~60 pt/s) se nota como un tic. Prefiero la otra opción del informe, **más fuerza solo para Deslizar** (18–20: el 90 % en 0,19–0,22 s), en las dos direcciones.

### H15 · Hoja con un toque: «latigazo» — **PARCIAL**
- La medida de «visible ~0,2 s (12,295 → 12,460)» está **contaminada**: de esos 165 ms, ~120 son el congelón de H1. Parte de la sensación de golpe viene del brinco tras el congelón, no del resorte.
- La idea de usar menos fuerza solo con toque (11–12) sigue siendo razonable. También ayuda a H1: con menos fuerza, cuando llega la página se ha destapado menos papel vacío (a 0,1 s, ~30 % en vez de ~44 %).
- Primero hay que arreglar H1 y luego ajustar el gusto en un iPhone.

### H16 · Fundido: el comentario dice «más suave» y no lo es — **CONFIRMADO**
- `Theme.swift:247` (comentario) y `:250` (`fadeSpring = 15.0`).
- Mi medida coincide: la nitidez del texto cae de 52 a 6 en 85 ms y vuelve a 50 en ~0,27 s, con cuadros cada 17 ms.
- **No bajaría la fuerza:** con menos fuerza dura más el momento sin texto a mitad del relevo. Corregiría el comentario.

### Elogios del informe que reviso
- «Resorte exacto aunque se pierda un cuadro» (`Components.swift:176-181`): **cierto, pero es lo que produce el brinco tras el congelón**. No es solo una virtud (ver H1, punto 5).
- «Nunca dos textos encimados»: **falso al abrir el libro** (ver H3). Sí se cumple en Fundido y en el cambio Páginas↔Continuo.
- «Reducir movimiento»: **confirmado** (`ReaderController.swift:144-147`, `PageCurl.swift:112` y `:274`).

---

## Lo que el informe omitió (en mi foco)

1. **Papel vacío bajo la hoja en todas las vueltas hacia adelante**, no solo en la primera (ver H1). Es el defecto de movimiento más frecuente de la app.
2. **Hacia atrás, la hoja NO sigue al dedo desde el primer toque.** El dueño lo pidió y el código no lo cumple: `live` solo existe hacia adelante (`PageCurl.swift:158`), y `render()` no dibuja nada mientras la vuelta no esté `ready || live` (`:263`). Al arrastrar hacia atrás, la página se queda quieta hasta que WebKit cambia de página, la fotografía y corre `prepare()`, y luego **brinca** a donde está el dedo. No lo pude ver en video (el demo es por código); se ve en el código y hay que probarlo con el dedo.
3. **La tarjeta no sigue al dedo.** El arrastre para subirla o bajarla solo actúa al soltar (`ReaderView.swift:632-637`, `.onEnded`). Mientras arrastras no se mueve nada y luego salta con la animación. Va contra el mismo pedido del dueño; Libros de Apple sigue el dedo.
4. **Al abrir, el pie pasa por una página equivocada (23) y encima tres textos** (ver H3).
5. **Al empezar cada vuelta se fotografía la página en el hilo principal** (`PageCurl.swift:148` y `:154`: `snapshotView` más `drawHierarchy` a 2×), justo en el instante en que el dedo empieza a moverse. Es costo de entrada en cada vuelta. Hay que medirlo en un iPhone.
6. **La barra de avance salta con un toque y no hay cómo volver** (ver H12).

---

## Mi top 5 corregido (impacto contra esfuerzo)

1. **Hoja sin papel vacío ni congelones** (H1, rehecho): usar la foto que ya da `takeSnapshot` en vez de `drawHierarchy(afterScreenUpdates: true)`; calcular el revés una vez por vuelta; con toque, esperar a la página (con el dedo, seguirlo); calentar Core Image; limitar el paso del resorte. **Esfuerzo bajo-medio.** Toca la animación que más se repite. Medir en un iPhone antes de pensar en Metal.
2. **Entrada al libro limpia** (H3 + H6 + omisión 4): ningún número (pie ni tarjeta) hasta la primera posición *asentada*; nada de «0 %» ni «Página 23»; la primera página entra con un relevo corto. **Esfuerzo bajo.**
3. **Que todo siga al dedo** (omisiones 2 y 3): la hoja hacia atrás (mostrar la foto de la página de ahora moviéndose y cambiar el reverso al llegar la anterior) y la tarjeta durante el arrastre. **Esfuerzo medio.** Es un pedido explícito del dueño que hoy no se cumple.
4. **Recortar la tarjeta a su vidrio** (H2). **Una línea.**
5. **Barra de avance segura y toques de 44 pt** (H12 + omisión 6): primero «Volver a la página 27» tras un salto, luego áreas de 44 pt en la barra, las dos «A» y la rayita. **Esfuerzo bajo.**

Fuera del top, pero barato: más fuerza al resorte de Deslizar (H14) y corregir el comentario del Fundido (H16).

---

**Fuera de mi foco, sin revisar a fondo:** no vi errores graves en tipografía ni espacios al pasar. Solo un detalle: la recomendación de H7 dice «el interior de la tarjeta de 16 a 16 (sin cambio)», que se lee como errata, y la cuenta 12 + 16 = 28 pasa por alto que los botones de arriba también cambiarían de lugar. Que lo confirme el otro revisor.

Archivos de esta revisión: `/tmp/gab-rev/` (cuadros y recortes; temporales, se pueden borrar al cerrar la revisión).
