// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LunchBell",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "LunchBell", targets: ["LunchBell"])],
    targets: [
        .executableTarget(name: "LunchBell")
    ]
)
