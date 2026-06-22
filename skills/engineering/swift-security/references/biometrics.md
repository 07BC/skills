# Biometric authentication

The most common biometric mistake is treating Face ID / Touch ID as a boolean gate.

## Never gate on `evaluatePolicy` alone

```swift
// ❌ Bypassable. The Bool lives in hookable user-space memory; a runtime
//    instrumentation tool flips it to `true` and the secret is handed over
//    without any authentication.
let context = LAContext()
context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                       localizedReason: "Unlock") { success, _ in
    if success { revealSecret() }   // nothing actually protects the secret
}
```

## Bind biometrics to the keychain

Store the secret behind a `SecAccessControl` with `.biometryCurrentSet`. The
keychain then performs authentication inside the Secure Enclave during
`SecItemCopyMatching` — there is no `Bool` in your process to patch. If the user
cancels or fails, the read fails; there is no secret to leak.

```swift
// Storing — protect the item with biometrics at write time.
var error: Unmanaged<CFError>?
guard let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    .biometryCurrentSet,
    &error
) else { throw error!.takeRetainedValue() as Error }

let addQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "auth",
    kSecAttrAccount as String: "refreshToken",
    kSecValueData as String: tokenData,
    kSecAttrAccessControl as String: access,
]
// … SecItemAdd with full OSStatus handling (see keychain.md)
```

```swift
// Reading — the keychain shows the biometric prompt itself.
let context = LAContext()
context.localizedReason = "Authenticate to use your saved session"

let readQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "auth",
    kSecAttrAccount as String: "refreshToken",
    kSecReturnData as String: true,
    kSecMatchLimit as String: kSecMatchLimitOne,
    kSecUseAuthenticationContext as String: context,
]

var result: CFTypeRef?
let status = SecItemCopyMatching(readQuery as CFDictionary, &result)
// errSecUserCanceled / errSecAuthFailed → authentication did not pass; reveal nothing.
```

## Detecting enrolment changes

`.biometryCurrentSet` invalidates the item automatically when the enrolled
biometric set changes, so a freshly added fingerprint cannot reach an existing
secret. If you need to *observe* the change yourself (for example, to prompt a
re-login), snapshot `LAContext().evaluatedPolicyDomainState` and compare it across
launches — a different value means enrolment changed.

## Fallback

Use `.deviceOwnerAuthentication` (rather than `…WithBiometrics`) when a device
passcode fallback is acceptable. For the keychain binding, the matching access
flag is `.userPresence`, which allows passcode fallback when biometrics are
unavailable or fail.

## Summary checklist

- [ ] No `evaluatePolicy` result used as the sole gate to a secret.
- [ ] Secrets requiring biometrics are stored behind `SecAccessControl`.
- [ ] `.biometryCurrentSet` used when added/removed biometrics must invalidate access.
- [ ] Cancel / fail paths reveal nothing.
