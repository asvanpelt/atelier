// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Atelier",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
    ],
    targets: [
        .executableTarget(
            name: "Atelier",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Atelier",
            resources: [.process("Resources")]
        ),
    ]
)
