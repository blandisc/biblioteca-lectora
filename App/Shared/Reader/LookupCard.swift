import LectoraCore
import SwiftUI
#if canImport(Translation)
import Translation
#endif

/// «Consultar» (SG-4): eliges una palabra o una frase y sale, abajo y sin dejar la página,
/// su traducción (en el teléfono, sin internet), el primer párrafo de Wikipedia en el idioma
/// del libro y el diccionario del sistema. Tocar fuera la cierra.
struct LookupCard: View {
    let term: String
    let bookLanguage: String?
    let close: () -> Void

    @State private var translation: String?
    @State private var summary: WikipediaSummary?
    @State private var searching = true
    @State private var showsDictionary = false
    /// Los idiomas del traductor aún no están en el teléfono: se ofrece «Traducir» y la
    /// descarga empieza solo si la pides.
    @State private var offersTranslation = false
    @State private var wantsTranslation = false
    @Environment(\.openURL) private var openURL

    private var isEntry: Bool { WordLookup.isEntry(term) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            HStack(alignment: .center, spacing: Theme.Space.l) {
                WholeWordsText(term)
                    .font(isEntry ? .bookTitle : .prose)
                    .italic(!isEntry)
                    .lineLimit(Theme.Reader.highlightLines)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
                CloseButton(label: "Cerrar la consulta", action: close)
                    .padding(.vertical, -Theme.Space.s)
            }
            if let translation {
                entry("Traducción", translation)
            }
            if let summary {
                entry("Wikipedia", summary.extract)
            } else if isEntry && searching {
                LoadingLine(text: "Buscando en Wikipedia…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: Theme.Space.s) {
                #if os(iOS)
                if isEntry {
                    tile("Diccionario", "text.magnifyingglass") { showsDictionary = true }
                }
                #endif
                if offersTranslation && translation == nil {
                    tile("Traducir", "translate") {
                        wantsTranslation = true
                        offersTranslation = false
                    }
                }
                if let summary {
                    tile("Wikipedia", "globe") { openURL(summary.url) }
                }
                tile(SelectionAction.copy.title, SelectionAction.copy.symbol) { copy() }
            }
        }
        .padding(Theme.Space.l)
        .glassPanel(cornerRadius: Theme.Radius.panel)
        .padding(.horizontal, Theme.Reader.chromeInset)
        .padding(.bottom, Theme.Reader.chromeInset)
        .animation(Theme.Motion.standard, value: summary)
        .animation(Theme.Motion.standard, value: translation)
        .task {
            summary = await WikipediaClient().summary(for: term, language: bookLanguage)
            searching = false
        }
        .modifier(TranslateTerm(term: term, bookLanguage: bookLanguage, requested: wantsTranslation,
                                offer: $offersTranslation, result: $translation))
        #if os(iOS)
        .sheet(isPresented: $showsDictionary) {
            DictionarySheet(term: term).ignoresSafeArea()
        }
        #endif
    }

    private func entry(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            SectionHeader(label)
            Text(text)
                .font(.prose)
                .foregroundStyle(Theme.ink)
                .lineLimit(Theme.Reader.lookupLines)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tile(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { IconTile(symbol: symbol, title: title) }
            .buttonStyle(PressableStyle())
    }

    private func copy() {
        #if os(iOS)
        UIPasteboard.general.string = term
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(term, forType: .string)
        #endif
    }
}

/// La traducción al español con el traductor de Apple, en el teléfono. Solo si el libro no
/// está en español, y solo en los sistemas que lo traen (iOS 18 y macOS 15 en adelante).
private struct TranslateTerm: ViewModifier {
    let term: String
    let bookLanguage: String?
    let requested: Bool
    @Binding var offer: Bool
    @Binding var result: String?

    func body(content: Content) -> some View {
        #if canImport(Translation)
        if #available(iOS 18.0, macOS 15.0, *), WordLookup.needsTranslation(bookLanguage: bookLanguage) {
            content.modifier(TranslationRunner(term: term, bookLanguage: bookLanguage, requested: requested,
                                               offer: $offer, result: $result))
        } else {
            content
        }
        #else
        content
        #endif
    }
}

#if canImport(Translation)
@available(iOS 18.0, macOS 15.0, *)
private struct TranslationRunner: ViewModifier {
    let term: String
    let bookLanguage: String?
    let requested: Bool
    @Binding var offer: Bool
    @Binding var result: String?
    @State private var configuration: TranslationSession.Configuration?

    private var source: Locale.Language? { WordLookup.languageCode(bookLanguage).map { Locale.Language(identifier: $0) } }
    private let target = Locale.Language(identifier: "es")

    func body(content: Content) -> some View {
        content
            .task {
                // Con los idiomas ya descargados se traduce solo; si faltan, se ofrece el botón.
                let availability = LanguageAvailability()
                let status = if let source {
                    await availability.status(from: source, to: target)
                } else {
                    (try? await availability.status(for: term, to: target)) ?? .unsupported
                }
                switch status {
                case .installed: configuration = .init(source: source, target: target)
                case .supported: offer = true
                default: break
                }
            }
            .onChange(of: requested) { _, now in
                if now { configuration = .init(source: source, target: target) }
            }
            .translationTask(configuration) { session in
                guard let response = try? await session.translate(term) else { return }
                let text = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
                // Si ya estaba en español, la «traducción» sale igual: no se enseña.
                if text.localizedCaseInsensitiveCompare(term) != .orderedSame { result = text }
            }
    }
}
#endif

#if os(iOS)
/// El diccionario del sistema (los que tengas descargados en Ajustes › General › Diccionario).
private struct DictionarySheet: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ controller: UIReferenceLibraryViewController, context: Context) {}
}
#endif
