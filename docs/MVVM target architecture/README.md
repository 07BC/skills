# SwiftUI MVVM Architecture Template

Generic, project-agnostic architecture template. Copy this folder to a new project and replace all `AppName` / `FeatureName` placeholders.

## Files

| File | Purpose |
|------|---------|
| `architecture.md` | Layer reference, dependency rules, composition root pattern |
| `coding-standards.md` | Swift 6 rules, style, prohibited patterns |
| `testing.md` | Swift Testing patterns, mock conventions, helper setup |
| `templates/AppDependencies.swift` | Composition root scaffold |
| `templates/EnvironmentServices.swift` | Environment entry points for repositories |
| `templates/AppEntry.swift` | `@main` App struct scaffold |
| `templates/FeatureRepository.swift` | Canonical stateless repository template |
| `templates/FeatureViewModel.swift` | Canonical ViewModel template |
| `templates/FeatureView.swift` | Canonical screen + view template |
| `templates/FeatureViewModelTests.swift` | Swift Testing ViewModel test template |
| `templates/FeatureRepositoryTests.swift` | Swift Testing repository test template |
| `templates/MockAPIClient.swift` | Mock HTTP client template |

## Quick start

1. Copy `target_architecture/` into new repo.
2. Rename placeholders: `AppName`, `FeatureName`, `APIClient`, `AppError`.
3. Scaffold `AppDependencies.swift`, `EnvironmentServices.swift`, `AppNameApp.swift` into the app target.
4. Add repositories one at a time following `FeatureRepository.swift`.
5. Add ViewModels one at a time following `FeatureViewModel.swift`.
6. Add views one at a time following `FeatureView.swift` (screen + view pair).
7. Tests follow `FeatureViewModelTests.swift` (primary) and `FeatureRepositoryTests.swift` (data layer).

## Invariants (never break these)

- Dependency arrows always point **inward** toward Domain.
- Domain never imports SwiftUI, UIKit, or Combine.
- `@Observable` is used on **ViewModels** (per-screen state) and **Services** (cross-cutting / app-lifetime state — auth, preferences, feature flags); repositories are stateless and never `@Observable`.
- Repositories are the **only** callers of the API client and storage layer.
- **Views construct their own ViewModel via `@State`**; repositories come from `@Environment`.
- ViewModels are **never** registered in `@Environment`.
- One protocol → always two conformers (production + mock).
- All new code compiles with `SWIFT_STRICT_CONCURRENCY=complete`.
