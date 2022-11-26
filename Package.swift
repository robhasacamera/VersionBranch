// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VersionBranch",
    products: [
        .executable(
            name: "VersionBranch",
            targets: ["VersionBranch"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "VersionBranch",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
    ])
