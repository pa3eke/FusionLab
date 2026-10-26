// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "FusionLab", platforms: [.macOS(.v14)], products: [.executable(name: "FusionLab", targets: ["FusionLab"])], targets: [
 .target(name: "YSFCodec", publicHeadersPath: "include"),
 .executableTarget(name: "FusionLab", dependencies: ["YSFCodec"],resources:[.copy("Resources/YSFHosts.txt")])
], cxxLanguageStandard: .cxx17)
