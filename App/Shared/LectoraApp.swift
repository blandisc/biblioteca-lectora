import SwiftUI

@main
struct LectoraApp: App {
    init() {
        #if os(iOS)
        // Títulos grandes (Ajustes, formularios) iguales a `Font.screenTitle`: New York 30
        // medium. Antes eran 34 en negrita y se veían distintos al resto de las pantallas.
        let base = UIFont.systemFont(ofSize: 30, weight: .medium)
        if let serif = base.fontDescriptor.withDesign(.serif) {
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: UIFont(descriptor: serif, size: 30)]
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
        }
        #if os(macOS)
        .defaultSize(width: Theme.Mac.defaultWindow.width, height: Theme.Mac.defaultWindow.height)
        #endif
    }
}
