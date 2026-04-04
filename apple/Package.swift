// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SaveCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SaveCore",
            targets: ["SaveCore"]
        ),
    ],
    targets: [
        .target(
            name: "SaveCore",
            path: "Sources/SaveCore"
        ),
    ]
)
