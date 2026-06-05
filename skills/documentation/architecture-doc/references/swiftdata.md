# Reference: SwiftData Patterns

## Key types to find and document

| Type | Role |
|------|------|
| `@Model` classes | Persistent entities — list all, note relationships |
| `ModelContainer` | Created once at app entry, holds schema + config |
| `ModelContext` | Per-operation scratch pad, inserted into environment |
| `@Query` | SwiftUI property wrapper — auto-updates view on change |

## What to look for

```bash
grep -r "@Model" . --include="*.swift" -l
grep -r "ModelContainer" . --include="*.swift" -l
grep -r "ModelContext" . --include="*.swift" -l
grep -r "VersionedSchema\|SchemaMigrationPlan" . --include="*.swift" -l
```

## Bootstrap pattern

```swift
// App entry — document the actual schema and config used
@main
struct MyApp: App {
    let container: ModelContainer = {
        let schema = Schema([UserSession.self, SessionHistory.self])
        let config = ModelConfiguration("myapp", schema: schema)
        return try! ModelContainer(for: schema, configurations: config)
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
```

## Migration — what to check for

```swift
// Versioned schemas signal intentional migration planning
enum KickSchemaV1: VersionedSchema { ... }
enum KickSchemaV2: VersionedSchema { ... }

struct KickMigrationPlan: SchemaMigrationPlan {
    static var stages: [MigrationStage] = [
        .lightweight(fromVersion: KickSchemaV1.self, toVersion: KickSchemaV2.self)
    ]
}
```

If no migration plan exists but the app has shipped, flag this as a risk:
`⚠️ TODO: No migration plan found — adding @Model properties without a
VersionedSchema will cause crashes on update for existing users.`

## Common gotchas

- `@Model` classes must be `final` — flag any that aren't.
- `ModelContext` is not `Sendable` — must be used on `@MainActor` or
  passed carefully. Flag any cross-actor usage.
- `@Query` only works inside SwiftUI views, not in services/models.
- Relationships with `.cascade` delete rules can silently delete data —
  document all delete rules if present.
- In-memory stores for testing: `ModelConfiguration(isStoredInMemoryOnly: true)`
  — check if tests use this pattern.
