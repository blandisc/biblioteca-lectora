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
}

const getCSS = ({ lineHeight, justify, hyphenate, fontFamily }) => `
    html { color-scheme: light dark; }
    body { font-family: ${fontFamily}; }
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
    doc.addEventListener('pointerup', () => {
        const selection = doc.getSelection()
        if (!selection || selection.isCollapsed || selection.rangeCount === 0) return
        const range = selection.getRangeAt(0)
        const text = selection.toString().trim()
        if (!text) return
        post('selection', { cfi: view.getCFI(index, range), text })
    })
}

window.lectora = {
    async open(url, lastLocation) {
        view?.close?.()
        view?.remove()
        view = document.createElement('foliate-view')
        document.body.append(view)
        view.addEventListener('relocate', onRelocate)
        view.addEventListener('load', onLoad)
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
    },
}

post('ready')
