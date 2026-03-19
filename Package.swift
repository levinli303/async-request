// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "async-request",
    platforms: [
        .macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)
    ],
    products: [
        .library(name: "AsyncRequest", targets: ["AsyncRequest"]),
    ],
    traits: [
        .default(enabledTraits: ["AsyncHTTPClient"]),
        .trait(name: "AsyncHTTPClient", description: "Use AsyncHTTPClient as the HTTP backend"),
        .trait(name: "URLSession", description: "Use URLSession as the HTTP backend"),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0"),
    ],
    targets: [
        .target(
            name: "AsyncRequest",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client", condition: .when(traits: ["AsyncHTTPClient"])),
            ],
            swiftSettings: [
                .define("USE_URL_SESSION", .when(traits: ["URLSession"])),
            ]
        ),
        .testTarget(
            name: "AsyncRequestTests",
            dependencies: ["AsyncRequest"]),
    ]
)
