// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BUS210MissionControl",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BUS210MissionControl", targets: ["BUS210MissionControl"]),
    ],
    targets: [
        .executableTarget(
            name: "BUS210MissionControl",
            path: "Sources/BUS210MissionControl"
        ),
    ],
    swiftLanguageModes: [.v5]
)
