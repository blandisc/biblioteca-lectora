#if os(macOS)
import LectoraCore
import SwiftUI

/// Renombrar o fusionar un autor, una serie o una etiqueta en toda la biblioteca (CB-2).
/// Escribir un nombre que ya existe es fusionar; los nombres parecidos («Cortázar, Julio»,
/// «J. Cortázar») vienen marcados para juntarse de una vez. ⌘Z lo deshace.
struct MacCatalogSheet: View {
    struct Target: Identifiable {
        let field: CatalogRename.Field
        let value: String
        var id: String { "\(field.rawValue):\(value)" }
    }

    let target: Target
    /// Todos los valores de ese campo con cuántos libros tienen cada uno.
    let values: [(String, Int)]
    let library: LibraryStore
    /// Al terminar, con el nombre nuevo (para seguir viendo lo mismo en la barra lateral).
    let done: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
    @State private var name = ""
    @State private var joined: Set<String> = []
    @State private var failed: [String] = []

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var lookalikes: [String] { CatalogRename.lookalikes(of: target.value, among: values.map(\.0)) }
    /// El valor que ya existe con el nombre escrito (fusión), si no es el mismo de antes.
    private var existing: String? {
        values.map(\.0).first { CatalogRename.key($0) == CatalogRename.key(trimmed) && $0 != target.value }
    }
    private var sources: [String] { [target.value] + joined.sorted() }
    private var affected: Int {
        let names = Set(sources + [existing].compactMap { $0 })
        return values.filter { names.contains($0.0) }.reduce(0) { $0 + $1.1 }
    }
    private var merges: Bool { existing != nil || !joined.isEmpty }
    private var unchanged: Bool { trimmed.isEmpty || (trimmed == target.value && joined.isEmpty) }

    var body: some View {
        Form {
            Section {
                TextField(fieldName, text: $name).oneLine()
                    .onSubmit(apply)
                if let existing {
                    Text("Ya existe «\(existing)»: los junto en \(oneField).")
                        .foregroundStyle(Theme.secondaryInk)
                }
            } header: {
                Text("«\(target.value)»")
            }
            if !lookalikes.isEmpty {
                Section("Parecidos: ¿son el mismo?") {
                    ForEach(lookalikes, id: \.self) { other in
                        Toggle(isOn: Binding(
                            get: { joined.contains(other) },
                            set: { if $0 { joined.insert(other) } else { joined.remove(other) } }
                        )) {
                            Text(other)
                            Text(count(of: other)).foregroundStyle(Theme.secondaryInk)
                        }
                    }
                }
            }
            if !failed.isEmpty {
                Section("No pude cambiar estos") {
                    Text(failed.joined(separator: ", ")).foregroundStyle(Theme.secondaryInk)
                }
            }
        }
        .formStyle(.grouped)
        .formScreen()
        .frame(width: Theme.Mac.catalogSheet.width)
        .frame(minHeight: Theme.Mac.catalogSheet.height)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Dejar como está") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(merges ? "Juntar en \(affected.counted("libro", "libros"))" : "Renombrar en \(affected.counted("libro", "libros"))", action: apply)
                    .disabled(unchanged)
            }
        }
        .onAppear {
            name = target.value
            joined = Set(lookalikes)
        }
    }

    private var fieldName: String {
        switch target.field {
        case .author: "Autor"
        case .series: "Serie"
        case .tag: "Etiqueta"
        }
    }

    private var fieldNoun: String {
        switch target.field {
        case .author: "autor"
        case .series: "serie"
        case .tag: "etiqueta"
        }
    }

    /// «un solo autor», «una sola serie»: concuerda con lo que se junta.
    private var oneField: String {
        target.field == .author ? "un solo autor" : "una sola \(fieldNoun)"
    }

    private func count(of value: String) -> String {
        (values.first { $0.0 == value }?.1 ?? 0).counted("libro", "libros")
    }

    private func apply() {
        guard !unchanged else { return }
        let final = existing ?? trimmed
        let change = library.rename(CatalogRename(field: target.field, from: sources, to: final))
        if !change.originals.isEmpty {
            let library = library
            undoManager?.registerUndo(withTarget: library) { store in
                MainActor.assumeIsolated { store.restore(change) }
            }
            undoManager?.setActionName(merges ? "Juntar \(fieldNoun)" : "Renombrar \(fieldNoun)")
        }
        guard change.failed.isEmpty else {
            failed = change.failed
            return
        }
        done(final)
        dismiss()
    }
}
#endif
