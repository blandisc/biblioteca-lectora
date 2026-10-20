// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LectoraCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LectoraCore", targets: ["LectoraCore"]),
    ],
    targets: [
        .target(name: "LectoraCore"),
        // Sondeo con datos reales (lo corre la CI; ver scripts/sondeo).
        .executableTarget(name: "lectora-sondeo", dependencies: ["LectoraCore"]),
        .testTarget(name: "LectoraCoreTests", dependencies: ["LectoraCore"], resources: [.copy("Fixtures")]),
    ]
)
