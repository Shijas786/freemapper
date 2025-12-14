// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AuroraMapper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AuroraMapper", targets: ["AuroraMapper"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AuroraMapper",
            path: "Sources",
            resources: [
                .process("Renderer/Shaders.metal")
            ]
        )
    ]
)
