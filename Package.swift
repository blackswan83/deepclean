// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeepClean",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DeepClean", targets: ["DeepClean"])
    ],
    targets: [
        .executableTarget(
            name: "DeepClean",
            path: "DeepClean",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-enable-implicit-dynamic"])
            ]
        )
    ]
)
