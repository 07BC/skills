# Reference: Project Setup Patterns

## What to look for in Package.swift

```swift
// Key fields to document
let package = Package(
    name: "...",
    platforms: [.iOS(.v18)],          // → deployment target
    products: [...],                   // → public library targets
    dependencies: [...],               // → third-party SPM deps
    targets: [...]                     // → local targets & test targets
)
```

Document every dependency with: name, version/branch, purpose, and whether
it is a runtime or dev-only dependency.

## Local Packages (`LocalPackages/`)

Common pattern at Kick and other teams: hardware-dependent or reusable
services are extracted into local Swift packages so they can be tested
independently without the main app target.

For each local package note:
- Its public API surface (exported types/protocols)
- Why it was extracted (testability, reuse, vendor patch like HaishinKit)
- How it is linked (static vs dynamic)

## Xcode Project vs SPM-only

If the repo uses a `.xcodeproj`:
```bash
find . -name "project.pbxproj" | xargs grep "productType" | sort -u
# Shows: application, unitTestBundle, uiTestBundle, framework, extensionKit
```

If SPM-only (Package.swift at root, no .xcodeproj), note this explicitly —
it changes how schemes, signing, and CI work.

## Capabilities & Entitlements

```bash
find . -name "*.entitlements" | xargs cat
```

Common ones to note: Push Notifications, Background Modes (audio, fetch,
remote-notification), App Groups, Associated Domains, Keychain Sharing.

## Build Configurations

Standard: Debug / Release. Non-standard configs (Staging, AdHoc, etc.)
signal a more complex deployment pipeline — document the differences
(bundle ID swapping, feature flags, API endpoints).

## Gotchas

- `ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES` on app extensions causes
  App Store rejection — flag if present.
- Local packages linked as **dynamic** frameworks add to launch time.
- `OTHER_SWIFT_FLAGS = -strict-concurrency=complete` in build settings
  means Swift 6 strict mode is enforced — relevant for Layer 5.
