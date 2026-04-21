// swift-tools-version: 5.9
import PackageDescription
import Foundation

let sparkleFrameworkPath = "Frameworks/Sparkle.framework"
let hasSparkleFramework = FileManager.default.fileExists(atPath: sparkleFrameworkPath)

let package = Package(
    name: "BreakReminder",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "BreakReminder",
            path: "BreakReminder",
            swiftSettings: hasSparkleFramework ? [
                .unsafeFlags(["-F", "Frameworks"])
            ] : [],
            linkerSettings: hasSparkleFramework ? [
                .unsafeFlags([
                    "-F", "Frameworks",
                    "-framework", "Sparkle",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ] : []
        )
    ]
)
