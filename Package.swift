// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JokersAndMarbles",
    platforms: [.iOS(.v17), .tvOS(.v17), .macOS(.v14)],
    products: [.library(name: "GameCore", targets: ["GameCore"])],
    targets: [.target(name: "GameCore"), .testTarget(name: "GameCoreTests", dependencies: ["GameCore"])]
)
