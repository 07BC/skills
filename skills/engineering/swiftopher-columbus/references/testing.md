# Reference: Testing & CI Patterns

## Swift Testing — what to look for

```bash
# Swift Testing usage
grep -r "import Testing" . --include="*.swift" -l
grep -r "@Test\|@Suite\|#expect\|#require" . --include="*.swift" | wc -l

# XCTest legacy
grep -r "import XCTest\|XCTestCase" . --include="*.swift" -l
```

Document the ratio. Mixed codebases (XCTest + Swift Testing) are fine but
worth calling out — new tests should use Swift Testing.

## Swift Testing anatomy

```swift
import Testing

@Suite("StreamOrchestrator")
struct StreamOrchestratorTests {

    @Test("starts in idle state")
    func initialState() {
        let sut = StreamOrchestrator()
        #expect(sut.state == .idle)
    }

    @Test("transitions to live on successful publish",
          .tags(.publishing))
    func transitionToLive() async throws {
        let sut = StreamOrchestrator(publisher: MockPublisher())
        try await sut.startStream()
        #expect(sut.state == .live)
    }

    @Test("handles publish failure", arguments: [
        RTMPError.timeout,
        RTMPError.unauthorized
    ])
    func publishFailure(error: RTMPError) async throws {
        let publisher = MockPublisher(failWith: error)
        let sut = StreamOrchestrator(publisher: publisher)
        await #expect(throws: error) {
            try await sut.startStream()
        }
    }
}
```

## Mock/stub strategy

Look for how dependencies are faked:

| Pattern | Signal |
|---------|--------|
| Protocol + mock struct | Clean DI, easy to test |
| `@testable import` + subclass | Legacy ObjC pattern, fragile |
| `withDependencies` / custom DI | Point-free style |
| In-memory `ModelContainer` | SwiftData testing |
| `MockPublisher(failWith:)` via init | Preferred for actors |

Document the dominant pattern. Flag if services are not protocol-backed
(makes them untestable without subclassing).

## In-memory SwiftData in tests

```swift
@Suite("StreamHistory persistence")
struct StreamHistoryTests {
    var container: ModelContainer!

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: StreamHistory.self,
            configurations: config
        )
    }

    @Test("saves stream session")
    func saveSession() throws {
        let context = container.mainContext
        context.insert(StreamHistory(duration: 120))
        try context.save()
        let all = try context.fetch(FetchDescriptor<StreamHistory>())
        #expect(all.count == 1)
    }
}
```

## CI Pipeline — what to document

```bash
find . -name "*.yml" -path "*github/workflows*" | xargs cat 2>/dev/null
find . -name "Fastfile" | xargs cat 2>/dev/null
find . -name "Matchfile" | xargs cat 2>/dev/null
```

For each CI job document:
- Trigger (push, PR, schedule, manual)
- Xcode version pinned (`xcode-version` or `.xcode-version` file)
- Test scheme and destination
- Code signing method (match, manual, automatic)
- Artefacts produced (IPA, dSYM, test results)

## Code signing

| Method | Notes |
|--------|-------|
| Fastlane Match | Certs/profiles in git repo — document the git URL source (redacted) |
| Manual | Profile UUIDs hardcoded — brittle, flag for migration |
| Automatic | Fine for development, not for CI |
| Xcode Cloud | Built-in — note if used |

## Deployment / release checklist items to look for

- `agvtool` or Fastlane `increment_build_number` for build number automation
- `MARKETING_VERSION` set manually vs automated
- `.xcode-version` or `XCODE_VERSION` env var for reproducible builds
- dSYM upload step (Crashlytics, Sentry, etc.)
- Release notes automation (changelog from git log or PR titles)
