import LectoraCore
import SwiftUI

/// Claves de la bienvenida.
enum WelcomeKeys {
    /// Ya se vio la bienvenida en este dispositivo.
    static let seen = "bienvenida.vista"
}

/// Primer arranque, en tres pasos: dónde vive tu Gabinete, tus libros y
/// (si quieres) Readwise. Se puede saltar todo; todo se cambia luego en Ajustes.
struct WelcomeScreen: View {
    enum Step: Int, CaseIterable {
        case hello, place, books, readwise
    }

    enum Place {
        case device, folder
    }

    /// Las dos salidas de cada paso, con el mismo nombre en el iPhone (en la barra) y en la Mac (al pie).
    static let skipTitle = "Ir a la biblioteca"
    static let backTitle = "Volver al paso anterior"

    @EnvironmentObject private var model: AppModel
    @ObservedObject private var connectors = ConnectorsStore.shared
    @AppStorage(WelcomeKeys.seen) private var seen = false
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = {
        #if DEBUG
        // Capturas: `-screenshot.step place|books|readwise` abre la bienvenida en ese paso.
        if let name = LaunchOptions.welcomeStep, let step = ["place": Step.place, "books": .books, "readwise": .readwise][name] { return step }
        #endif
        return .hello
    }()
    #if os(macOS)
    /// En la Mac la hoja mide lo que mide su paso, sin pasar de la ventana más chica.
    @State private var contentHeight: CGFloat = Theme.Mac.sheetMax
    #endif
    @State private var place: Place = .device
    @State private var choosingFolder = false
    @State private var migratingCalibre = false
    @State private var importingBooks = false
    @State private var connectingReadwise = false
    @State private var working = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
            #if os(macOS)
            .frame(width: Theme.Mac.welcome, height: min(contentHeight, Theme.Mac.sheetMax))
            #endif
            .pushedScreen()
            #if os(iOS)
            // Con la letra más grande, «Ir a la biblioteca» baja al pie en vez de esconderse en «•••».
            .sheetActions(leave: step == .hello ? nil : SheetAction(title: Self.backTitle, action: goBack),
                          confirm: SheetAction(title: Self.skipTitle) { finish() }, quiet: true)
            #endif
            .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
                if case .success(let folder) = result { useFolder(folder) }
            }
            .sheet(isPresented: $migratingCalibre) { CalibreMigrationScreen(finishTitle: "Seguir con la bienvenida").environmentObject(model).duoBars() }
            .sheet(isPresented: $connectingReadwise) {
                NavigationStack { ConnectorScreen(connector: .readwise) }.duoBars()
            }
            .errorAlert("No pude usar esa carpeta", message: $errorMessage, back: "Elegir otra carpeta")
        }
    }

    /// Cada paso en dos partes: la pregunta (el paso, su título y qué es) y la respuesta (las opciones
    /// y su botón). En un iPhone de pie van una bajo otra, como siempre; acostado, lado a lado, así el
    /// botón se ve sin desplazar; con el Duo abierto, cada una en su página (`Spread`).
    @ViewBuilder private var content: some View {
        #if os(iOS)
        Spread(spacing: Theme.Space.l) {
            stepView(.question)
        } trailing: {
            stepView(.answer)
        }
        #else
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                stepView(.whole)
                // La hoja de la Mac no enseña los botones de la barra: saltar y volver van al pie.
                WelcomeExits(back: step == .hello ? nil : goBack) { finish() }
            }
            .screenContent()
            // Una hoja no tiene la barra de la ventana que deja su aire arriba.
            .padding(.top, Theme.Space.screenTopInSheet)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        #endif
    }

    @ViewBuilder private func stepView(_ part: WelcomePart) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            if step != .hello, part != .answer {
                Text("Paso \(step.rawValue) de \(Step.allCases.count - 1)")
                    .font(.footnote)
                    .foregroundStyle(Theme.tertiaryInk)
            }
            switch step {
            case .hello: HelloStep(part: part) { step = .place }
            case .place:
                PlaceStep(part: part, place: $place, chosen: model.library.isLocal ? nil : CabinetLocation.displayName(model.library.cabinet),
                          working: working, chooseFolder: { choosingFolder = true }) {
                    step = .books
                }
            case .books:
                BooksStep(part: part, count: model.library.books.count,
                          importing: model.library.progressLine,
                          importFraction: model.library.progressFraction,
                          blocked: model.addBooksBlocked,
                          calibre: { migratingCalibre = true },
                          add: { if model.addBooksBlocked == nil { importingBooks = true } }) {
                    step = .readwise
                }
                // Un selector de archivos por vista: este va aquí y el de la carpeta, en la raíz.
                .fileImporter(isPresented: part == .question ? .constant(false) : $importingBooks,
                              allowedContentTypes: LibraryStore.importableTypes,
                              allowsMultipleSelection: true) { model.finishImport($0) }
            case .readwise:
                ReadwiseStep(part: part, connected: connectors.isConnected(.readwise),
                             connect: { connectingReadwise = true }) {
                    finish()
                }
            }
        }
    }

    /// Toda salida cierra la bienvenida (auditoría 5): se anota que ya la viste y se cierra aquí
    /// mismo. Antes se cerraba solo si «vista» cambiaba, y al volver a ella desde el vacío (ya vista)
    /// ninguna salida la cerraba.
    private func finish() {
        seen = true
        dismiss()
    }

    private func goBack() { step = Step(rawValue: step.rawValue - 1) ?? .hello }

    /// La carpeta elegida: si ya tiene un Gabinete (el de tu Mac), se usa; si no, se crea ahí.
    private func useFolder(_ folder: URL) {
        working = true
        Task {
            do {
                if CabinetLocation.hasLibrary(in: folder) {
                    try model.library.use(cabinet: folder)
                } else {
                    try await model.library.move(toCabinet: folder)
                }
                place = .folder
            } catch {
                errorMessage = error.localizedDescription
                place = .device
            }
            working = false
        }
    }
}

/// Qué parte de un paso se pinta: la pregunta, la respuesta o todo (la Mac).
private enum WelcomePart { case question, answer, whole }

/// «Gabinete»: qué es, en dos frases.
private struct HelloStep: View {
    var part: WelcomePart = .whole
    let next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            if part != .answer {
                BrandMark()
                    .padding(.vertical, Theme.Space.xxl)
            }
            if part != .question { answer }
        }
    }

    @ViewBuilder private var answer: some View {
        Text("Para leer y pensar")
            .screenTitleFont()
        Text("Tus libros, tus subrayados y tus notas, juntos en una carpeta tuya. Sin servidor: lo que guardas se queda en tus dispositivos y lo abres también con Calibre y Obsidian.")
            .font(.body)
            .foregroundStyle(Theme.secondaryInk)
        PrimaryButton(title: "Preparar mi Gabinete", fillsWidth: true, action: next)
            .padding(.top, Theme.Space.l)
    }
}

/// Dónde vive tu Gabinete.
private struct PlaceStep: View {
    var part: WelcomePart = .whole
    @Binding var place: WelcomeScreen.Place
    /// Nombre de la carpeta elegida, si ya se eligió una.
    let chosen: String?
    let working: Bool
    let chooseFolder: () -> Void
    let next: () -> Void
    private let device = DeviceKind.current

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            if part != .answer {
                Text("¿Dónde vive tu Gabinete?").screenTitleFont()
                Text("Una carpeta con dos partes: Biblioteca, con la forma de Calibre, y Notas, que abre también Obsidian.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            if part != .question { answer }
        }
    }

    @ViewBuilder private var answer: some View {
        Button { place = .device } label: {
            OptionRow(systemImage: device.symbol, title: device.here,
                      detail: "\(device.localFolder). Puedes moverlo a iCloud Drive después.",
                      selected: place == .device && chosen == nil)
        }
        .buttonStyle(.plain)
        Button(action: chooseFolder) {
            OptionRow(systemImage: "icloud", title: chosen ?? "En iCloud Drive",
                      detail: "Elige o crea una carpeta «Gabinete». Si tu \(device.partner.name) ya tiene uno ahí, uso ese: así tu \(device.name) y tu \(device.partner.name) comparten todo.",
                      selected: chosen != nil)
        }
        .buttonStyle(.plain)
        .disabled(working)
        if working {
            LoadingLine(text: "Preparando la carpeta…")
        }
        PrimaryButton(title: "Usar esta carpeta", fillsWidth: true, action: next)
            .disabled(working)
    }
}

/// Tus libros: traerlos de Calibre, añadir archivos o empezar sin nada.
private struct BooksStep: View {
    var part: WelcomePart = .whole
    let count: Int
    /// «Añadiendo 3 de 32…» si hay una importación en curso.
    let importing: String?
    let importFraction: Double?
    /// Por qué no puedo traer ni añadir libros ahora (bajo tu biblioteca de iCloud, auditoría 6).
    let blocked: String?
    let calibre: () -> Void
    let add: () -> Void
    let next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            if part != .answer { question }
            if part != .question { answer }
        }
    }

    @ViewBuilder private var question: some View {
        Text("Tus libros").screenTitleFont()
        if let importing {
            // Se ve que trabaja: puedes seguir y los libros terminan de llegar solos.
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text(importing)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                ThinProgress(value: importFraction ?? 0)
            }
        } else {
            Text(count == 0 ? "EPUB, PDF, MOBI y cómics propios, sin DRM." : "Ya hay \(count.counted("libro", "libros")) en tu Gabinete.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
        }
    }

    @ViewBuilder private var answer: some View {
        Group {
            Button(action: calibre) {
                OptionRow(systemImage: "books.vertical", title: "Traer mi biblioteca de Calibre",
                          detail: "Libros, datos, portadas, series y subrayados. No toco Calibre.")
            }
            Button(action: add) {
                OptionRow(systemImage: "plus", title: "Añadir archivos",
                          detail: "Desde \(DeviceKind.current.files), iCloud Drive o donde los tengas.")
            }
        }
        .buttonStyle(.plain)
        .disabled(blocked != nil)
        if let blocked {
            ReasonLine(blocked)
        }
        // Sin libros, la salida es discreta: lo importante es traerlos.
        if count == 0 {
            QuietButton(title: "Empezar sin libros", action: next)
        } else {
            PrimaryButton(title: "Seguir con mis libros", fillsWidth: true, action: next)
        }
    }
}

/// Readwise, si lo usas.
private struct ReadwiseStep: View {
    var part: WelcomePart = .whole
    let connected: Bool
    let connect: () -> Void
    let finish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            if part != .answer {
                Text("¿Usas Readwise?").screenTitleFont()
                Text("Tus subrayados van y vienen: los de Gabinete van a Readwise, y llegan los de Kindle y tus otras fuentes. Hardcover y lo demás está en Ajustes › Conexiones.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            if part != .question { answer }
        }
    }

    @ViewBuilder private var answer: some View {
        Button(action: connect) {
            OptionRow(systemImage: "highlighter", title: connected ? "Readwise conectado" : "Conectar Readwise",
                      detail: "Con tu llave de readwise.io/access_token.", selected: connected)
        }
        .buttonStyle(.plain)
        // Sin conectar, la salida es una sola: «Ir a la biblioteca», arriba (o al pie con la letra
        // más grande). «Ahora no» hacía lo mismo sin decirlo (auditoría 8).
        if connected {
            PrimaryButton(title: "Ir a mi Gabinete", fillsWidth: true, action: finish)
        }
    }
}

#if os(macOS)
/// Las salidas de la bienvenida en la Mac, al pie de cada paso: la hoja de la Mac no enseña los
/// botones de la barra, y sin ellas no había cómo saltarla ni volver (auditoría 2).
private struct WelcomeExits: View {
    let back: (() -> Void)?
    let skip: () -> Void

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            Hairline()
            ButtonPair {
                if let back { QuietButton(title: WelcomeScreen.backTitle, action: back) }
                QuietButton(title: WelcomeScreen.skipTitle, action: skip)
            }
        }
    }
}
#endif
