// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Drifter",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Drifter", targets: ["Drifter"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Drifter",
            dependencies: [],
            path: "Sources/Drifter"
        ),
        .testTarget(
            name: "DrifterTests",
            dependencies: ["Drifter"],
            path: "Tests/DrifterTests"
        ),
    ]
)
