# Keychain fundamentals

The keychain is the only sanctioned store for credentials on Apple platforms.
Every operation goes through `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`,
or `SecItemDelete`, each driven by a query dictionary and each returning an
`OSStatus`.

## Always handle `OSStatus`

Every `SecItem*` call returns a status. Discarding it is the single most common
keychain bug. Handle the cases you can actually hit.

```swift
enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
    case itemNotFound
    case interactionNotAllowed
}
```

`errSecInteractionNotAllowed` means the item exists but the device is locked and
the accessibility class forbids access right now. **Never delete on this status** —
retry when the device is unlocked.

## Add-or-update, never delete-then-add

`SecItemAdd` fails with `errSecDuplicateItem` if a matching item already exists.
The correct response is `SecItemUpdate`, not delete-then-add (which opens a race
window and destroys persistent references).

```swift
func save(_ data: Data, service: String, account: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecValueData as String: data,
        // Always explicit — see access-control.md
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    switch status {
    case errSecSuccess:
        return
    case errSecDuplicateItem:
        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(match as CFDictionary, attributes as CFDictionary)
        guard updateStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    default:
        throw KeychainError.unexpectedStatus(status)
    }
}
```

## Reading

```swift
func read(service: String, account: String) throws -> Data {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    switch status {
    case errSecSuccess:
        guard let data = result as? Data else { throw KeychainError.itemNotFound }
        return data
    case errSecItemNotFound:
        throw KeychainError.itemNotFound
    case errSecInteractionNotAllowed:
        throw KeychainError.interactionNotAllowed
    default:
        throw KeychainError.unexpectedStatus(status)
    }
}
```

## Never on `@MainActor`

Each `SecItem*` call is a synchronous IPC round-trip to `securityd` that blocks the
calling thread. Keep keychain access off the main actor. On iOS 17+, a dedicated
actor is the clean isolation boundary; on older targets, a serial `DispatchQueue`
bridged to `async` works.

```swift
actor KeychainStore {
    func save(_ data: Data, service: String, account: String) throws { /* … */ }
    func read(service: String, account: String) throws -> Data { /* … */ }
}
```

## macOS: target the data-protection keychain

On macOS, add `kSecUseDataProtectionKeychain: true` to **every** query. Without it,
calls route to the legacy file-based keychain, which silently ignores unsupported
attributes and cannot use biometric protection or Secure Enclave keys. Mac Catalyst
and iOS-on-Mac apply this automatically.

```swift
#if os(macOS)
query[kSecUseDataProtectionKeychain as String] = true
#endif
```

## Choosing `kSecClass`

- `kSecClassGenericPassword` — app secrets, tokens, API keys. Keyed by
  `kSecAttrService` + `kSecAttrAccount`.
- `kSecClassInternetPassword` — web credentials; use this (not generic password)
  when you want AutoFill. Keyed by `kSecAttrServer`, `kSecAttrProtocol`, etc.
- `kSecClassKey` — raw cryptographic keys, with `kSecAttrKeyType`.
- `kSecClassCertificate` / `kSecClassIdentity` — certificates and cert+key pairs.

## Summary checklist

- [ ] Every `SecItem*` return value is handled in a `switch`.
- [ ] `errSecDuplicateItem` triggers `SecItemUpdate`, never delete-then-add.
- [ ] `errSecInteractionNotAllowed` retries later, never deletes.
- [ ] No keychain call runs on `@MainActor` / main thread.
- [ ] macOS queries set `kSecUseDataProtectionKeychain: true`.
- [ ] Every add sets `kSecAttrAccessible` explicitly.
