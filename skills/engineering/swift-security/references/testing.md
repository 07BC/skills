# Testing security code

Security code is testable, but the keychain, Secure Enclave, and biometrics behave
differently on the simulator than on device. Split the strategy accordingly.

## Abstract the keychain behind a protocol

Unit tests should not touch the real keychain. Define a narrow protocol and inject
a fake; reserve real `SecItem*` calls for on-device integration tests.

```swift
protocol SecretStore: Sendable {
    func save(_ data: Data, account: String) async throws
    func read(account: String) async throws -> Data
    func delete(account: String) async throws
}

actor KeychainSecretStore: SecretStore { /* real SecItem* calls — keychain.md */ }

actor InMemorySecretStore: SecretStore {
    private var items: [String: Data] = [:]
    func save(_ data: Data, account: String) { items[account] = data }
    func read(account: String) throws -> Data {
        guard let data = items[account] else { throw KeychainError.itemNotFound }
        return data
    }
    func delete(account: String) { items[account] = nil }
}
```

Test the consuming logic (token refresh, logout cleanup, migration) against the
in-memory store with Swift Testing:

```swift
import Testing

@Test func logoutClearsTheToken() async throws {
    let store = InMemorySecretStore()
    let session = SessionManager(store: store)
    try await session.signIn(token: Data("abc".utf8))
    try await session.signOut()
    await #expect(throws: KeychainError.self) { try await store.read(account: "token") }
}
```

## What only device tests can prove

- **Secure Enclave** — `SecureEnclave.isAvailable` is `false` on the simulator, so
  any SE path must be verified on a physical device.
- **Biometric-bound items** — Face ID / Touch ID prompts cannot be satisfied by
  unit tests; verify the keychain binding with a manual or UI test on device
  (enrolled biometrics in the simulator do not exercise the Secure Enclave path).
- **Accessibility timing** — locked-device behaviour
  (`errSecInteractionNotAllowed`) is only observable on a real, locked device.

## CryptoKit is unit-testable directly

Pure CryptoKit operations (hash, seal/open, sign/verify, HKDF) are deterministic
enough to test without hardware — round-trip a value and assert it recovers, and
assert that tampering with ciphertext makes `open` throw.

```swift
@Test func sealOpenRoundTrips() throws {
    let key = SymmetricKey(size: .bits256)
    let sealed = try AES.GCM.seal(Data("hello".utf8), using: key)
    let opened = try AES.GCM.open(sealed, using: key)
    #expect(opened == Data("hello".utf8))
}
```

## CI

CI runners may have no keychain configured; integration tests that hit the real
keychain need a created/unlocked keychain in the job, or should be tagged and run
only on device lanes. Keep the protocol-backed unit tests in the default lane so
the bulk of coverage runs everywhere.

## Summary checklist

- [ ] Consuming logic tested against an in-memory `SecretStore`, not the real keychain.
- [ ] Secure Enclave and biometric paths verified on a physical device.
- [ ] CryptoKit round-trip and tamper tests in the default unit-test lane.
- [ ] Real-keychain integration tests gated to device/CI lanes with a prepared keychain.
