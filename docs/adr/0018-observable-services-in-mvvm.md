# @Observable Services are a sanctioned role in the MVVM target architecture

The MVVM target now recognises **three** `@Observable`-relevant roles, not two:
stateless `Sendable` Repositories, per-screen `@Observable` ViewModels, and
`@Observable` **Services** for cross-cutting / app-lifetime state (auth session,
user preferences, feature flags). A Service is `@MainActor @Observable`, built
once in `AppDependencies`, injected via `@Environment`, and observed by many
screens — the same wiring as a repository, but stateful. `@Observable` is
therefore allowed on ViewModels **and** Services, never on a Repository.

## Why

Real MVVM projects already do this — `kick-apple-tv` ships `AuthService` and
`PreferencesService` as `@Observable` services alongside its MVVM screens. But the
MVVM docs and `swift-mvvm-architecture` skill asserted "ViewModels are the **only**
`@Observable` type in user code", and the audit grep suite flagged every non-VM
`@Observable` as a BLOCKER. The binary `architecture: MVVM` flag plus that claim
caused Claude to steer users *away* from a correct, explicitly requested pattern —
the failure that prompted this ADR. Documenting Services as first-class closes the
gap: a shared, persistent state holder no longer reads as MVVM drift.

## Considered options

- **Add an "override" mechanism** so a user could request an MV service in an MVVM
  project as a deviation. Rejected — the evidence showed a service is not a
  deviation here but an established, correct, coexisting pattern. An override
  framing would mislabel legitimate architecture as an exception.
- **Leave MVVM as VM-only; treat services as MV-only.** Rejected — it does not
  describe how modern MVVM apps actually manage cross-cutting state, and forces
  either god-ViewModels or duplicated state across screens.

## Consequences

- The guardrail that distinguishes the roles must hold: a Service is app-scoped
  shared state; a ViewModel is per-screen state owned via `@State`. A Service is
  **not** a shortcut to skip the ViewModel layer. This is stated in
  `swift-mvvm-architecture` and the MVVM `coding-standards.md`.
- `swift-code-review` inherits the change because it reads these docs — no
  separate reviewer edit. Audit greps now allow-list `Service`; a `@Observable`
  Repository remains a BLOCKER.
- Consuming projects should describe their real split in `CLAUDE.md` rather than
  relying on the bare `architecture: MVVM` flag, which cannot express the
  MVVM-screens + MV-services shape on its own.
