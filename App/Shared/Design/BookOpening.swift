import SwiftUI

/// Transición de abrir un libro: la portada de la Mesa crece hasta volverse la
/// página (zoom de iOS 18). En versiones anteriores y en el Mac, la transición normal.
enum BookOpening {
    static let coverID = "portada-actual"
}

private struct BookOpeningNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var bookOpeningNamespace: Namespace.ID? {
        get { self[BookOpeningNamespaceKey.self] }
        set { self[BookOpeningNamespaceKey.self] = newValue }
    }
}

extension View {
    /// Marca la portada desde la que se abre el libro.
    @ViewBuilder
    func bookOpeningSource(in namespace: Namespace.ID?) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *), let namespace {
            self.matchedTransitionSource(id: BookOpening.coverID, in: namespace)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// El lector entra creciendo desde la portada.
    @ViewBuilder
    func bookOpeningDestination(in namespace: Namespace.ID?, enabled: Bool) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *), let namespace, enabled {
            self.navigationTransition(.zoom(sourceID: BookOpening.coverID, in: namespace))
        } else {
            self
        }
        #else
        self
        #endif
    }
}
