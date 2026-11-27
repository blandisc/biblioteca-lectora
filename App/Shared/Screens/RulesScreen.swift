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
                .pickerStyle(.segmented) // ds-exception: control nativo de Form
                // Cada campo con su nombre arriba y la pista adentro: en la Mac, sin borde, se leían
                // como texto fijo.
                LabeledField(label: "Cuando diga", prompt: kind == .author ? "Por ejemplo, Gabo" : "Por ejemplo, Fiction", text: $from)
                    .autocorrectionDisabled()
                LabeledField(label: "Cambiar por", prompt: kind == .author ? "Por ejemplo, Gabriel García Márquez" : "Vacío: la quito", text: $to)
                    .autocorrectionDisabled()
                Button("Agregar regla") { add() }
                    .disabled(from.trimmingCharacters(in: .whitespaces).isEmpty
                              || (kind == .author && to.trimmingCharacters(in: .whitespaces).isEmpty))
            } header: {
                CapsText(text: "Nueva regla")
            } footer: {
                Text("Sin importar acentos ni mayúsculas. Se aplican a los libros que importes y a los datos de internet.")
            }

            if !rules.authors.isEmpty {
                Section {
                    ForEach(rules.authors) { rule in row(rule) }
                        .onDelete { remove(at: $0, kind: .author) }
                } header: {
                    CapsText(text: "Autores")
                }
            }
            if !rules.tags.isEmpty {
                Section {
                    ForEach(rules.tags) { rule in row(rule) }
                        .onDelete { remove(at: $0, kind: .tag) }
                } header: {
                    CapsText(text: "Etiquetas")
                }
            }
            if !rules.isEmpty {
                Section {
                    Button("Aplicar a toda la biblioteca") {
                        let count = model.library.applyRulesToLibrary()
                        appliedMessage = "\(count == 1 ? "Cambió" : "Cambiaron") \(count.counted("libro", "libros"))."
                    }
                }
            }
        }
        .formScreen()
        .navigationTitle("Reglas")
        .noticeAlert("Apliqué tus reglas", message: $appliedMessage, back: "Volver a Reglas")
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
