// Puente entre foliate-js y la app nativa.
// La app llama a `window.lectora.*` y recibe eventos por `webkit.messageHandlers.lectora`.
import { makeBook } from './foliate/view.js'
import { collapse, compare } from './foliate/epubcfi.js'

const post = (type, payload = {}) =>
    window.webkit?.messageHandlers?.lectora?.postMessage({ type, ...payload })

const defaultStyle = {
    // Aire entre renglones, igual en todos los libros: el estilo del libro no le gana.
    lineHeight: 1.45,
    justify: true,
    hyphenate: true,
    fontFamily: 'Literata, Charter, Georgia, serif',
    maxInlineSize: 720,
    // Tamaño de letra relativo (1 = el del libro).
    fontScale: 1,
    // Colores del tema de la app (claro u oscuro). null = los del libro.
    textColor: null,
    linkColor: null,
    // «paginated» (de página en página) o «scrolled» (continuo, hacia abajo).
    flow: 'paginated',
    // En el iPhone la página se dobla como hoja (lo hace la app): aquí no se arrastra.
    curl: false,
    // Aire arriba y abajo de la página (px), para que el capítulo y el pie
    // queden sobre papel limpio y nunca encima del texto. Lo manda la app.
    margin: 48,
}

const getColorCSS = ({ textColor, linkColor }) => !textColor ? '' : `
    html, body { color: ${textColor} !important; background: transparent !important; }
    body *:not(a) { color: inherit !important; background-color: transparent !important; }
    a, a * { color: ${linkColor ?? textColor} !important; }
`

// En continuo, un separador «—— 24 ——» donde empieza cada página del libro.
// Va antes de un párrafo (nunca cruza el texto) y se dibuja con CSS sobre un
// atributo: no se agregan nodos al libro, así los CFI (subrayados, marcadores,
// posición) siguen apuntando al mismo lugar.
const pageMarkCSS = ({ flow, textColor }) => {
    if (flow !== 'scrolled') return ''
    const ink = textColor ? `${textColor}a6` : 'rgba(128, 128, 128, 0.8)'
    const line = textColor ? `${textColor}38` : 'rgba(128, 128, 128, 0.3)'
    return `[data-gabinete-page]::before {
        content: attr(data-gabinete-page) !important;
        display: block !important; text-align: center !important; text-indent: 0 !important;
        font: 500 0.72rem/1 -apple-system, system-ui, sans-serif !important;
        letter-spacing: 0.04em; color: ${ink} !important; margin: 1.6em 0 !important;
        background: linear-gradient(${line}, ${line}) left center / calc(50% - 2.2em) 1px no-repeat,
                    linear-gradient(${line}, ${line}) right center / calc(50% - 2.2em) 1px no-repeat !important;
    }`
}

// Página del libro en que empieza cada párrafo (la misma cuenta que foliate en
// view.js: 2,400 bytes del archivo por página, unas 1,800 letras, como una página
// de un libro de bolsillo; con 1,500 salía más corta que una pantalla) y la marca
// en el primero de cada una.
const sizePerPage = 2400
const markPages = (doc, index) => {
    const sections = view?.book?.sections ?? []
    const sizes = sections.map(s => s.linear != 'no' && s.size > 0 ? s.size : 0)
    const size = sizes[index] ?? 0
    if (!size) return
    const before = sizes.slice(0, index).reduce((a, b) => a + b, 0)
    const blocks = [...doc.body.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li, blockquote, pre, figure, dt, dd')]
        .filter(el => !el.parentElement?.closest('p, li, blockquote, pre, figure, dt, dd'))
    const total = blocks.reduce((sum, el) => sum + (el.textContent?.length ?? 0), 0)
    if (!total) return
    let seen = 0
    let page = Math.floor(before / sizePerPage)
    blocks.forEach((el, i) => {
        const here = Math.floor((before + (seen / total) * size) / sizePerPage)
        if (i > 0 && here > page) el.setAttribute('data-gabinete-page', String(here + 1))
        page = Math.max(page, here)
        seen += el.textContent?.length ?? 0
    })
}

const getCSS = ({ lineHeight, justify, hyphenate, fontFamily, fontScale, flow, scrollTop, ...colors }) => `
    html {
        color-scheme: light dark; font-size: ${Math.round(fontScale * 100)}% !important;
        /* Sin esto, WebKit en el iPhone agranda la letra en continuo (la página es
           larguísima y la «ajusta»): la letra debe ser la misma en los dos modos. */
        -webkit-text-size-adjust: 100% !important; text-size-adjust: 100% !important;
    }
    ${getColorCSS(colors)}
    ${pageMarkCSS({ flow, textColor: colors.textColor })}
    ${chapterCSS(colors)}
    body { font-family: ${fontFamily} !important; }
    ${flow === 'scrolled' && scrollTop ? `body { padding-top: ${scrollTop}px !important; }` : ''}
    body *:not(code):not(pre):not(kbd):not(samp) { font-family: inherit !important; }
    /* El aire entre renglones es el nuestro aunque el libro ponga el suyo con
       «!important» en sus clases (p.normal…): el #id de mentira le gana a cualquier clase. */
    :root :is(p, li, blockquote, dd):not(#lectora-even) {
        line-height: ${lineHeight} !important;
    }
    p, li, blockquote, dd {
        text-align: ${justify ? 'justify' : 'start'};
        -webkit-hyphens: ${hyphenate ? 'auto' : 'manual'};
        hyphens: ${hyphenate ? 'auto' : 'manual'};
        -webkit-hyphenate-limit-before: 3;
        -webkit-hyphenate-limit-after: 2;
        -webkit-hyphenate-limit-lines: 2;
        hanging-punctuation: allow-end last;
        widows: 2;
    }
    [align="left"] { text-align: left; }
    [align="right"] { text-align: right; }
    [align="center"] { text-align: center; }
    [align="justify"] { text-align: justify; }
    pre { white-space: pre-wrap !important; }
`

let view = null
let style = { ...defaultStyle }
// El verde de lo tuyo (subrayados, notas, marcador) llega siempre de la app (Theme.Green):
// aquí no se escribe ningún color.
const highlightColor = () => style.linkColor ?? 'currentColor'

// Subrayados: CFI de rango. Se dibujan como un trazo de lápiz bajo el texto.
const highlights = new Set()
let lastSelection = null
let annotationTapped = false

const SVG_NS = 'http://www.w3.org/2000/svg'
const pencil = (rects, { color = highlightColor() } = {}) => {
    const g = document.createElementNS(SVG_NS, 'g')
    g.setAttribute('fill', 'none')
    g.setAttribute('stroke', color)
    g.setAttribute('stroke-width', '1.6')
    g.setAttribute('stroke-linecap', 'round')
    for (const { left, right, bottom } of rects) {
        const w = right - left
        if (w < 2) continue
        const y = bottom + 1
        const path = document.createElementNS(SVG_NS, 'path')
        // Un trazo apenas irregular, como hecho a mano.
        path.setAttribute('pathLength', '1')
        path.dataset.width = String(w)
        path.setAttribute('d', `M${left + 1} ${y + 0.6} C ${left + w * 0.25} ${y - 0.8}, ${left + w * 0.5} ${y + 1}, `
            + `${left + w * 0.72} ${y - 0.2} S ${right - w * 0.06} ${y + 0.4}, ${right - 1} ${y - 0.5}`)
        g.append(path)
    }
    return g
}

// Pasar de página deslizando (la página sigue al dedo y se acomoda sola),
// salvo que el sistema pida reducir el movimiento.
const reducedMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)')

const applyStyle = () => {
    const renderer = view?.renderer
    if (!renderer) return
    renderer.setAttribute('max-inline-size', `${style.maxInlineSize}px`)
    // Margen del texto fijo en puntos (no un porcentaje del ancho), igual en páginas y
    // en continuo y en cualquier iPhone. foliate lo pide como fracción: en páginas el
    // margen es la fracción del ancho; en continuo, fracción ÷ (1 − fracción).
    if (style.textMargin) {
        const m = style.textMargin / Math.max(window.innerWidth, 1)
        const g = style.flow === 'scrolled' ? m / (1 + m) : m
        const gap = `${(g * 100).toFixed(4)}%`
        if (renderer.getAttribute('gap') !== gap) {
            renderer.setAttribute('gap', gap)
            renderer.render?.()
        }
    }
    renderer.toggleAttribute('animated', !reducedMotion?.matches)
    renderer.toggleAttribute('no-drag', !!style.curl)
    // Arriba poco (el capítulo es chico), abajo más (el pie y el contador).
    const margin = `${style.margin}px`
    const bottom = `${style.marginBottom ?? style.margin}px`
    if (renderer.getAttribute('margin') !== margin || renderer.style.getPropertyValue('--_margin-bottom') !== bottom) {
        renderer.style.setProperty('--_margin-bottom', bottom)
        renderer.setAttribute('margin', margin)
        renderer.render?.()
    }
    // Cambiar el modo vuelve a paginar todo: solo si de verdad cambió.
    if (renderer.getAttribute('flow') !== style.flow) renderer.setAttribute('flow', style.flow)
    renderer.setStyles?.(getCSS(style))
}
reducedMotion?.addEventListener?.('change', applyStyle)

// En continuo, en vez de la barra del sistema, un puntito en el margen derecho que
// baja contigo mientras deslizas y se apaga al parar (SC-D, 26 nov 2026). Medidas,
// tenue y tiempo llegan de la app (Theme.Reader.scrollDot…), el color es la tinta.
let scrollDot = null
let scrollDotTimer = null
const moveScrollDot = () => {
    const renderer = view?.renderer
    const dot = style.dot
    if (!renderer || !dot || style.flow !== 'scrolled') return
    if (!scrollDot) {
        scrollDot = document.createElement('div')
        Object.assign(scrollDot.style, {
            position: 'fixed', borderRadius: '50%', pointerEvents: 'none', opacity: '0', zIndex: '2',
        })
        document.body.append(scrollDot)
    }
    const room = renderer.viewSize - renderer.size
    if (room <= 0) return
    const fraction = Math.min(1, Math.max(0, renderer.start / room))
    const track = window.innerHeight - dot.top - dot.bottom - dot.size
    Object.assign(scrollDot.style, {
        width: `${dot.size}px`, height: `${dot.size}px`,
        right: `${dot.right - dot.size / 2}px`,
        top: `${dot.top + fraction * track}px`,
        background: style.textColor ?? 'currentColor',
        transition: `opacity ${dot.fade}s ease-out`,
        opacity: `${dot.opacity}`,
    })
    clearTimeout(scrollDotTimer)
    scrollDotTimer = setTimeout(() => { if (scrollDot) scrollDot.style.opacity = '0' }, dot.hold * 1000)
}
// El margen en puntos depende del ancho: al girar se recalcula.
window.addEventListener('resize', applyStyle)

// En continuo, foliate muestra un capítulo a la vez. Al llegar al final y seguir
// jalando hacia arriba, pasa al siguiente; al principio y jalando hacia abajo, al
// anterior. Así se lee de corrido, sin botones.
const pullThreshold = 64
let selecting = false
const watchPull = doc => {
    let startY = null
    let edge = null
    doc.addEventListener('touchstart', event => {
        const renderer = view?.renderer
        if (!renderer?.scrolled || event.touches.length > 1) { startY = event.touches[0]?.screenY ?? null; edge = null; return }
        startY = event.touches[0].screenY
        edge = renderer.viewSize - renderer.end <= 2 ? 'end' : renderer.start <= 0 ? 'start' : null
    }, { passive: true })
    doc.addEventListener('touchend', event => {
        const renderer = view?.renderer
        if (startY == null || !edge || !renderer?.scrolled) return
        const dy = startY - (event.changedTouches[0]?.screenY ?? startY)
        startY = null
        if (edge === 'end' && dy > pullThreshold) view.next()
        else if (edge === 'start' && dy < -pullThreshold) view.prev()
    }, { passive: true })
}

// Texto del rango sin los títulos (h1–h6): «Capítulo primero» no es parte de la frase.
// Si la página solo tiene un título, se usa el título.
const proseOf = range => {
    if (!range) return ''
    const fragment = range.cloneContents()
    const headings = fragment.querySelectorAll?.('h1, h2, h3, h4, h5, h6') ?? []
    const all = fragment.textContent ?? ''
    headings.forEach(heading => heading.remove())
    const prose = fragment.textContent ?? ''
    return prose.trim() ? prose : all
}

// Primeras palabras de la página, cortadas en una palabra completa.
const excerptOf = range => {
    const text = proseOf(range).replace(/\s+/g, ' ').trim()
    if (!text) return null
    if (text.length <= 160) return text
    return text.slice(0, 160).replace(/\s+\S*$/, '') + '…'
}

// Palabras de la página (para las sesiones de lectura).
const segmenter = typeof Intl.Segmenter === 'function' ? new Intl.Segmenter(undefined, { granularity: 'word' }) : null
const wordsOf = range => wordsOfText(range?.toString() ?? '')
const wordsOfText = text => {
    if (!text.trim()) return 0
    if (!segmenter) return text.trim().split(/\s+/).length
    let count = 0
    for (const part of segmenter.segment(text)) if (part.isWordLike) count++
    return count
}

// Palabras que faltan para terminar el capítulo (el archivo del libro en que
// estás): lo que queda después de la página, con la proporción de palabras por
// letra del capítulo (se cuenta una vez por capítulo, no en cada página).
const wordsPerChar = new WeakMap()
const chapterLeftOf = range => {
    const doc = range?.endContainer?.ownerDocument
    if (!doc?.body) return null
    let rate = wordsPerChar.get(doc)
    if (rate == null) {
        const all = doc.body.textContent ?? ''
        rate = all.length ? wordsOfText(all) / all.length : 0
        wordsPerChar.set(doc, rate)
    }
    try {
        const rest = doc.createRange()
        rest.setStart(range.endContainer, range.endOffset)
        rest.setEnd(doc.body, doc.body.childNodes.length)
        return Math.round(rest.toString().length * rate)
    } catch { return null }
}

// Inicio de capítulo como en un libro bien editado: el primer título del archivo
// (si abre el capítulo) va centrado, en cursiva y con un adorno, y el primer
// párrafo empieza con letra capital. Se marca con atributos y se dibuja con CSS:
// no se agregan nodos, así los CFI siguen apuntando al mismo lugar.
const isTitleLike = el => /^H[1-6]$/.test(el.tagName)
    || /tit|cap|chap|head/i.test(`${el.className} ${el.parentElement?.className ?? ''}`)
const markChapter = doc => {
    // Los primeros renglones cortos antes del primer párrafo de verdad son el
    // título (en muchos libros es un <p class="titulo">, no un <h1>).
    const titles = []
    let first = null
    for (const el of doc.body.querySelectorAll('h1, h2, h3, h4, h5, h6, p')) {
        if (el.parentElement?.closest('p, li, blockquote, figure')) continue
        const length = el.textContent?.trim().length ?? 0
        if (!length) continue
        if (length > 80) { first = el; break }
        titles.push(el)
        if (titles.length > 3) return
    }
    if (!first || !titles.length || !titles.some(isTitleLike)) return
    titles.forEach((el, i) => el.setAttribute('data-gabinete-chapter',
        [i === 0 ? 'first' : '', i === titles.length - 1 ? 'last' : ''].join(' ').trim()))
    if (/^[«"“¿¡(]?\p{L}/u.test(first.textContent.trim())) first.setAttribute('data-gabinete-drop', '')
}

const chapterCSS = ({ linkColor }) => `
    [data-gabinete-chapter] {
        text-align: center !important; text-indent: 0 !important;
        font-style: italic !important; font-weight: 400 !important;
        font-size: 1.45em !important; line-height: 1.25 !important;
        margin: 0 0 0.3em !important;
    }
    [data-gabinete-chapter~="first"] { margin-top: 1em !important; }
    [data-gabinete-chapter~="last"] { margin-bottom: 0 !important; padding-bottom: 1.4em !important; }
    [data-gabinete-chapter] * { font-style: inherit !important; font-weight: inherit !important; }
    [data-gabinete-chapter~="last"]::after {
        content: '❦'; display: block; font-style: normal; font-size: 0.7em;
        line-height: 1; margin-top: 0.6em; opacity: 0.5;
    }
    [data-gabinete-drop] { text-indent: 0 !important; }
    [data-gabinete-drop]::first-letter {
        float: left; font-size: 3.3em; line-height: 0.85; font-weight: 500;
        padding: 0.06em 0.08em 0 0; color: ${linkColor ?? 'currentColor'} !important;
    }
`

// El índice del libro en una lista, con la profundidad de cada entrada.
const flattenTOC = (items, depth = 0) => items.flatMap(item => [
    { label: (item.label ?? '').trim(), href: item.href ?? null, depth },
    ...flattenTOC(item.subitems ?? [], depth + 1),
])

// Búsqueda en el libro: una a la vez; la más reciente gana.
let searchToken = 0

// Cómo se llegó a la página: «jump» si fue por el índice, la barra o un enlace.
let navigation = null

// Marcadores: la app manda sus CFI y aquí se ve cuáles caen en la página visible.
// Se compara el punto del marcador con el principio y el final de la página, no
// el principio exacto: al cambiar la letra o el área visible, foliate vuelve a
// paginar y la página empieza en otro punto, pero el marcador sigue en ella.
let bookmarkCFIs = []
let pageCFI = null
const isOnPage = cfi => {
    if (!cfi || !pageCFI) return false
    try {
        const point = collapse(cfi)
        return compare(point, collapse(pageCFI)) >= 0 && compare(point, collapse(pageCFI, true)) < 0
    } catch { return false }
}
const postMarks = () => post('marks', { cfis: bookmarkCFIs.filter(isOnPage) })

const onRelocate = ({ detail }) => {
    const { fraction, cfi, tocItem, location, range } = detail
    post('relocate', {
        // foliate da NaN en secciones de dos páginas (0 ÷ 0): no se manda.
        fraction: Number.isFinite(fraction) ? fraction : null,
        cfi,
        chapter: tocItem?.label ?? null,
        chapterHref: tocItem?.href ?? null,
        current: location?.current ?? null,
        // Si hay página antes o después (para no doblar la hoja en la portada o al final).
        atStart: view.renderer?.atStart ?? false,
        atEnd: view.renderer?.atEnd ?? false,
        total: location?.total ?? null,
        excerpt: excerptOf(range),
        words: wordsOf(range),
        chapterLeft: chapterLeftOf(range),
        jumped: navigation === 'jump',
    })
    navigation = null
    pageCFI = cfi
    postMarks()
}

// Renglones parejos: una letra con otra fuente (ć, ē), una llamada de nota subida o
// unas versalitas no deben separar su renglón de los demás. Lo que va dentro de la
// línea no aporta alto propio; el renglón lo da el párrafo. Se mide una vez por clase.
const evenLines = doc => {
    const seen = new Map()
    for (const el of doc.body?.querySelectorAll('span, a, sup, sub, small, i, em, b, strong') ?? []) {
        const key = `${el.localName}.${el.className}.${el.getAttribute('style') ?? ''}`
        let inline = seen.get(key)
        if (inline === undefined) {
            inline = getComputedStyle(el).display === 'inline'
            seen.set(key, inline)
        }
        if (inline) el.style.setProperty('line-height', '0', 'important')
    }
}

const onLoad = ({ detail: { doc, index } }) => {
    // El idioma correcto activa la separación silábica en español o inglés.
    if (!doc.documentElement.lang && view.book?.metadata?.language) {
        const lang = view.book.metadata.language
        doc.documentElement.lang = Array.isArray(lang) ? lang[0] : lang
    }
    watchPull(doc)
    evenLines(doc)
    markPages(doc, index)
    markChapter(doc)
    doc.addEventListener('selectionchange', () => {
        const selection = doc.getSelection()
        const active = !!selection && !selection.isCollapsed
        if (active !== selecting) { selecting = active; post('selecting', { active }) }
        if (!selection || selection.isCollapsed || selection.rangeCount === 0) return
        lastSelection = { doc, index, range: selection.getRangeAt(0).cloneRange() }
    })
    // Los toques se resuelven aquí y no con vistas nativas encima, para que el
    // toque largo llegue al texto y se pueda seleccionar.
    doc.addEventListener('click', event => {
        if (annotationTapped) { annotationTapped = false; return }
        if (event.defaultPrevented || event.target.closest?.('a')) return
        const selection = doc.getSelection()
        if (selection && !selection.isCollapsed) return
        const frame = doc.defaultView?.frameElement
        const offset = frame?.getBoundingClientRect().left ?? 0
        post('tap', { x: (event.clientX + offset) / window.innerWidth })
    })
}

// Un subrayado recién hecho se dibuja solo, como trazo de marcador: renglón por
// renglón, de izquierda a derecha. Los que ya estaban aparecen quietos.
const freshHighlights = new Set()
const drawingPencil = (rects, options) => {
    const g = pencil(rects, options)
    let delay = 0
    for (const path of g.children) {
        const duration = Math.min(520, 140 + Number(path.dataset.width ?? 0) * 1.1)
        path.style.strokeDasharray = '1'
        path.animate([{ strokeDashoffset: 1 }, { strokeDashoffset: 0 }],
            { duration, delay, easing: 'cubic-bezier(0.33, 1, 0.68, 1)', fill: 'both' })
        delay += duration * 0.85
    }
    return g
}

// Marcador en continuo (MC-E1): un hilo en el aire entre renglones que nace casi
// invisible en la orilla del texto y se vuelve verde hasta el margen, donde se
// dobla en una cinta chica junto al renglón marcado. Va en la capa de los
// subrayados: se mueve con el texto. En páginas no se dibuja (allí la cinta de la
// esquina marca la hoja).
let freshBookmark = null
let threadCount = 0
const drawnBookmarks = new Set()
// Lo dibujado de cada marcador, para que al quitarlo se recoja en vez de desaparecer.
const bookmarkElements = new Map()
const threadAndTab = (doc, range) => (rects, { color, animated, value }) => {
    const g = document.createElementNS(SVG_NS, 'g')
    bookmarkElements.set(value, g)
    const r = rects[0]
    if (!r) return g
    const block = (range.startContainer.nodeType === 3 ? range.startContainer.parentElement : range.startContainer) ?? doc.body
    const lineHeight = parseFloat(doc.defaultView.getComputedStyle(block).lineHeight) || r.height * 1.45
    // La orilla de arriba del renglón: justo en medio del aire con el de antes.
    const y = r.top - (lineHeight - r.height) / 2
    const body = doc.body.getBoundingClientRect()
    const width = doc.documentElement.clientWidth
    const tab = 10, x = (body.right + width) / 2, h = lineHeight * 1.25
    const id = `lectora-thread-${++threadCount}`
    const defs = document.createElementNS(SVG_NS, 'defs')
    const gradient = document.createElementNS(SVG_NS, 'linearGradient')
    gradient.id = id
    for (const [offset, opacity] of [[0, 0], [0.7, 0.55], [1, 1]]) {
        const stop = document.createElementNS(SVG_NS, 'stop')
        stop.setAttribute('offset', String(offset))
        stop.setAttribute('stop-color', color)
        stop.setAttribute('stop-opacity', String(opacity))
        gradient.append(stop)
    }
    defs.append(gradient)
    const thread = document.createElementNS(SVG_NS, 'rect')
    thread.setAttribute('x', String(body.left))
    thread.setAttribute('y', String(y - 0.5))
    thread.setAttribute('width', String(Math.max(0, x - body.left)))
    thread.setAttribute('height', '1')
    thread.setAttribute('fill', `url(#${id})`)
    const ribbon = document.createElementNS(SVG_NS, 'path')
    ribbon.setAttribute('d', `M${x - tab / 2} ${y} H${x + tab / 2} V${y + h} L${x} ${y + h * 0.84} L${x - tab / 2} ${y + h} Z`)
    ribbon.setAttribute('fill', color)
    g.append(defs, thread, ribbon)
    for (const el of [thread, ribbon]) el.style.transformBox = 'fill-box'
    thread.style.transformOrigin = 'right center'
    ribbon.style.transformOrigin = 'center top'
    if (animated) {
        // La cinta cae con un rebote corto y el hilo se dibuja hacia la izquierda.
        ribbon.animate([{ transform: 'scaleY(0)' }, { transform: 'scaleY(1)' }],
            { duration: 360, easing: 'cubic-bezier(0.3, 1.4, 0.5, 1)', fill: 'both' })
        thread.animate([{ transform: 'scaleX(0)', opacity: 0 }, { transform: 'scaleX(1)', opacity: 1 }],
            { duration: 420, delay: 120, easing: 'cubic-bezier(0.33, 1, 0.68, 1)', fill: 'both' })
    }
    return g
}
const syncBookmarkMarks = () => {
    if (!view) return
    const wanted = new Set(style.flow === 'scrolled' ? bookmarkCFIs : [])
    for (const value of [...drawnBookmarks]) {
        if (wanted.has(value)) continue
        drawnBookmarks.delete(value)
        const g = bookmarkElements.get(value)
        bookmarkElements.delete(value)
        const remove = () => { if (!drawnBookmarks.has(value)) view?.deleteAnnotation({ value }).catch?.(() => {}) }
        const [, thread, ribbon] = g?.isConnected ? g.children : []
        if (!thread || !ribbon || reducedMotion?.matches) { remove(); continue }
        // Al quitarlo, al revés: el hilo se recoge hacia la cinta y la cinta sube.
        thread.animate([{ transform: 'scaleX(1)', opacity: 1 }, { transform: 'scaleX(0)', opacity: 0 }],
            { duration: 280, easing: 'cubic-bezier(0.32, 0, 0.67, 0)', fill: 'both' })
        ribbon.animate([{ transform: 'scaleY(1)' }, { transform: 'scaleY(0)' }],
            { duration: 240, delay: 160, easing: 'cubic-bezier(0.32, 0, 0.67, 0)', fill: 'both' })
            .finished.then(remove, remove)
    }
    for (const value of wanted) {
        if (drawnBookmarks.has(value)) continue
        drawnBookmarks.add(value)
        view.addAnnotation({ value }).catch?.(() => {})
    }
}

const onDrawAnnotation = ({ detail: { draw, annotation, doc, range } }) => {
    if (drawnBookmarks.has(annotation?.value)) {
        const animated = freshBookmark === annotation.value && !reducedMotion?.matches
        if (animated) freshBookmark = null
        draw(threadAndTab(doc, range), { color: highlightColor(), animated, value: annotation.value })
        return
    }
    const animated = freshHighlights.delete(annotation?.value) && !reducedMotion?.matches
    draw(animated ? drawingPencil : pencil, { color: highlightColor() })
}

const onCreateOverlay = () => {
    for (const value of highlights) view.addAnnotation({ value })
    // Los marcadores de continuo también: al abrir el libro aún no había dónde dibujarlos.
    for (const value of style.flow === 'scrolled' ? bookmarkCFIs : []) {
        drawnBookmarks.add(value)
        view.addAnnotation({ value }).catch?.(() => {})
    }
}

const onShowAnnotation = ({ detail: { value } }) => {
    if (drawnBookmarks.has(value)) return
    annotationTapped = true
    post('annotation', { cfi: value })
}

// Datos de un libro para el catálogo (título, autores, serie, ISBN, portada…).
const text = x => {
    if (!x) return null
    if (typeof x === 'string') return x
    if (x.name) return text(x.name)
    const values = Object.values(x)
    return typeof values[0] === 'string' ? values[0] : null
}
const blobToDataURL = blob => new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result)
    reader.onerror = () => reject(reader.error)
    reader.readAsDataURL(blob)
})
const findISBN = values => {
    for (const value of values) {
        const match = String(value).replace(/[-\s]/g, '').match(/(97[89]\d{10}|\d{9}[\dXx])(?!\d)/)
        if (match && (/isbn/i.test(value) || match[1].length === 13)) return match[1].toUpperCase()
    }
    return null
}
const extract = async url => {
    const book = await makeBook(url)
    const m = book.metadata ?? {}
    const authors = [].concat(m.author ?? []).map(text).filter(Boolean)
    let series = m.belongsTo?.series
    if (Array.isArray(series)) series = series[0]
    const identifiers = [].concat(m.identifier ?? [], m.altIdentifier ?? [])
        .map(x => typeof x === 'string' ? x : x?.value ? `${x.scheme}:${x.value}` : null)
        .filter(Boolean)
    let cover = null
    try {
        const blob = await book.getCover?.()
        if (blob) cover = await blobToDataURL(blob)
    } catch {}
    return {
        title: text(m.title),
        authors,
        language: [].concat(m.language ?? [])[0] ?? null,
        publisher: text([].concat(m.publisher ?? [])[0]),
        published: m.published ? String(m.published) : null,
        description: m.description ?? null,
        subjects: [].concat(m.subject ?? []).map(text).filter(Boolean),
        series: text(series?.name) ?? null,
        seriesIndex: Number.isFinite(parseFloat(series?.position)) ? parseFloat(series.position) : null,
        isbn: findISBN(identifiers),
        cover,
    }
}

window.lectora = {
    extract,

    setBookmarks(cfis) {
        bookmarkCFIs = cfis ?? []
        postMarks()
        syncBookmarkMarks()
    },
    // En continuo: el primer renglón que se lee entero `lines` renglones bajo `y`
    // (puntos desde arriba de la pantalla), para que el desvanecido no se coma el marcador. Devuelve su CFI (su primera letra) y el texto que sigue, para
    // la lista de marcadores. La próxima vez que se dibuje, el marcador entra animado.
    readingLine(y, lines = 0) {
        const renderer = view?.renderer
        if (!renderer?.scrolled) return null
        for (const { doc, index } of renderer.getContents()) {
            const frame = doc?.defaultView?.frameElement
            if (!frame || !doc.caretRangeFromPoint) continue
            const body = doc.body.getBoundingClientRect()
            const lineHeight = parseFloat(doc.defaultView.getComputedStyle(doc.body).lineHeight) || 24
            const top = y - frame.getBoundingClientRect().top + lines * lineHeight
            const step = lineHeight / 4
            for (let dy = 0; dy < step * 24; dy += step) {
                const caret = doc.caretRangeFromPoint(body.left + 2, top + dy)
                const node = caret?.startContainer
                if (!node || node.nodeType !== 3 || !node.length || !node.textContent.trim()) continue
                const offset = Math.min(caret.startOffset, node.length - 1)
                const range = doc.createRange()
                range.setStart(node, offset)
                range.setEnd(node, offset + 1)
                const rect = range.getClientRects()[0]
                if (!rect || rect.top < top - 2) continue
                const block = node.parentElement?.closest('p, li, blockquote, dd, div, h1, h2, h3, h4, h5, h6') ?? doc.body
                const rest = doc.createRange()
                rest.setStart(node, offset)
                rest.setEndAfter(block.lastChild ?? block)
                const cfi = view.getCFI(index, range)
                freshBookmark = cfi
                return { cfi, excerpt: rest.toString().replace(/\s+/g, ' ').trim().slice(0, 160) }
            }
        }
        return null
    },

    async open(url, lastLocation) {
        view?.close?.()
        view?.remove()
        view = document.createElement('foliate-view')
        document.body.append(view)
        view.addEventListener('relocate', onRelocate)
        view.addEventListener('load', onLoad)
        view.addEventListener('load', () => view.renderer?.addEventListener('scroll', moveScrollDot), { once: true })
        view.addEventListener('draw-annotation', onDrawAnnotation)
        view.addEventListener('create-overlay', onCreateOverlay)
        view.addEventListener('show-annotation', onShowAnnotation)
        try {
            await view.open(url)
            const { book } = view
            post('opened', {
                title: typeof book.metadata?.title === 'string'
                    ? book.metadata.title
                    : Object.values(book.metadata?.title ?? {})[0] ?? null,
                toc: flattenTOC(book.toc ?? []),
            })
            applyStyle()
            await view.init({ lastLocation: lastLocation || null, showTextStart: !lastLocation })
        } catch (error) {
            post('error', { message: String(error?.message ?? error) })
        }
    },
    next: () => view?.next(),
    prev: () => view?.prev(),
    // Pasa de página sin animación y dice si se movió: la app ya tapó la página
    // con su foto y la va a doblar. Espera a que la nueva esté pintada.
    async turn(dir) {
        const renderer = view?.renderer
        if (!renderer) return false
        const before = pageCFI
        const animated = renderer.hasAttribute('animated')
        renderer.removeAttribute('animated')
        const relocated = new Promise(resolve => {
            view.addEventListener('relocate', resolve, { once: true })
            setTimeout(resolve, 600)
        })
        const turning = dir < 0 ? view.prev() : view.next()
        await Promise.race([relocated, turning])
        if (animated) renderer.setAttribute('animated', '')
        // Que la página nueva quede pintada (sin esperar de más si la vista no pinta).
        await Promise.race([
            new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))),
            new Promise(resolve => setTimeout(resolve, 80)),
        ])
        return pageCFI !== before
    },
    // Después de cambiar de forma (páginas ↔ continuo): espera a que el libro se
    // acomode y quede pintado, o hasta `ms` si no avisa.
    async settled(ms) {
        if (!view) return
        await new Promise(resolve => {
            view.addEventListener('relocate', resolve, { once: true })
            setTimeout(resolve, ms)
        })
        await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
    },
    goTo: target => { navigation = 'jump'; return view?.goTo(target) },
    goToFraction: fraction => { navigation = 'jump'; return view?.goToFraction(fraction) },
    // Busca en todo el libro y manda los resultados (con su capítulo y el texto alrededor).
    async search(query) {
        const token = ++searchToken
        view?.clearSearch()
        const text = (query ?? '').trim()
        if (!view || text.length < 2) { post('searchResults', { query: text, results: [] }); return }
        const results = []
        // La página de cada resultado, contada como el pie del libro (sizePerPage letras).
        const sizes = view.book.sections.map(s => s.linear != 'no' && s.size > 0 ? s.size : 0)
        const sizeTotal = sizes.reduce((a, b) => a + b, 0) || 1
        try {
            // Lo encontrado se recuadra en el verde de la app, no en el rojo de foliate.
            const drawOptions = { color: highlightColor(), width: 1.5 }
            for await (const result of view.search({ query: text, drawOptions })) {
                if (token !== searchToken) return
                if (result === 'done') break
                if (result.progress != null) {
                    post('searchProgress', { query: text, progress: result.progress, count: results.length })
                }
                // Lo que se va encontrando llega a la app capítulo por capítulo, no hasta el final.
                const found = []
                for (const item of result.subitems ?? []) {
                    if (results.length >= 300) break
                    const before = sizes.slice(0, result.index ?? 0).reduce((a, b) => a + b, 0)
                    const at = before + (item.at ?? 0) * (sizes[result.index ?? 0] ?? 0)
                    const entry = {
                        cfi: item.cfi, chapter: result.label ?? '',
                        pre: item.excerpt?.pre ?? '', match: item.excerpt?.match ?? text, post: item.excerpt?.post ?? '',
                        page: Math.floor(at / sizePerPage) + 1, fraction: at / sizeTotal,
                    }
                    results.push(entry)
                    found.push(entry)
                }
                if (found.length) post('searchFound', { query: text, results: found })
                if (results.length >= 300) break
            }
        } catch (error) {
            post('error', { message: String(error?.message ?? error) })
        }
        if (token === searchToken) post('searchResults', { query: text, results })
    },
    clearSearch() {
        searchToken++
        view?.clearSearch()
    },
    // Busca en el libro la cita de cada subrayado que llegó sin posición (de
    // Calibre o de Kindle vía Readwise) y manda dónde quedó, uno por uno. Cada uno
    // trae sus búsquedas de la más exacta a la más suelta (QuoteAnchor en LectoraCore).
    async anchor(items) {
        for (const { id, queries } of items) {
            let cfi = null
            for (const query of queries ?? []) {
                if (!view || cfi) break
                try {
                    for await (const result of view.search({ query })) {
                        if (result === 'done') break
                        if (result.subitems?.length) { cfi = result.subitems[0].cfi; break }
                    }
                } catch {}
                view.clearSearch()
            }
            post('anchored', { id, cfi })
        }
    },
    setStyle(partial) {
        const flowChanged = partial.flow && partial.flow !== style.flow
        style = { ...style, ...partial }
        applyStyle()
        if (partial.linkColor) for (const value of [...highlights, ...drawnBookmarks]) view?.addAnnotation({ value })
        if (flowChanged) syncBookmarkMarks()
        if (flowChanged && scrollDot) scrollDot.style.opacity = '0'
    },
    // Devuelve la selección actual ({ cfi, text, prefix, suffix }) y la limpia.
    takeSelection() {
        if (!lastSelection || !view) return null
        const { doc, index, range } = lastSelection
        lastSelection = null
        const text = range.toString().trim()
        if (!text) return null
        const before = doc.createRange()
        before.setStart(doc.body, 0)
        before.setEnd(range.startContainer, range.startOffset)
        const after = doc.createRange()
        after.setStart(range.endContainer, range.endOffset)
        after.setEnd(doc.body, doc.body.childNodes.length)
        const cfi = view.getCFI(index, range)
        doc.getSelection()?.removeAllRanges()
        return { cfi, text, prefix: before.toString().slice(-40), suffix: after.toString().slice(0, 40) }
    },
    setHighlights(values) {
        highlights.clear()
        for (const value of values) highlights.add(value)
        for (const value of highlights) view?.addAnnotation({ value })
    },
    addHighlight(value) {
        if (!highlights.has(value)) freshHighlights.add(value)
        highlights.add(value)
        view?.addAnnotation({ value })
    },
    removeHighlight(value) {
        highlights.delete(value)
        view?.deleteAnnotation({ value })
    },
}

post('ready')
