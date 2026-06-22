# Common security anti-patterns

The highest-frequency mistakes in generated and hand-written Swift security code,
each with the corrective pattern. Scan for these during review; any match is a
finding.

## 1. Secrets in `UserDefaults` / `@AppStorage` / plist

```swift
// ❌ Plaintext, readable from an unencrypted backup. OWASP "insecure data storage".
UserDefaults.standard.set(accessToken, forKey: "token")
@AppStorage("apiKey") var apiKey = ""
```

```swift
// ✅ Keychain only (see keychain.md for the full add-or-update).
try keychain.save(Data(accessToken.utf8), service: "auth", account: "accessToken")
```

`@AppStorage` is a `UserDefaults` wrapper — same flaw. Never put credentials,
tokens, or keys in `Info.plist`, `.xcconfig`, or `NSCoding` archives either.

## 2. Hardcoded cryptographic keys / secrets

```swift
// ❌ A key shipped in the binary is extractable with `strings`.
let key = SymmetricKey(data: Data(base64Encoded: "aGFyZGNvZGVk…")!)
```

Generate keys at runtime and store them in the keychain (or derive them per the
KDF guidance in `cryptokit.md`). Fetch runtime secrets from a server over TLS; do
not bake them into the app.

## 3. `LAContext.evaluatePolicy` as the only gate

Covered in full in `biometrics.md`. The boolean is patchable; bind the secret to
the keychain with `SecAccessControl` instead.

## 4. Ignored `OSStatus`

```swift
// ❌ The add can fail silently (e.g. errSecDuplicateItem) and the secret is lost.
SecItemAdd(query as CFDictionary, nil)
```

Handle every status in a `switch` (see `keychain.md`).

## 5. Missing `kSecAttrAccessible`

An add dictionary with no accessibility attribute defaults to `WhenUnlocked`,
breaking background access and hiding the policy from review. Set it explicitly —
see `access-control.md`.

## 6. AES-GCM nonce reuse

```swift
// ❌ Same key + same nonce across messages leaks plaintext XOR.
for msg in messages { try AES.GCM.seal(msg, using: key, nonce: fixedNonce) }
```

```swift
// ✅ Let CryptoKit pick a fresh nonce each call.
for msg in messages { try AES.GCM.seal(msg, using: key) }
```

## 7. Raw ECDH shared secret used as a key

```swift
// ❌ Non-uniform distribution; requires an unsafe workaround that signals misuse.
let raw = sharedSecret.withUnsafeBytes { Data($0) }
```

```swift
// ✅ Derive through HKDF with domain-separating info (see cryptokit.md).
let key = sharedSecret.hkdfDerivedSymmetricKey(
    using: SHA256.self, salt: salt, sharedInfo: info, outputByteCount: 32)
```

## 8. Delete-then-add for updates

Replacing an item with `SecItemDelete` + `SecItemAdd` opens a race window and
destroys persistent references. Use add-or-update (`keychain.md`).

## 9. No first-launch keychain cleanup

Keychain items survive app uninstall, so a reinstall inherits stale tokens. On
first launch (gated by a `UserDefaults` flag), delete any orphaned items across the
classes you use before treating the install as fresh.

## 10. Secure Enclave without a simulator guard

`SecureEnclave.isAvailable` is `false` on the simulator, so an unguarded check
quietly exercises only the fallback path in testing. Guard with
`#if targetEnvironment(simulator)` (see `cryptokit.md`).

## OWASP touchpoints

These map to the Mobile Top 10 — chiefly insecure data storage (#1, #2, #5),
insufficient cryptography (#6, #7), and insecure authentication (#3). If a project
needs formal MASVS/MASTG evidence, map findings to those categories explicitly.
