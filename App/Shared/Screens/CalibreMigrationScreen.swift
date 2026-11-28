import LectoraCore
import SwiftUI
import UniformTypeIdentifiers

/// Traer tu biblioteca de Calibre (una sola vez): elegir la carpeta, ver qué
/// llega, traerlo y el resumen. Calibre no se toca: se copia (arquitectura D3).
struct CalibreMigrationScreen: View {
    /// El botón del final dice a dónde vuelves: la hoja se cierra sobre donde la abriste
    /// («Ver mi biblioteca» volvía a la bienvenida o a Ajustes).
    var finishTitle = "Volver a Ajustes"

    enum Step {
        case choose
        case reading
        case review(source: URL, plan: CalibreMigrationPlan)
        case migrating
        case done(CalibreMigrationReport)
    }

    @EnvironmentObject private var model: AppModel
    /// Hoja o, con el Duo abierto y acostado, panel en una página: se cierra igual (`SheetDismiss`).
    private let dismiss = SheetDismiss()
    @State private var step: Step = .choose
    @State private var choosing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    switch step {
                    case .choose: ChooseStep(blocked: model.addBooksBlocked) { choosing = true }
                    case .reading: progress(title: "Leyendo tu biblioteca de Calibre…", value: nil)
                    // Mientras bajo tu biblioteca de iCloud, el plan saldría de una lista a medias (auditoría 6).
                    case .review(let source, let plan):
                        ReviewStep(plan: plan, busyReason: model.library.busyReason ?? model.addBooksBlocked,
                                   cloudIncomplete: model.library.cloudGaveUp) { migrate(source: source, plan: plan) }
                    case .migrating:
                        let done = model.library.progress
                        progress(title: done.map { "Trayendo \($0.done.counted("libro", "libros")) de \($0.total)…" } ?? "Trayendo…",
                                 value: model.library.progressFraction)
                    case .done(let report): SummaryStep(report: report, finishTitle: finishTitle) { dismiss() }
                    }
                }
                .screenContent()
            }
            .pushedScreen("Traer de Calibre")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !isMigrating { BarButton("Cerrar la importación") { dismiss() } }
                }
            }
            .fileImporter(isPresented: $choosing, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result { read(url) }
            }
            .errorAlert("No pude leer tu biblioteca de Calibre", message: $errorMessage, back: "Volver a la importación")
            .interactiveDismissDisabled(isMigrating)
        }
    }

    private var isMigrating: Bool {
        if case .migrating = step { return true }
        return false
    }

    // MARK: Pasos

    private func progress(title: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            if let value {
                Text(title).font(.body)
                ThinProgress(value: value)
            } else {
                LoadingLine(text: title)
            }
            Text("Mantén Gabinete abierto hasta que termine: si sales de la app, puedo quedarme a medias.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
        }
    }

    // MARK: Acciones

    private func read(_ url: URL) {
        step = .reading
        Task {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let entries = try await Task.detached(priority: .userInitiated) { try CalibreLibrary.read(libraryAt: url) }.value
                step = .review(source: url, plan: CalibreMigrationPlan(entries: entries, existing: model.library.books))
            } catch {
                errorMessage = error.localizedDescription
                step = .choose
            }
        }
    }

    private func migrate(source: URL, plan: CalibreMigrationPlan) {
        step = .migrating
        Task {
            let report = await model.library.migrateFromCalibre(source, plan: plan, annotations: model.annotations)
            step = .done(report)
        }
    }
}

/// Paso 1: qué hace la migración y elegir la carpeta.
private struct ChooseStep: View {
    /// Por qué no puedo traerla ahora (bajo tu biblioteca de iCloud).
    var blocked: String?
    let choose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            SectionHeader("Una sola vez")
            Text("Elige la carpeta de tu biblioteca de Calibre: la que se abre en Calibre con el botón Biblioteca › Abrir la carpeta.")
                .font(.body)
            Text("Copio tus libros con sus datos, portadas, series, etiquetas, calificaciones y los subrayados del visor de Calibre. Tu biblioteca de Calibre no la toco. Desde ahí, Gabinete es el dueño del catálogo y deja los datos de cada libro en su carpeta, al día: si vuelves a Calibre, su «Restaurar base de datos» la reconstruye.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
            if let blocked {
                ReasonLine(blocked)
            }
            PrimaryButton(title: "Elegir la carpeta de Calibre", systemImage: "folder", action: choose)
                .disabled(blocked != nil)
        }
    }
}

/// Paso 2: lo que llega, antes de copiar nada.
private struct ReviewStep: View {
    let plan: CalibreMigrationPlan
    /// Otro trabajo de toda la biblioteca está corriendo (auditoría 4): traer espera.
    var busyReason: String?
    /// iCloud no bajó toda tu biblioteca (auditoría 9, B10): se puede traer, pero lo digo antes.
    var cloudIncomplete = false
    let migrate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            SectionHeader("Lo que llega")
            StatTrio(items: [
                .init(value: plan.toImport.count.formatted(.number.locale(.gabinete)), label: "libros"),
                .init(value: plan.covers.formatted(.number.locale(.gabinete)), label: "portadas"),
                .init(value: plan.annotations.formatted(.number.locale(.gabinete)), label: "subrayados"),
            ])
            VStack(spacing: 0) {
                FactRow(label: "Series", value: "\(plan.series)")
                FactRow(label: "Ya estaban en tu Gabinete", value: "\(plan.alreadyHere.count)")
                FactRow(label: "Sin archivo en Calibre", value: "\(plan.withoutFiles.count)")
            }
            Text("Los subrayados de Calibre llegan a tu Cuaderno con su libro, y los pinto en el texto la primera vez que abres cada libro.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
            if plan.toImport.isEmpty {
                EmptyState(title: "Nada nuevo que traer", message: "Todo lo que tiene esta biblioteca ya está en tu Gabinete.")
            } else {
                if let busyReason {
                    ReasonLine(busyReason)
                } else if cloudIncomplete {
                    ReasonLine(EmptyCopy.calibreWhileCloudIncomplete)
                }
                PrimaryButton(title: "Traer \(plan.toImport.count.counted("libro", "libros"))", fillsWidth: true, action: migrate)
                    .disabled(busyReason != nil)
            }
        }
    }
}

/// Paso 3: cómo fue.
private struct SummaryStep: View {
    let report: CalibreMigrationReport
    let finishTitle: String
    let finish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            SectionHeader("Terminé")
            Text("\(report.imported == 1 ? "Llegó" : "Llegaron") \(report.imported.counted("libro", "libros")) a tu Gabinete.")
                .font(.bookTitle)
            VStack(spacing: 0) {
                FactRow(label: "Subrayados", value: "\(report.annotations)")
                FactRow(label: "Ya estaban", value: "\(report.alreadyHere)")
                FactRow(label: "Sin archivo en Calibre", value: "\(report.withoutFiles.count)")
                FactRow(label: "No pude copiar", value: "\(report.failed.count)")
            }
            if !report.failed.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    SectionHeader("Revisa estos")
                    ForEach(Array(report.failed.enumerated()), id: \.offset) { _, item in
                        TitleDetailRow(title: item.title, detail: item.reason)
                    }
                }
            }
            if !report.withoutFiles.isEmpty {
                Text("Sin archivo: " + report.withoutFiles.prefix(Theme.Lists.preview).joined(separator: " · ") + (report.withoutFiles.count > Theme.Lists.preview ? "…" : ""))
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
            PrimaryButton(title: finishTitle, fillsWidth: true, action: finish)
        }
    }
}
