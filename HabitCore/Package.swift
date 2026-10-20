// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HabitCore",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "HabitCore",
            targets: ["HabitCore"]
        )
    ],
    targets: [
        .target(
            name: "HabitCore"
        ),
        .testTarget(
            name: "HabitCoreTests",
            dependencies: ["HabitCore"]
        )
    ]
)
