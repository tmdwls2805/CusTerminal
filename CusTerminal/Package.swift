// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "CusTerminal",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "CusTerminal", targets: ["CusTerminal"]),
  ],
  dependencies: [
    // SwiftTerm — 터미널 뷰 + PTY + VT/ANSI 에뮬레이션.
    .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
  ],
  targets: [
    .executableTarget(
      name: "CusTerminal",
      dependencies: [
        .product(name: "SwiftTerm", package: "SwiftTerm"),
      ],
      path: "Sources/CusTerminal"
    ),
  ]
)
