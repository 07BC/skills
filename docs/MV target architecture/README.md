# SwiftUI MV Architecture Template

Generic, project-agnostic architecture template. Copy this folder to a new project and replace all `AppName` / `FeatureName` placeholders.

## Files

| File | Purpose |
|------|---------|
| `architecture.md` | Layer reference, dependency rules, composition root pattern |
| `coding-standards.md` | Swift 6 rules, style, prohibited patterns |
| `testing.md` | Swift Testing patterns, mock conventions, helper setup |
| `templates/AppDependencies.swift` | Composition root scaffold |
| `templates/EnvironmentServices.swift` | Environment entry points |
| `templates/AppEntry.swift` | `@main` App struct scaffold |
| `templates/FeatureService.swift` | Canonical service + fetcher template |
| `templates/FeatureView.swift` | Canonical view template |
| `templates/FeatureServiceTests.swift` | Swift Testing service test template |
| `templates/MockAPIClient.swift` | Mock HTTP client template |

## Quick start

1. Copy `target_architecture/` into new repo.
2. Rename placeholders: `AppName`, `FeatureName`, `APIClient`, `AppError`.
3. Scaffold `AppDependencies.swift`, `EnvironmentServices.swift`, `AppNameApp.swift` into the app target.
4. Add services one at a time following `FeatureService.swift`.
5. Add views one at a time following `FeatureView.swift`.
6. Tests follow `FeatureServiceTests.swift`.

## Invariants (never break these)

- Dependency arrows always point **inward** toward Domain.
- Domain never imports SwiftUI, UIKit, or Combine.
- Services are the **only** writers of observable state.
- Views **never** construct services — injection only via `@Environment`.
- One protocol → always two conformers (production + mock).
- All new code compiles with `SWIFT_STRICT_CONCURRENCY=complete`.
