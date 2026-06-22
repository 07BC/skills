# CryptoKit and trust

CryptoKit (iOS 13+) covers hashing, MAC, symmetric and public-key cryptography
with a safe-by-default API. Prefer it over the older Security framework wherever it
covers the use case. The notes below favour correctness; where several algorithms
are equally valid, pick by your interop and performance needs.

## Hashing and MAC

```swift
let digest = SHA256.hash(data: data)                 // SHA256/384/512 (iOS 13+)
let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
let ok = HMAC<SHA256>.isValidAuthenticationCode(mac, authenticating: data, using: key)
```

`isValidAuthenticationCode` is constant-time — use it instead of comparing tags
yourself. Never use `Insecure.MD5` or `Insecure.SHA1` for security purposes
(checksums against non-adversarial corruption only).

## Symmetric encryption — never reuse a nonce

AES-GCM and ChaChaPoly are authenticated. The cardinal rule: **never reuse a nonce
with the same key.** A single reuse leaks the XOR of the two plaintexts and can
expose the authentication key. The safest approach is to let CryptoKit generate the
nonce — omit the `nonce:` parameter and it produces a random one per call.

```swift
// ✅ CryptoKit generates a fresh random nonce.
let key = SymmetricKey(size: .bits256)
let sealed = try AES.GCM.seal(plaintext, using: key)
let recovered = try AES.GCM.open(sealed, using: key)
// To persist or transmit, store `sealed.combined` (nonce ‖ ciphertext ‖ tag) and
// rebuild with `try AES.GCM.SealedBox(combined: data)` before opening.
```

```swift
// ❌ Manual nonce reused across messages with the same key — catastrophic.
let nonce = try AES.GCM.Nonce(data: fixedNonceData)
for message in messages {
    _ = try AES.GCM.seal(message, using: key, nonce: nonce)
}
```

ChaChaPoly is a drop-in alternative and performs better on hardware without AES
acceleration (e.g. older watches). The nonce rule is identical.

Persist `SymmetricKey` material in the keychain (as `Data` from its raw
representation), never in a file or a hardcoded string.

## Public-key: signing and key agreement

```swift
// Signing — P256 for interop, Curve25519 for performance.
let signingKey = P256.Signing.PrivateKey()
let signature = try signingKey.signature(for: data)
let valid = signingKey.publicKey.isValidSignature(signature, for: data)
```

```swift
// Key agreement — always derive through HKDF; never use the raw shared secret.
let priv = P256.KeyAgreement.PrivateKey()
let shared = try priv.sharedSecretFromKeyAgreement(with: peerPublicKey)
let symmetricKey = shared.hkdfDerivedSymmetricKey(
    using: SHA256.self,
    salt: salt,
    sharedInfo: Data("app.session.v1".utf8),   // domain separation
    outputByteCount: 32
)
```

A raw ECDH `SharedSecret` has non-uniform distribution and is not safe as a key —
CryptoKit deliberately omits `withUnsafeBytes` on it, so reaching for an unsafe
workaround is the tell that the code is wrong. Always run it through `HKDF`.

For password-derived keys, use PBKDF2 (via CommonCrypto) with a high iteration
count, or a memory-hard KDF — not a bare hash.

## HPKE (iOS 17+)

`HPKE` (Hybrid Public Key Encryption) packages ECDH + KDF + AEAD into one vetted
construction, removing the manual ECDH→HKDF→AES-GCM chain. Prefer it on iOS 17+ for
encrypting to a recipient's public key.

## Secure Enclave

Hardware-backed P256 keys whose private material never leaves the chip.

- P256 signing and key agreement only — no symmetric primitives are exposed.
- Keys are **generated** inside the Enclave; you cannot import external key
  material. Persist the opaque `dataRepresentation` (to the keychain) and restore
  via `init(dataRepresentation:)` — never `init(rawRepresentation:)`.
- Guard for the simulator: `SecureEnclave.isAvailable` returns `false` there, so an
  unguarded availability check silently takes the fallback path in all simulator
  testing.

```swift
#if targetEnvironment(simulator)
throw SecurityError.secureEnclaveUnavailableOnSimulator
#else
guard SecureEnclave.isAvailable else { throw SecurityError.noSecureEnclave }
let key = try SecureEnclave.P256.Signing.PrivateKey()
let blob = key.dataRepresentation          // opaque; persist to the keychain
#endif
```

## Certificate trust and pinning

- Use the asynchronous `SecTrustEvaluateWithError`; the synchronous
  `SecTrustEvaluate` is deprecated.
- Pin on the **SPKI** (public-key) hash or use declarative `NSPinnedDomains`
  (iOS 14+) in `Info.plist` — not the leaf certificate, which rotates annually and
  will break the app on renewal.
- For mTLS, load the client identity from the keychain and supply it from the
  `URLSession` authentication challenge.

## Summary checklist

- [ ] No AES-GCM/ChaChaPoly nonce reused with the same key (prefer auto nonce).
- [ ] ECDH shared secrets always derived through `HKDF`.
- [ ] No `Insecure.MD5` / `Insecure.SHA1` for security.
- [ ] Secure Enclave code guards the simulator and never imports key material.
- [ ] Pinning uses SPKI hash or `NSPinnedDomains`, not leaf certificates.
- [ ] Trust evaluation uses `SecTrustEvaluateWithError`.
