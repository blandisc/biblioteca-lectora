import LectoraCore
import SwiftUI

/// Reglas tuyas para autores y etiquetas (como los mapas de Calibre). Se
/// aplican a lo que llega de archivos e internet; lo que escribes a mano no.
struct RulesScreen: View {
    enum Kind: String, CaseIterable, Identifiable {
        case author, tag
        var id: Self { self }
        var title: String { self == .author ? "Autor" : "Etiqueta" }
    }

    @EnvironmentObject private var model: AppModel
    @State private var kind: Kind = .author
    @State private var from = ""
    @State private var to = ""
    @State private var appliedMessage: String?

    private var rules: MetadataRules { model.library.rules }

    var body: some View {
        Form {
            Section {
                Picker("Tipo", selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                TextField(kind == .author ? "Cuando diga (p. ej. Gabo)" : "Cuando diga (p. ej. Fiction)", text: $from)
                    .autocorrectionDisabled()
                TextField(kind == .author ? "Cambiar por" : "Cambiar por (vacío: quitarla)", text: $to)
                    .autocorrectionDisabled()
                Button("Agregar regla") { add() }
                    .disabled(from.trimmingCharacters(in: .whitespaces).isEmpty
                              || (kind == .author && to.trimmingCharacters(in: .whitespaces).isEmpty))
            } header: {
                Text("Nueva regla")
            } footer: {
                Text("Sin importar mayúsculas ni acentos. Se aplican a los libros que importes y a los datos de internet.")
            }

            if !rules.authors.isEmpty {
                Section("Autores") {
                    ForEach(rules.authors) { rule in row(rule) }
                        .onDelete { remove(at: $0, kind: .author) }
                }
            }
            if !rules.tags.isEmpty {
                Section("Etiquetas") {
                    ForEach(rules.tags) { rule in row(rule) }
                        .onDelete { remove(at: $0, kind: .tag) }
                }
            }
            if !rules.isEmpty {
                Section {
                    Button("Aplicar a toda la biblioteca") {
                        let count = model.library.applyRulesToLibrary()
                        appliedMessage = count == 1 ? "Cambió 1 libro." : "Cambiaron \(count) libros."
                    }
                }
            }
        }
        .navigationTitle("Reglas")
        .alert("Reglas aplicadas", isPresented: Binding(
            get: { appliedMessage != nil },
            set: { if !$0 { appliedMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appliedMessage ?? "")
        }
    }

    private func row(_ rule: MetadataRules.Rule) -> some View {
        LabeledContent(rule.from, value: rule.to.isEmpty ? "Quitar" : rule.to)
    }

    private func add() {
        var updated = rules
        let rule = MetadataRules.Rule(from: from.trimmingCharacters(in: .whitespaces), to: to.trimmingCharacters(in: .whitespaces))
        switch kind {
        case .author: updated.authors.append(rule)
        case .tag: updated.tags.append(rule)
        }
        model.library.saveRules(updated)
        from = ""
        to = ""
    }

    private func remove(at offsets: IndexSet, kind: Kind) {
        var updated = rules
        switch kind {
        case .author: updated.authors.remove(atOffsets: offsets)
        case .tag: updated.tags.remove(atOffsets: offsets)
        }
        model.library.saveRules(updated)
    }
}
