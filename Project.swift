import ProjectDescription

let project = Project(
    name: "Macpardy",
    packages: [
        .remote(
            url: "https://github.com/weichsel/ZIPFoundation",
            requirement: .upToNextMinor(from: "0.9.19")
        ),
        // The buzzer core (#99). Local while the external-server work is in
        // progress; it moves to its own repo once that's done.
        .local(path: "Packages/MacpardyBuzzer"),
    ],
    targets: [
        .target(
            name: "Macpardy",
            destinations: [.mac],
            product: .app,
            bundleId: "jbkiv.Macpardy",
            deploymentTargets: .macOS("26.3"),
            infoPlist: .extendingDefault(with: [
                // Board packages (.macpardy): a zip with board.json and images/.
                "UTExportedTypeDeclarations": [
                    [
                        "UTTypeIdentifier": "jbkiv.macpardy.board",
                        "UTTypeDescription": "Macpardy Board",
                        "UTTypeConformsTo": ["public.data", "public.archive"],
                        "UTTypeTagSpecification": [
                            "public.filename-extension": ["macpardy"],
                        ],
                    ],
                ],
                "CFBundleDocumentTypes": [
                    [
                        "CFBundleTypeName": "Macpardy Board",
                        "CFBundleTypeRole": "Editor",
                        "LSHandlerRank": "Owner",
                        "LSItemContentTypes": ["jbkiv.macpardy.board"],
                    ],
                ],
            ]),
            sources: ["Macpardy/**/*.swift"],
            resources: [
                "Macpardy/Assets.xcassets",
                "Macpardy/Localizable.xcstrings",
                "Macpardy/Resources/Sounds/**",
                // Kept as a folder so the games can be listed from the bundle.
                .folderReference(path: "Macpardy/Resources/Games"),
            ],
            scripts: [
                // Fails the build on a bare `Button` / `.onTapGesture` in Views/ (#87).
                // Skipped with a warning when SwiftLint isn't installed.
                .pre(
                    script: """
                    export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
                    if command -v swiftlint >/dev/null 2>&1; then
                        cd "$SRCROOT" && swiftlint lint --quiet --strict --config .swiftlint.yml
                    else
                        echo "warning: SwiftLint is not installed, so the unlogged_tap check was skipped. Install it with: brew install swiftlint"
                    fi
                    """,
                    name: "SwiftLint",
                    basedOnDependencyAnalysis: false
                ),
            ],
            dependencies: [
                .package(product: "ZIPFoundation"),
                .package(product: "BuzzerCore"),
                .package(product: "BuzzerWebPage"),
            ],
            settings: .settings(
                base: [
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                    "CODE_SIGN_STYLE": "Automatic",
                    "CODE_SIGN_ENTITLEMENTS": "Config/Macpardy.entitlements",
                    "COMBINE_HIDPI_IMAGES": "YES",
                    "CURRENT_PROJECT_VERSION": "1",
                    "ENABLE_APP_SANDBOX": "YES",
                    "ENABLE_INCOMING_NETWORK_CONNECTIONS": "YES",
                    // NWListener needs network.client to accept connections from other devices
                    // in the sandbox; the app itself never connects out. See buzzer-protocol.md.
                    "ENABLE_OUTGOING_NETWORK_CONNECTIONS": "YES",
                    "ENABLE_PREVIEWS": "YES",
                    "ENABLE_RESOURCE_ACCESS_AUDIO_INPUT": "NO",
                    "ENABLE_RESOURCE_ACCESS_BLUETOOTH": "NO",
                    "ENABLE_RESOURCE_ACCESS_CALENDARS": "NO",
                    "ENABLE_RESOURCE_ACCESS_CAMERA": "NO",
                    "ENABLE_RESOURCE_ACCESS_CONTACTS": "NO",
                    "ENABLE_RESOURCE_ACCESS_LOCATION": "NO",
                    "ENABLE_RESOURCE_ACCESS_PRINTING": "NO",
                    "ENABLE_RESOURCE_ACCESS_USB": "NO",
                    "ENABLE_USER_SELECTED_FILES": "readwrite",
                    "GENERATE_INFOPLIST_FILE": "YES",
                    "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.games",
                    "INFOPLIST_KEY_NSHumanReadableCopyright": "",
                    "LD_RUNPATH_SEARCH_PATHS": [
                        "$(inherited)",
                        "@executable_path/../Frameworks",
                    ],
                    "MACOSX_DEPLOYMENT_TARGET": "26.3",
                    "MARKETING_VERSION": "0.5.0",
                    "PRODUCT_BUNDLE_IDENTIFIER": "jbkiv.Macpardy",
                    "REGISTER_APP_GROUPS": "YES",
                    "STRING_CATALOG_GENERATE_SYMBOLS": "YES",
                    "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
                    "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
                    "SWIFT_EMIT_LOC_STRINGS": "YES",
                    "SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY": "YES",
                    "SWIFT_VERSION": "5.0",
                ],
                configurations: [
                    .debug(
                        name: "Debug",
                        settings: [
                            "DEBUG": "1",
                            "ENABLE_TESTABILITY": "YES",
                            "GCC_OPTIMIZATION_LEVEL": "0",
                            "ONLY_ACTIVE_ARCH": "YES",
                            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
                            "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
                        ]
                    ),
                    .release(
                        name: "Release",
                        settings: [
                            "CODE_SIGN_INJECT_BASE_ENTITLEMENTS": "NO",
                            "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
                            "ENABLE_HARDENED_RUNTIME": "YES",
                            "ENABLE_NS_ASSERTIONS": "NO",
                            "SWIFT_COMPILATION_MODE": "wholemodule",
                        ]
                    ),
                ],
                defaultSettings: .recommended
            )
        ),
        .target(
            name: "MacpardyTests",
            destinations: [.mac],
            product: .unitTests,
            bundleId: "jbkiv.MacpardyTests",
            deploymentTargets: .macOS("26.3"),
            infoPlist: .default,
            sources: ["MacpardyTests/**/*.swift"],
            dependencies: [.target(name: "Macpardy")],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "5.0",
                    "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
                    "GENERATE_INFOPLIST_FILE": "YES",
                ]
            )
        ),
    ]
)
