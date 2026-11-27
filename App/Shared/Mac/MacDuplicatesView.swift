#if os(macOS)
import LectoraCore
import SwiftUI

/// Posibles duplicados (CB-3): cada grupo con sus libros lado a lado. Eliges cuál se queda y
/// «Juntar en uno» le pasa los formatos que no tenía, sus datos, subrayados y marcadores;
/// «No son el mismo» no lo vuelve a proponer.
struct MacDuplicatesView: View {
    @ObservedObject var library: LibraryStore
    /// El que se queda en cada grupo (por omisión, el que tiene subrayados o avance, luego EPUB).
    @State private var keep: [UUID: UUID] = [:]
    @State private var confirming: [Book]?
    @State private var notice: String?

    var body: some View {
        let groups = library.duplicateGroups()
        List {
            if let notice {
                Text(notice).foregroundStyle(Theme.secondaryInk)
            }
            ForEach(groups, id: \.first?.id) { group in
                Section {
                    ForEach(group) { book in row(book, in: group) }
                } header: {
                    Text(group[0].title).font(.rowTitle).foregroundStyle(Theme.ink).lineLimit(1).truncationMode(.tail)
                } footer: {
                    HStack {
                        Spacer()
                        Button("No son el mismo") { library.dismissDuplicates(group) }
                        Button("Juntar en uno…") { confirming = group }
                            .macMainAction()
                    }
                }
            }
        }
        .macPaper()
        .overlay {
            if groups.isEmpty {
                MacEmptyState(title: EmptyCopy.noDuplicates.title, message: EmptyCopy.noDuplicates.message, systemImage: "checkmark.circle")
            }
        }
        .navigationTitle(Duplicates.title)
        .navigationSubtitle(groups.isEmpty ? "" : groups.count.counted("grupo", "grupos"))
        .confirmationDialog(confirmTitle, isPresented: Binding(
            get: { confirming != nil }, set: { if !$0 { confirming = nil } }
        ), titleVisibility: .visible) {
            if let group = confirming {
                Button("Juntar en «\(keeper(of: group)?.title ?? "")»") { merge(group) }
            }
            Button("Dejarlos separados", role: .cancel) {}
        } message: {
            Text(confirming.map(confirmMessage) ?? "")
        }
    }

    private func row(_ book: Book, in group: [Book]) -> some View {
        let highlights = AnnotationStore.shared.annotations(forBook: book.id).count
        let chosen = keeper(of: group)?.id == book.id
        return Button { keep[group[0].id] = book.id } label: {
            HStack(spacing: Theme.Space.l) {
                ChoiceMark(selected: chosen)
                TitleDetailRow(title: book.title, detail: details(book, highlights: highlights)) {
                    if chosen { Text("Se queda").foregroundStyle(Theme.ink) }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    /// «Julio Cortázar · EPUB · 12 subrayados · agregado 3 oct 2024».
    private func details(_ book: Book, highlights: Int) -> String {
        [book.authors.joined(separator: ", ").nonEmpty,
         book.formats.joined(separator: " · ").nonEmpty,
         highlights > 0 ? highlights.counted("subrayado", "subrayados") : nil,
         book.readingStatus == .toRead ? nil : (book.readingStatus == .finished ? "leído" : "empezado"),
         book.addedAt.map { "agregado \($0.esShort)" }]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private func keeper(of group: [Book]) -> Book? {
        let counts = Dictionary(uniqueKeysWithValues: group.map { ($0.id, AnnotationStore.shared.annotations(forBook: $0.id).count) })
        let id = keep[group[0].id] ?? DuplicateFinder.preferred(group, highlights: counts)
        return group.first { $0.id == id }
    }

    private var confirmTitle: String {
        guard let group = confirming else { return "" }
        return "¿Juntar \(group.count.counted("libro", "libros")) en uno?"
    }

    private func confirmMessage(_ group: [Book]) -> String {
        guard let keeper = keeper(of: group) else { return "" }
        let others = group.filter { $0.id != keeper.id }
        let newFormats = Set(others.flatMap(\.formats)).subtracting(keeper.formats).sorted()
        var lines = ["Se queda «\(keeper.title)» (\(keeper.formats.joined(separator: " · ")))."]
        if !newFormats.isEmpty { lines.append("Gana \(newFormats.joined(separator: " y ")) en su misma carpeta.") }
        lines.append("Sus datos se completan con los de los otros, y sus subrayados y marcadores pasan a este.")
        lines.append("Los archivos repetidos van a la Papelera, de donde se pueden recuperar.")
        return lines.joined(separator: " ")
    }

    private func merge(_ group: [Book]) {
        guard let keeper = keeper(of: group) else { return }
        do {
            let report = try library.merge(keep: keeper.id, others: group.map(\.id).filter { $0 != keeper.id })
            var parts = ["Junté «\(keeper.title)»"]
            if !report.addedFormats.isEmpty { parts.append("ahora con \(report.addedFormats.joined(separator: " y "))") }
            if report.movedHighlights > 0 { parts.append(report.movedHighlights.counted("subrayado pasó", "subrayados pasaron")) }
            if report.trashed > 0 { parts.append(report.trashed.counted("archivo a la Papelera", "archivos a la Papelera")) }
            notice = parts.joined(separator: " · ") + "."
        } catch {
            notice = "No pude juntar «\(keeper.title)»: \(error.localizedDescription)"
        }
        keep[group[0].id] = nil
    }
}
#endif
