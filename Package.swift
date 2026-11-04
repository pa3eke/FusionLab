// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "FusionLab", platforms: [.macOS(.v14)], products: [.executable(name: "FusionLab", targets: ["FusionLab"])], targets: [
 .target(name: "YSFCodec", publicHeadersPath: "include"),
 .target(name: "MD380Codec", exclude:["vendor/COPYING","vendor/COPYING.LGPL2"], publicHeadersPath: "include"),
 .executableTarget(name: "FusionLab", dependencies: ["YSFCodec","MD380Codec"],resources:[.copy("Resources/YSFHosts.txt")])
], cxxLanguageStandard: .cxx17)
