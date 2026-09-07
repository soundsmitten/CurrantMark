// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CurrantMark",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CurrantMarkApp", targets: ["CurrantMark"]),
        .executable(name: "currantmark", targets: ["CurrantMarkCLI"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-markdown.git",
            revision: "27b7fc1a19068bcea3d2072db0ce86360d1400ed"
        )
    ],
    targets: [
        .target(
            name: "CurrantMarkCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            resources: [.process("Resources/Style.css")]
        ),
        .executableTarget(
            name: "CurrantMark",
            dependencies: ["CurrantMarkCore"],
            exclude: ["Resources/Info.plist"]
        ),
        .executableTarget(
            name: "CurrantMarkCLI",
            dependencies: ["CurrantMarkCore"]
        ),
        .testTarget(
            name: "CurrantMarkTests",
            dependencies: ["CurrantMarkCore"]
        )
    ]
)
