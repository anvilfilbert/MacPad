// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacPad",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacPad", targets: ["NotepadMac"])
    ],
    targets: [
        .target(
            name: "NotepadMacCore",
            path: "Sources/NotepadMacCore"
        ),
        .executableTarget(
            name: "NotepadMac",
            dependencies: ["NotepadMacCore"],
            path: "Sources/NotepadMac"
        ),
        .testTarget(
            name: "NotepadMacTests",
            dependencies: ["NotepadMacCore"],
            path: "Tests/NotepadMacTests"
        )
    ]
)
