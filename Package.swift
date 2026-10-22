// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "HandTrack",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "HandTrack"),
        .testTarget(name: "HandTrackTests", dependencies: ["HandTrack"]),
    ]
)
