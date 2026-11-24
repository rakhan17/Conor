// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Conor",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Conor", targets: ["Conor"])],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4")
    ],
    targets: [
        .executableTarget(
            name: "Conor",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Conor"
        )
    ]
)
