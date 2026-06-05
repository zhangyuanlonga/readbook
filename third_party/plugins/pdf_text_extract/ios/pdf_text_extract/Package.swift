// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "pdf_text_extract",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "pdf-text-extract", targets: ["pdf_text_extract"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "pdf_text_extract",
            dependencies: []
        ),
    ]
)
