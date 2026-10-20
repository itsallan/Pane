// swift-tools-version: 6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "PaneKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Playback", targets: ["Playback"]),
        .library(name: "Data", targets: ["Data"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "PlayerFeature", targets: ["PlayerFeature"]),
        .library(name: "LibraryFeature", targets: ["LibraryFeature"]),
        .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
        .library(name: "PlaybackTesting", targets: ["PlaybackTesting"]),
    ],
    dependencies: [
        // VLCKit 4 is pre-release and its delegate API changes between builds, so pin exactly.
        .package(url: "https://code.videolan.org/videolan/VLCKit.git", exact: "4.0.0-a25"),
    ],
    targets: [
        .target(name: "Domain", swiftSettings: swiftSettings),
        .target(
            name: "Playback",
            dependencies: ["Domain", .product(name: "VLCKit", package: "VLCKit")],
            swiftSettings: swiftSettings
        ),
        .target(name: "Data", dependencies: ["Domain"], swiftSettings: swiftSettings),
        .target(name: "DesignSystem", swiftSettings: swiftSettings),
        .target(name: "PlayerFeature", dependencies: ["Domain", "DesignSystem"], swiftSettings: swiftSettings),
        .target(name: "LibraryFeature", dependencies: ["Domain", "DesignSystem"], swiftSettings: swiftSettings),
        .target(name: "SettingsFeature", dependencies: ["Domain", "DesignSystem"], swiftSettings: swiftSettings),
        .target(name: "PlaybackTesting", dependencies: ["Domain"], swiftSettings: swiftSettings),

        .testTarget(name: "DomainTests", dependencies: ["Domain", "PlaybackTesting"], swiftSettings: swiftSettings),
        .testTarget(name: "PlaybackTests", dependencies: ["Playback"], swiftSettings: swiftSettings),
        .testTarget(name: "DataTests", dependencies: ["Data"], swiftSettings: swiftSettings),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"], swiftSettings: swiftSettings),
        .testTarget(name: "PlayerFeatureTests", dependencies: ["PlayerFeature", "PlaybackTesting"], swiftSettings: swiftSettings),
        .testTarget(name: "LibraryFeatureTests", dependencies: ["LibraryFeature", "PlaybackTesting"], swiftSettings: swiftSettings),
        .testTarget(name: "SettingsFeatureTests", dependencies: ["SettingsFeature", "PlaybackTesting"], swiftSettings: swiftSettings),
        .testTarget(name: "PlaybackTestingTests", dependencies: ["PlaybackTesting"], swiftSettings: swiftSettings),
    ]
)
