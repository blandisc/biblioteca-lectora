// Puente entre foliate-js y la app nativa.
// La app llama a `window.lectora.*` y recibe eventos por `webkit.messageHandlers.lectora`.
import './foliate/view.js'

const post = (type, payload = {}) =>
    window.webkit?.messageHandlers?.lectora?.postMessage({ type, ...payload })

const defaultStyle = {
    lineHeight: 1.5,
    justify: true,
    hyphenate: true,
    fontFamily: 'Literata, Charter, Georgia, serif',
    maxInlineSize: 720,
    // Tamaño de letra relativo (1 = el del libro).
    fontScale: 1,
    // Colores del tema de la app (claro u oscuro). null = los del libro.
    textColor: null,
    linkColor: null,
}

const getColorCSS = ({ textColor, linkColor }) => !textColor ? '' : `
    html, body { color: ${textColor} !important; background: transparent !important; }
    body *:not(a) { color: inherit !important; background-color: transparent !important; }
    a, a * { color: ${linkColor ?? textColor} !important; }
`

const getCSS = ({ lineHeight, justify, hyphenate, fontFamily, fontScale, ...colors }) => `
    html { color-scheme: light dark; font-size: ${Math.round(fontScale * 100)}% !important; }
    ${getColorCSS(colors)}
    body { font-family: ${fontFamily} !important; }
    body *:not(code):not(pre):not(kbd):not(samp) { font-family: inherit !important; }
    p, li, blockquote, dd {
        line-height: ${lineHeight};
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

// Subrayados: CFI de rango. Se dibujan como un trazo de lápiz bajo el texto.
const highlights = new Set()
let lastSelection = null
let annotationTapped = false

const SVG_NS = 'http://www.w3.org/2000/svg'
const pencil = (rects, { color = '#B8372A' } = {}) => {
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
        path.setAttribute('d', `M${left + 1} ${y + 0.6} C ${left + w * 0.25} ${y - 0.8}, ${left + w * 0.5} ${y + 1}, `
            + `${left + w * 0.72} ${y - 0.2} S ${right - w * 0.06} ${y + 0.4}, ${right - 1} ${y - 0.5}`)
        g.append(path)
    }
    return g
}

const applyStyle = () => {
    if (!view?.renderer) return
    view.renderer.setStyles?.(getCSS(style))
    view.renderer.setAttribute('max-inline-size', `${style.maxInlineSize}px`)
}

const onRelocate = ({ detail }) => {
    const { fraction, cfi, tocItem, location } = detail
    post('relocate', {
        fraction,
        cfi,
        chapter: tocItem?.label ?? null,
        current: location?.current ?? null,
        total: location?.total ?? null,
    })
}

const onLoad = ({ detail: { doc, index } }) => {
    // El idioma correcto activa la separación silábica en español o inglés.
    if (!doc.documentElement.lang && view.book?.metadata?.language) {
        const lang = view.book.metadata.language
        doc.documentElement.lang = Array.isArray(lang) ? lang[0] : lang
    }
    doc.addEventListener('selectionchange', () => {
        const selection = doc.getSelection()
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

const onDrawAnnotation = ({ detail: { draw } }) =>
    draw(pencil, { color: style.linkColor ?? '#B8372A' })

const onCreateOverlay = () => {
    for (const value of highlights) view.addAnnotation({ value })
}

const onShowAnnotation = ({ detail: { value } }) => {
    annotationTapped = true
    post('annotation', { cfi: value })
}

window.lectora = {
    async open(url, lastLocation) {
        view?.close?.()
        view?.remove()
        view = document.createElement('foliate-view')
        document.body.append(view)
        view.addEventListener('relocate', onRelocate)
        view.addEventListener('load', onLoad)
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
                toc: (book.toc ?? []).map(item => ({ label: item.label, href: item.href })),
            })
            applyStyle()
            await view.init({ lastLocation: lastLocation || null, showTextStart: !lastLocation })
        } catch (error) {
            post('error', { message: String(error?.message ?? error) })
        }
    },
    next: () => view?.next(),
    prev: () => view?.prev(),
    goTo: target => view?.goTo(target),
    goToFraction: fraction => view?.goToFraction(fraction),
    setFlow: flow => view?.renderer?.setAttribute('flow', flow),
    setStyle(partial) {
        style = { ...style, ...partial }
        applyStyle()
        if (partial.linkColor) for (const value of highlights) view?.addAnnotation({ value })
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
        highlights.add(value)
        view?.addAnnotation({ value })
    },
    removeHighlight(value) {
        highlights.delete(value)
        view?.deleteAnnotation({ value })
    },
}

post('ready')
