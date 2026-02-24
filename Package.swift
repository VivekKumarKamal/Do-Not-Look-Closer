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
            exclude: ["Resources"],
            swiftSettings: [
                .unsafeFlags(["-F", "Frameworks"])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "Frameworks",
                    "-framework", "Sparkle",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        )
    ]
)
