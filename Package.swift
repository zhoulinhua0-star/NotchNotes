// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NotchNotes",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NotchNotes", targets: ["NotchNotes"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "NotchNotes",
            dependencies: [],
            path: "Sources/NotchNotes",
            exclude: [
                "EditorInteractionState.swift",
                "LocalImageStore.swift",
                "NotebookView.swift",
                "NoteStore.swift",
                "SystemSleepGuard.swift"
            ]
        ),
        .testTarget(
            name: "NotchNotesTests",
            dependencies: ["NotchNotes"],
            path: "Tests/NotchNotesTests",
            exclude: [
                "NoteStoreTests.swift",
                "SystemSleepGuardTests.swift"
            ]
        )
    ]
)
