// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Echo",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Echo",
            path: "Sources/Echo"
        )
    ]
)
