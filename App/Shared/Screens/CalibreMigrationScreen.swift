import LectoraCore
import SwiftUI
import UniformTypeIdentifiers

/// Traer tu biblioteca de Calibre (una sola vez): elegir la carpeta, ver qué
/// llega, traerlo y el resumen. Calibre no se toca: se copia (arquitectura D3).
struct CalibreMigrationScreen: View {
    enum Step {
        case choose
        case reading
        case review(source: URL, plan: CalibreMigrationPlan)
        case migrating
        case done(CalibreMigrationReport)
    }

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .choose
    @State private var choosing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    switch step {
                    case .choose: ChooseStep { choosing = true }
                    case .reading: progress(title: "Leyendo tu biblioteca de Calibre…", value: nil)
                    case .review(let source, let plan): ReviewStep(plan: plan) { migrate(source: source, plan: plan) }
                    case .migrating:
                        let done = model.library.progress
                        progress(title: done.map { "Trayendo \($0.done) de \($0.total) libros…" } ?? "Trayendo…",
                                 value: model.library.progressFraction)
                    case .done(let report): SummaryStep(report: report) { dismiss() }
                    }
                }
                .screenContent()
            }
            .pushedScreen("Traer de Calibre")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !isMigrating { Button("Cerrar") { dismiss() } }
                }
            }
            .fileImporter(isPresented: $choosing, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result { read(url) }
            }
            .alert("No se pudo leer", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .interactiveDismissDisabled(isMigrating)
        }
    }

    private var isMigrating: Bool {
        if case .migrating = step { return true }
        return false
    }

    // MARK: Pasos

    private func progress(title: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text(title).font(.body)
            if let value { ThinProgress(value: value) } else { ProgressView() }
            Text("Puedes dejar la app abierta; no cierres esta hoja.")
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
    let choose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            SectionLabel(text: "Una sola vez")
            Text("Elige la carpeta de tu biblioteca de Calibre, la que tiene metadata.db (en Calibre: botón Biblioteca › Abrir la carpeta).")
                .font(.body)
            Text("Se copian tus libros con sus datos, portadas, series, etiquetas, calificaciones y los subrayados del visor de Calibre. Tu biblioteca de Calibre no se modifica. Desde ahí, Gabinete es el dueño del catálogo y mantiene cada metadata.opf al día: si vuelves a Calibre, su «Restaurar base de datos» la reconstruye.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
            PrimaryButton(title: "Elegir la carpeta de Calibre", systemImage: "folder", action: choose)
        }
    }
}

/// Paso 2: lo que llega, antes de copiar nada.
private struct ReviewStep: View {
    let plan: CalibreMigrationPlan
    let migrate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            SectionLabel(text: "Lo que llega")
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
            Text("Los subrayados de Calibre llegan a tu Cuaderno con su libro, y se pintan en el texto la primera vez que abres cada libro.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
            if plan.toImport.isEmpty {
                EmptyState(title: "Nada nuevo que traer", message: "Todo lo que tiene esta biblioteca ya está en tu Gabinete.")
            } else {
                PrimaryButton(title: "Traer \(plan.toImport.count) libros", fillsWidth: true, action: migrate)
            }
        }
    }
}

/// Paso 3: cómo fue.
private struct SummaryStep: View {
    let report: CalibreMigrationReport
    let finish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            SectionLabel(text: "Listo")
            Text(report.imported == 1 ? "Llegó 1 libro a tu Gabinete." : "Llegaron \(report.imported) libros a tu Gabinete.")
                .font(.bookTitle)
            VStack(spacing: 0) {
                FactRow(label: "Subrayados", value: "\(report.annotations)")
                FactRow(label: "Ya estaban", value: "\(report.alreadyHere)")
                FactRow(label: "Sin archivo en Calibre", value: "\(report.withoutFiles.count)")
                FactRow(label: "No se pudieron copiar", value: "\(report.failed.count)")
            }
            if !report.failed.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    SectionLabel(text: "Revisa estos")
                    ForEach(Array(report.failed.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                            Text(item.title).font(.rowTitle)
                            Text(item.reason).font(.footnote).foregroundStyle(Theme.secondaryInk)
                        }
                    }
                }
            }
            if !report.withoutFiles.isEmpty {
                Text("Sin archivo: " + report.withoutFiles.prefix(10).joined(separator: " · ") + (report.withoutFiles.count > 10 ? "…" : ""))
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
            PrimaryButton(title: "Ver mi biblioteca", fillsWidth: true, action: finish)
        }
    }
}
