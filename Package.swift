// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "async-request",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)
    ],
    products: [
        .library(name: "AsyncRequest", targets: ["AsyncRequest"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0"),
        .package(url: "https://github.com/vapor/vapor", from: "4.113.2"),
    ],
    targets: [
        .target(
            name: "AsyncRequest", dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Vapor", package: "Vapor"),
            ]),
        .testTarget(
            name: "AsyncRequestTests",
            dependencies: ["AsyncRequest"]),
    ]
)
