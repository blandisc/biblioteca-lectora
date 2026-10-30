import SwiftUI

@main
struct LectoraApp: App {
    init() {
        #if os(iOS)
        // Títulos grandes en New York, como en el diseño elegido (v7).
        let base = UIFont.systemFont(ofSize: 34, weight: .bold)
        if let serif = base.fontDescriptor.withDesign(.serif) {
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: UIFont(descriptor: serif, size: 34)]
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.brand)
        }
    }
}
