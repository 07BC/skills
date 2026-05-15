# Apple DocC Documentation Conventions

## Basic Structure

Every documented symbol uses `///` prefix. The first line is always the **summary** — one sentence, no period at end unless it's a full sentence. Leave a blank `///` line before any additional content.

```swift
/// Returns the absolute value of the given number.
///
/// Longer description if needed. Explain behaviour, edge cases,
/// or implementation notes here.
func abs(_ value: Int) -> Int
```

## Parameters

Use `- Parameter name:` for a single parameter, or `- Parameters:` + indented list for multiple:

```swift
/// - Parameter value: The number to convert.

/// - Parameters:
///   - lhs: The left-hand operand.
///   - rhs: The right-hand operand.
```

## Returns

```swift
/// - Returns: The formatted string, or `nil` if formatting fails.
```

## Throws

```swift
/// - Throws: `NetworkError.timeout` if the request exceeds the time limit.
///           `DecodingError` if the response cannot be parsed.
```

## Callout Types

```swift
/// - Note: Available on iOS 16 and later.
/// - Important: Must be called on the main thread.
/// - Warning: This method modifies the receiver in place.
/// - Tip: For better performance, cache the result.
/// - Precondition: `count` must be greater than zero.
/// - Postcondition: The array is sorted in ascending order.
/// - Requires: A valid authentication token must exist in the keychain.
/// - Complexity: O(n log n)
/// - SeeAlso: `sorted(by:)`, `sort()`
/// - Since: 2.0
```

## Code Examples

Use fenced Swift code blocks:

```swift
/// ```swift
/// let result = encode(payload, using: .base64)
/// print(result) // "aGVsbG8="
/// ```
```

## Cross-References

Wrap symbol names in backticks. Use full qualified name only when ambiguous:

```swift
/// Use ``encode(_:using:)`` before passing data to ``upload(_:)``.
/// Returns a `String` or `nil`.
```

## Properties

```swift
/// The current authentication state of the user.
///
/// Observe this property to react to sign-in and sign-out events.
var authState: AuthState
```

## Enums

Document the enum type and each case:

```swift
/// Represents the possible states of a network request.
enum RequestState {
    /// The request has not yet been sent.
    case idle
    /// The request is in progress.
    case loading
    /// The request completed with a response.
    case success(Data)
    /// The request failed with an error.
    case failure(Error)
}
```

## Protocols

Document the protocol and each requirement:

```swift
/// A type that can authenticate a user.
protocol AuthServiceProtocol {
    /// Signs the user in with the given credentials.
    ///
    /// - Parameter credentials: The user's login credentials.
    /// - Throws: `AuthError.invalidCredentials` if authentication fails.
    func signIn(with credentials: Credentials) async throws
}
```

## Update Rules

When a `///` comment already exists on a symbol:
- Keep the existing summary if it is accurate; improve it if it is vague or wrong
- Add missing `- Parameter`, `- Returns`, `- Throws` sections
- Add callouts only if genuinely useful (don't pad)
- Never remove accurate existing content — only refine or extend it
- Preserve existing line breaks and formatting style
