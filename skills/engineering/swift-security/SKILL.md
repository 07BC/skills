---
name: swift-security
description: 'Conceptual guidance and reference for client-side security on Apple platforms — keychain, cryptography, and credential storage. Triggers when developers ask about: (1) storing secrets, tokens, passwords, or API keys, (2) Keychain Services / SecItem / kSecClass / OSStatus errors, (3) CryptoKit (AES-GCM, ChaChaPoly, HKDF, P256, Curve25519, HPKE), (4) Secure Enclave or hardware-backed keys, (5) biometric auth, LAContext, Face ID / Touch ID, SecAccessControl, (6) data protection / kSecAttrAccessible, (7) certificate pinning / SecTrust, (8) migrating secrets off UserDefaults / Info.plist / .xcconfig, (9) ATS / data protection questions.'
user-invocable: false
---
# Swift Security

## Overview

This skill is **read-only conceptual reference** for client-side security on
Apple platforms (iOS, macOS, tvOS, watchOS, visionOS): the Keychain, CryptoKit,
the Secure Enclave, biometric authentication, credential lifecycle, and
certificate trust. It explains the correct patterns and the invariants that must
never be broken. It is correctness-focused, not architecture-prescriptive — where
several valid options exist (P256 vs Curve25519, AES-GCM vs ChaChaPoly, actor vs
serial queue), it presents the trade-off rather than mandating one.

It does **not** cover server-side auth, App Transport Security policy, CloudKit
key management, or transport-layer TLS configuration beyond client-side
certificate pinning. For hands-on code review or fixes of concrete security bugs,
hand off to `swift-engineering` / `swift-code-review`.

## Core invariants

These are security invariants, not style preferences. Use "always" / "never" only
for these. Everything else is advisory.

1. **Never ignore the `OSStatus` from a `SecItem*` call.** Every call returns a
   status that must be handled — at minimum `errSecSuccess`, `errSecDuplicateItem`,
   `errSecItemNotFound`, and `errSecInteractionNotAllowed`. Silently discarding it
   is the root cause of most keychain bugs. → `references/keychain.md`

2. **Always use add-or-update; never delete-then-add.** On `errSecDuplicateItem`
   from `SecItemAdd`, follow up with `SecItemUpdate`. Delete-then-add opens a race
   window and destroys persistent references. → `references/keychain.md`

3. **Never use `LAContext.evaluatePolicy()` as a standalone auth gate.** It returns
   a `Bool` that is trivially patched at runtime. Bind biometrics to the keychain:
   store the secret behind `SecAccessControl` with `.biometryCurrentSet` and let the
   keychain prompt during `SecItemCopyMatching`. → `references/biometrics.md`

4. **Never store secrets in `UserDefaults`, `Info.plist`, `.xcconfig`, `@AppStorage`,
   or `NSCoding` archives.** These produce plaintext artefacts readable from
   unencrypted backups. The keychain is the only sanctioned store for credentials.
   → `references/anti-patterns.md`

5. **Never call `SecItem*` on `@MainActor`.** Each call is an IPC round-trip to
   `securityd` that blocks the calling thread. Route all keychain access through a
   dedicated `actor` (iOS 17+) or a serial queue on older targets.
   → `references/keychain.md`

6. **Always set `kSecAttrAccessible` explicitly.** The implicit default
   (`WhenUnlocked`) breaks background work and hides your security policy from code
   review. Choose the most restrictive class that fits the access pattern.
   → `references/access-control.md`

7. **Always set `kSecUseDataProtectionKeychain: true` on macOS targets.** Without it,
   queries route to the legacy file-based keychain, which ignores unsupported
   attributes and cannot use biometric protection or Secure Enclave keys. Mac
   Catalyst and iOS-on-Mac do this automatically. → `references/keychain.md`

8. **CryptoKit:** never reuse an AES-GCM nonce with the same key (a single reuse
   leaks the XOR of both plaintexts — prefer letting CryptoKit generate the nonce);
   never use a raw ECDH shared secret as a symmetric key (always derive through
   `HKDF`); use P256 or Curve25519 for signing and key agreement; never use
   `Insecure.MD5` / `Insecure.SHA1` for security purposes. → `references/cryptokit.md`

## Top anti-patterns — detection scan

When reviewing code, search for these. Any match is a finding.

| Search for | Anti-pattern | Severity | Reference |
| --- | --- | --- | --- |
| `UserDefaults`/`@AppStorage` + token/key/secret/password | Plaintext credential storage | CRITICAL | `anti-patterns.md` |
| Hardcoded base64/hex string (≥16 chars) used as a key | Hardcoded cryptographic key | CRITICAL | `anti-patterns.md` |
| `evaluatePolicy` with no nearby `SecItemCopyMatching` | LAContext-only biometric gate | CRITICAL | `biometrics.md` |
| `SecItemAdd` whose return value is discarded | Ignored `OSStatus` | HIGH | `keychain.md` |
| `SecItemAdd` dictionary with no `kSecAttrAccessible` | Implicit accessibility | HIGH | `access-control.md` |
| `AES.GCM.Nonce()` reused in a loop with one key | Nonce reuse | CRITICAL | `cryptokit.md` |
| `sharedSecret.withUnsafeBytes` (no `HKDF`) | Raw shared secret as key | HIGH | `cryptokit.md` |
| `kSecAttrAccessibleAlways` | Deprecated accessibility (iOS 12) | HIGH | `access-control.md` |
| `SecItemDelete` then `SecItemAdd` for an update | Delete-then-add race | HIGH | `keychain.md` |
| `SecureEnclave.isAvailable` with no simulator guard | Simulator false-negative | MEDIUM | `cryptokit.md` |
| `SecTrustEvaluate` (synchronous, deprecated) | Legacy trust evaluation | MEDIUM | `cryptokit.md` |

## Reference files

Load the minimum set for the question — never all at once.

- **`keychain.md`** — `SecItem*` CRUD, query dictionaries, `OSStatus` handling,
  add-or-update, actor isolation, macOS data-protection keychain.
- **`access-control.md`** — `kSecAttrAccessible` constants and selection,
  `SecAccessControl` flags, device-bound vs syncable.
- **`biometrics.md`** — keychain-bound Face ID / Touch ID, the `evaluatePolicy`
  bypass, enrolment-change detection.
- **`cryptokit.md`** — hashing, HMAC, AES-GCM / ChaChaPoly, `SymmetricKey`, HKDF,
  P256 / Curve25519, HPKE, Secure Enclave, certificate trust.
- **`anti-patterns.md`** — the highest-frequency security mistakes with ❌/✅ pairs.
- **`testing.md`** — protocol-based mocking, simulator vs device, CI keychain.

## Availability quick reference

Only versions that are stable and confirmed are listed. Confirm anything else
against current Apple documentation before relying on it.

| API | Minimum iOS |
| --- | --- |
| CryptoKit core: SHA-256/384/512, HMAC, AES-GCM, ChaChaPoly, HKDF, P256, Curve25519 | 13 |
| `SecureEnclave.P256` (signing / key agreement) | 13 |
| `SecAccessControl` with `.biometryCurrentSet` | 11.3 |
| `kSecUseDataProtectionKeychain` (macOS) | macOS 10.15 |
| HPKE (`HPKE.Sender` / `HPKE.Recipient`) | 17 |
| Swift concurrency `actor` for keychain isolation | 13 runtime, 17+ recommended |
