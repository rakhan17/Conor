// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Conor",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Conor", targets: ["Conor"])],
    targets: [.executableTarget(name: "Conor", path: "Sources/Conor")]
)
