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
        .testTarget(name: "LectoraCoreTests", dependencies: ["LectoraCore"]),
    ]
)
