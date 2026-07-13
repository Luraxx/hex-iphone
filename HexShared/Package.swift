// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HexShared",
    platforms: [.iOS("18.0"), .macOS("13.0")],
    products: [
        .library(name: "HexShared", targets: ["HexShared"]),
    ],
    targets: [
        .target(name: "HexShared"),
    ]
)
