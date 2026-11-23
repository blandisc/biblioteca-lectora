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

    @EnvironmentObject private var model: AppModel
    @ObservedObject private var connectors = ConnectorsStore.shared
    @AppStorage(WelcomeKeys.seen) private var seen = false
    @State private var step: Step = .hello
    @State private var place: Place = .device
    @State private var choosingFolder = false
    @State private var migratingCalibre = false
    @State private var importingBooks = false
    @State private var connectingReadwise = false
    @State private var working = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    if step != .hello {
                        Text("Paso \(step.rawValue) de \(Step.allCases.count - 1)")
                            .font(.footnote)
                            .foregroundStyle(Theme.tertiaryInk)
                    }
                    switch step {
                    case .hello: HelloStep { step = .place }
                    case .place:
                        PlaceStep(place: $place, chosen: model.library.isLocal ? nil : CabinetLocation.displayName(model.library.cabinet),
                                  working: working, chooseFolder: { choosingFolder = true }) {
                            step = .books
                        }
                    case .books:
                        BooksStep(count: model.library.books.count,
                                  importing: model.library.progressLine,
                                  importFraction: model.library.progressFraction,
                                  calibre: { migratingCalibre = true },
                                  add: { importingBooks = true }) {
                            step = .readwise
                        }
                        // Un selector de archivos por vista: este va aquí y el de la carpeta, arriba.
                        .fileImporter(isPresented: $importingBooks, allowedContentTypes: LibraryStore.importableTypes,
                                      allowsMultipleSelection: true) { model.finishImport($0) }
                    case .readwise:
                        ReadwiseStep(connected: connectors.isConnected(.readwise),
                                     connect: { connectingReadwise = true }) {
                            seen = true
                        }
                    }
                }
                .screenContent()
            }
            .pushedScreen()
            .toolbar {
                if step != .hello {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Atrás") { step = Step(rawValue: step.rawValue - 1) ?? .hello }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Saltar") { seen = true }.foregroundStyle(Theme.secondaryInk)
                }
            }
            .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
                if case .success(let folder) = result { useFolder(folder) }
            }
            .sheet(isPresented: $migratingCalibre) { CalibreMigrationScreen().environmentObject(model) }
            .sheet(isPresented: $connectingReadwise) {
                NavigationStack { ConnectorScreen(connector: .readwise) }
            }
            .alert("No se pudo usar esa carpeta", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

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

/// «Gabinete»: qué es, en dos frases.
private struct HelloStep: View {
    let next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            BrandMark()
                .padding(.vertical, Theme.Space.xxl)
            Text("Para leer y pensar")
                .font(.screenTitle)
            Text("Tus libros, tus subrayados y tus notas, juntos en una carpeta tuya. Sin servidor: lo que guardas se queda en tus dispositivos y se abre también con Calibre y Obsidian.")
                .font(.body)
                .foregroundStyle(Theme.secondaryInk)
            PrimaryButton(title: "Empezar", fillsWidth: true, action: next)
                .padding(.top, Theme.Space.l)
        }
    }
}

/// Dónde vive tu Gabinete.
private struct PlaceStep: View {
    @Binding var place: WelcomeScreen.Place
    /// Nombre de la carpeta elegida, si ya se eligió una.
    let chosen: String?
    let working: Bool
    let chooseFolder: () -> Void
    let next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            Text("¿Dónde vive tu Gabinete?").font(.screenTitle)
            Text("Una carpeta con dos partes: Biblioteca (con la forma de Calibre) y Notas (Markdown).")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
            Button { place = .device } label: {
                OptionRow(systemImage: "iphone", title: "En este dispositivo",
                          detail: "Archivos › En mi iPhone › Gabinete. Puedes moverlo a iCloud después.",
                          selected: place == .device && chosen == nil)
            }
            .buttonStyle(.plain)
            Button(action: chooseFolder) {
                OptionRow(systemImage: "icloud", title: chosen ?? "En iCloud Drive",
                          detail: "Elige o crea una carpeta «Gabinete». Si tu Mac ya tiene uno ahí, se usa ese: así tu iPhone y tu Mac comparten todo.",
                          selected: chosen != nil)
            }
            .buttonStyle(.plain)
            .disabled(working)
            if working {
                HStack(spacing: Theme.Space.s) { ProgressView(); Text("Preparando la carpeta…").font(.footnote) }
                    .foregroundStyle(Theme.secondaryInk)
            }
            PrimaryButton(title: "Seguir", fillsWidth: true, action: next)
                .disabled(working)
        }
    }
}

/// Tus libros: traerlos de Calibre, añadir archivos o empezar sin nada.
private struct BooksStep: View {
    let count: Int
    /// «Añadiendo 3 de 32…» si hay una importación en curso.
    let importing: String?
    let importFraction: Double?
    let calibre: () -> Void
    let add: () -> Void
    let next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            Text("Tus libros").font(.screenTitle)
            if let importing {
                // Se ve que trabaja: puedes seguir y los libros terminan de llegar solos.
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text(importing)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                    ThinProgress(value: importFraction ?? 0)
                }
            } else {
                Text(count == 0 ? "EPUB, PDF, MOBI y cómics propios, sin DRM." : count == 1 ? "Ya hay 1 libro en tu Gabinete." : "Ya hay \(count) libros en tu Gabinete.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            Button(action: calibre) {
                OptionRow(systemImage: "books.vertical", title: "Traer mi biblioteca de Calibre",
                          detail: "Libros, datos, portadas, series y subrayados. Calibre no se toca.")
            }
            .buttonStyle(.plain)
            Button(action: add) {
                OptionRow(systemImage: "plus", title: "Añadir archivos",
                          detail: "Desde Archivos, iCloud Drive o donde los tengas.")
            }
            .buttonStyle(.plain)
            // Sin libros, la salida es discreta: lo importante es traerlos.
            if count == 0 {
                QuietButton(title: "Empezar sin libros", action: next)
            } else {
                PrimaryButton(title: "Seguir", fillsWidth: true, action: next)
            }
        }
    }
}

/// Readwise, si lo usas.
private struct ReadwiseStep: View {
    let connected: Bool
    let connect: () -> Void
    let finish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            Text("¿Usas Readwise?").font(.screenTitle)
            Text("Tus subrayados van y vienen: los de Gabinete van a Readwise, y llegan los de Kindle y tus otras fuentes. Hardcover y lo demás está en Ajustes › Conexiones.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
            Button(action: connect) {
                OptionRow(systemImage: "highlighter", title: connected ? "Readwise conectado" : "Conectar Readwise",
                          detail: "Con tu llave de readwise.io/access_token.", selected: connected)
            }
            .buttonStyle(.plain)
            if connected {
                PrimaryButton(title: "Listo", fillsWidth: true, action: finish)
            } else {
                QuietButton(title: "Ahora no", action: finish)
            }
        }
    }
}
