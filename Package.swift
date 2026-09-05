// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "SpeakLocal",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SpeakLocal", targets: ["SpeakLocal"])],
    targets: [.executableTarget(name: "SpeakLocal", path: "Sources/SpeakLocal")]
)
