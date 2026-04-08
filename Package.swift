// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MeasureAnything",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MeasureAnythingCore", targets: ["MeasureAnythingCore"]),
        .library(name: "MeasureAnythingTaxonomy", targets: ["MeasureAnythingTaxonomy"])
    ],
    targets: [
        .target(
            name: "MeasureAnythingCore",
            path: "MeasureAnythingApp/Core/Conversion",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "MeasureAnythingTaxonomy",
            path: "MeasureAnythingApp/Core/Taxonomy",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MeasureAnythingCoreTests",
            dependencies: ["MeasureAnythingCore"]
        ),
        .testTarget(
            name: "MeasureAnythingTaxonomyTests",
            dependencies: ["MeasureAnythingTaxonomy"]
        )
    ]
)

