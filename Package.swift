// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KeyType",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "KeyType", targets: ["KeyType"])
    ],
    targets: [
        .target(name: "KeyTypeCore"),
        .executableTarget(name: "KeyType", dependencies: ["KeyTypeCore"]),
        .testTarget(name: "KeyTypeCoreTests", dependencies: ["KeyTypeCore"])
    ],
    swiftLanguageModes: [.v5]
)
