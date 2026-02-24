// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BreakReminder",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "BreakReminder",
            path: "Sources/BreakReminder",
            exclude: ["Resources"]
        )
    ]
)
