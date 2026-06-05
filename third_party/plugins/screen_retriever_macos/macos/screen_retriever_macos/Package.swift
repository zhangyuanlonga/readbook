// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "screen_retriever_macos",
    platforms: [
        .macOS("10.15"),
    ],
    products: [
        .library(name: "screen-retriever-macos", targets: ["screen_retriever_macos"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "screen_retriever_macos",
            dependencies: []
        ),
    ]
)
