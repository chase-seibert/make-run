// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MakeRun",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MakeRun", targets: ["MakeRun"])
    ],
    targets: [
        .executableTarget(
            name: "MakeRun",
            path: "Sources/MakeRun"
        ),
        .testTarget(
            name: "MakeRunTests",
            dependencies: ["MakeRun"],
            path: "Tests/MakeRunTests"
        )
    ]
)
