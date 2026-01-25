// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NSMessenger",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NSMessenger",
            targets: ["NSMessenger"]),
    ],
    dependencies: [
        // SignalR Client for real-time messaging
        .package(url: "https://github.com/moozzyk/SignalR-Client-Swift.git", from: "0.8.0"),
        
        // Optional: Kingfisher for efficient image loading and caching
        // .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        .target(
            name: "NSMessenger",
            dependencies: [
                .product(name: "SignalRClient", package: "SignalR-Client-Swift"),
                // .product(name: "Kingfisher", package: "Kingfisher"),
            ]),
        .testTarget(
            name: "NSMessengerTests",
            dependencies: ["NSMessenger"]),
    ]
)