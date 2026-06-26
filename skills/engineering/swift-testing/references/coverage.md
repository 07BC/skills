# Swift Testing — raising coverage

Writing a correct test and raising coverage are different jobs. The rest of this skill is about correctness. This file is about *yield*: given a dark codebase, where do you point the next test so the suite catches the most regressions per unit of effort?

Read this when the task is "increase coverage", "add tests for this module", or "the suite doesn't catch enough".

## Measure first — never infer

Coverage is an empirical signal. Do not guess which files are tested; measure.

```
xcodebuild test -scheme {Scheme} \
  -destination 'platform={platform} Simulator,id={SIM_ID}' \
  -testPlan {plan} -parallel-testing-enabled NO -enableCodeCoverage YES \
  -resultBundlePath /tmp/cov.xcresult
xcrun xccov view --report /tmp/cov.xcresult > /tmp/filecov.txt
```

Regenerate after each batch of tests and record the **delta**. A batch that doesn't move the number tested the wrong thing (or duplicated existing coverage — re-read the file first).

## The denominator trap

Line coverage counts every line in the target, **including SwiftUI `View` bodies that unit tests do not exercise by design** (that is XCUITest territory). A 20% app-coverage number is often "the logic is 80% covered and the view layer is 0%" — not "80% of the logic is untested".

- **Chase logic, not view bodies.** Filters, formatters, decoders, models, services, the parts of ViewModels that aren't `body`.
- **Stop climbing a file** when the remaining uncovered lines are view bodies, `Console.*`/logging, or `#Preview`s. Note them and move on — forcing those to "covered" is busywork that doesn't catch regressions.
- Coverage is usually **bimodal**: newer injectable code (repositories, services with protocol seams) is well-covered; the legacy shell (composition root, navigation, push-driven transports) is dark. The dark legacy is where the regressions hide *and* where the seams are missing — see "Fix the seam first".

## 100% is not the target — name the uncoverable remainder

Line coverage has a ceiling below 100% that no honest test can close. A "get to 100%" mandate pushes you to write exactly the tautological tests this skill bans (`SKILL.md`, "When NOT to write a test") just to light up these lines:

- **Dead / unreachable code** — a branch shadowed by an earlier one (a deeplink case the prior regex always matches first), a `RawRepresentable.init(from:)` the compiler's synthesised `Decodable` always wins over. No test reaches it; only deleting the dead code moves the number.
- **Synthesised conformances** — `Codable`/`Equatable`/`Hashable` the compiler generated. A test for them tests the compiler.
- **Memberwise `init`s and pure property storage** — construction *is* the test; building the value and reading back the field you just set is tautological.
- **Coverage-tool quirks** — e.g. a stored-property default initialiser counted as its own uncovered region.

**Stop at logic coverage; list the uncoverable remainder** (dead code → propose deletion, synthesised → skip, quirks → note) instead of manufacturing tests for it. If the task literally says "100%", report the realistic ceiling and what sits under it rather than padding the number — that padding is the false confidence this file exists to prevent.

## Prioritise by yield: `uncovered lines × blast radius`

Rank targets, don't sweep alphabetically. For each dark/partial file:

- **Uncovered lines** — from `xccov` (`(uncovered, total)` per file).
- **Blast radius** — grade with `gitnexus_impact` (`mcp__gitnexus__impact`, direction `upstream`). Auth/token, playback, decode, navigation = high; a date formatter or debug helper = low. See `references/tooling.md`.

Then attack in this order — cheapest, safest yield first:

1. **Pure-logic types with 0% coverage** — filters, formatters, decoders, model transforms. Deterministic input→output, no dependencies. Parameterise (`@Test(arguments:)`). Highest % per unit of effort, near-zero risk.
2. **Decode / error / nil / empty branches** — most suites cover the happy path only. Malformed JSON, missing/null fields, empty collections, thrown errors, cancellation. These are where real bugs ship.
3. **Services with real logic** — e.g. websocket frame construction, request building, retry/guard logic. Inject the transport; assert the frames/requests produced.
4. **ViewModel error/edge branches** — via the injected protocol dependency. Mirror an already-well-covered sibling suite's setup.
5. **Seam-unlocked coverage** — code you *cannot* test today because a dependency is a `static` call or a non-injected concrete type. Make it injectable (see below), then test.

## Fix the seam first

If you can't inject a stub, the injection point is the bug — not the test. A ViewModel that calls `SomeClient.staticMethod(...)` or constructs a concrete dependency inline cannot be tested in isolation.

1. Make the dependency injectable (protocol + initialiser injection), keeping behaviour identical.
2. **Run `gitnexus_impact` before the refactor.** If blast radius is LOW/MEDIUM, do it and add the test. If HIGH/CRITICAL, **surface it as a finding and stop** — don't bury a risky production refactor inside a "add tests" task.
3. Then write the test through the new seam.

Never reach for a singleton or a real network call to "make it testable" — that is the opposite of coverage (a flaky integration test that races on CI). See the "Never touch process-global state" ban in `SKILL.md`.

## What "more coverage" must never mean

- Not a weaker assertion to make a crashing test green (see `weaker-after-crash` in `references/anti-patterns.md`).
- Not a test that asserts the mock's own configured return (see the `pass-through-mock` ban in `SKILL.md`).
- Not `Task.sleep`/polling to get an async path to "run" (see `SKILL.md` hard-stops).

A coverage number that goes up while the suite's regression-catching power stays flat is worse than no change — it manufactures false confidence. Every new test must answer: *what regression does this catch?*

## Before you declare a coverage task done

A green local suite is necessary but not sufficient. These three traps once shipped a "done, 199 tests passing" claim sitting on top of a package that did not compile in CI — and a source edit that broke the app build:

- **Build the package the way CI builds it.** A suite that passes inside the app workspace can sit on an SPM package that fails to compile *standalone* — the mode CI uses (`xcodebuild -scheme {Package}` with a fresh dependency resolve), which also floats dependency versions independently of the app's pin. Before committing: build the standalone scheme, and if a package CI workflow exists, confirm it is green — don't infer it from the workspace build.
- **A compile error against a dependency's API is a version smell, not a call site to patch.** If test or source code won't build because a dependency's signature differs (an enum case gained/lost a parameter), do **not** edit the call to match whatever version happened to resolve — that can make the package compile while breaking the app, which pins a different version. Check the resolved version against the app's pin first and align them; don't paper over the divergence at the call site.
- **Local toolchain ≠ CI toolchain.** A clean local pass can still fail in CI on a different Xcode/Swift build (or a CI `xcode-version: '26'` that silently resolves to an RC). "Clean local build is truth" holds *for that toolchain* — it is not a guarantee for CI's. When CI fails on code that builds locally, suspect the toolchain delta before re-editing the code.
