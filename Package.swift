import PackageDescription

let package = Package(
    name: "G3GridView",
    platforms: [
        .iOS(.v9),
    ],
    products: [
        .library(
            name: "GridView",
            targets: ["GridView"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "GridView",
            dependencies: [],
            path: "GridView"),
    ]
)
