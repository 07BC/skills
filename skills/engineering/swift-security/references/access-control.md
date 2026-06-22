# Keychain access control

Every keychain item carries a `kSecAttrAccessible` value that decides **when** it
can be decrypted. Set it explicitly on every add — the implicit default
(`WhenUnlocked`) breaks background work and makes your security policy invisible in
review.

## Accessibility constants

| Constant | Decryptable when | Survives backup / migration | Background-safe | Use when |
| --- | --- | --- | --- | --- |
| `WhenPasscodeSetThisDeviceOnly` | Unlocked, passcode set | No | No | Highest-sensitivity secrets; removed if the passcode is removed |
| `WhenUnlockedThisDeviceOnly` | Unlocked | No | No | Device-bound, foreground-only |
| `WhenUnlocked` | Unlocked | Yes | No | Syncable secrets (system default — avoid using it implicitly) |
| `AfterFirstUnlockThisDeviceOnly` | After first unlock until restart | No | Yes | Background tasks, push handlers, device-bound |
| `AfterFirstUnlock` | After first unlock until restart | Yes | Yes | Background tasks that must survive a restore |

**Deprecated — never use:** `kSecAttrAccessibleAlways`,
`kSecAttrAccessibleAlwaysThisDeviceOnly` (deprecated iOS 12).

**Rule of thumb:** need background access → start at
`AfterFirstUnlockThisDeviceOnly`. Foreground-only → `WhenUnlockedThisDeviceOnly`.
Tighten to `WhenPasscodeSetThisDeviceOnly` for high-value secrets. Use the
non-`ThisDeviceOnly` variants only when iCloud sync or backup migration is genuinely
required.

## `ThisDeviceOnly` vs syncable

`ThisDeviceOnly` items are excluded from encrypted backups and device migration, so
they cannot leak through a restored backup. They also do not sync via iCloud
Keychain. Pairing `kSecAttrSynchronizable: true` with a `ThisDeviceOnly` class is
contradictory — pick one intent.

## `SecAccessControl` for stronger protection

To require user presence (biometrics or passcode) at access time, attach a
`SecAccessControl` via `kSecAttrAccessControl` instead of a bare `kSecAttrAccessible`.

```swift
var error: Unmanaged<CFError>?
guard let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    .biometryCurrentSet,        // invalidated if the enrolled biometric set changes
    &error
) else {
    throw error!.takeRetainedValue() as Error
}

let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "auth",
    kSecAttrAccount as String: "refreshToken",
    kSecValueData as String: tokenData,
    kSecAttrAccessControl as String: access,   // replaces kSecAttrAccessible
]
```

- `.biometryCurrentSet` invalidates the item if fingerprints/faces are added or
  removed — the strongest binding.
- `.biometryAny` survives enrolment changes; weaker, but does not force re-store.
- `.userPresence` lets the system fall back to the device passcode.

See `biometrics.md` for the full keychain-bound authentication flow.

## Summary checklist

- [ ] Every add sets `kSecAttrAccessible` or `kSecAttrAccessControl` explicitly.
- [ ] No deprecated `Always` constants.
- [ ] Class matches the access pattern (background vs foreground, device-bound vs syncable).
- [ ] No `Synchronizable: true` combined with a `ThisDeviceOnly` class.
