# Swift Testing Assertions Reference

## All test functions
All test functions must be async and throws

```swift
func functionName() async throws {
}
```

## Basic Assertions

### #expect
The primary assertion macro. Evaluates a boolean expression.

```swift
#expect(value == expected)
#expect(array.isEmpty)
#expect(optional != nil)
#expect(count > 0)
```

### #require
Like `#expect` but throws on failure, stopping test execution.

```swift
let user = try #require(response.user)  // Unwraps optional or fails
#require(array.count >= 3)  // Fails if false
```

## Equality

```swift
#expect(actual == expected)
#expect(actual != unexpected)
```

## Optionals

```swift
#expect(value == nil)
#expect(value != nil)

// Unwrap and use
let unwrapped = try #require(optionalValue)
```

## Collections

```swift
#expect(array.isEmpty)
#expect(!array.isEmpty)
#expect(array.count == 3)
#expect(array.contains("item"))
```

## Errors

### Expect throws
```swift
#expect(throws: MyError.self) {
    try functionThatThrows()
}
```

### Expect specific error
```swift
#expect(throws: MyError.invalidInput) {
    try validate("")
}
```

### Expect any error
```swift
#expect(throws: (any Error).self) {
    try riskyOperation()
}
```

⚠️ `throws: (any Error).self` / `throws: Error.self` is a **weak assertion** — it passes for *any* thrown error, including one thrown for the wrong reason (an unrelated trap, a different decode failure). It is the error-path `!= nil`. Prefer the specific type or case (the two examples above). Use the any-error form only when "throws something" genuinely is the contract and the type is outside the SUT's control. See `references/anti-patterns.md` ("over-wide-throws").

### Expect no throw
```swift
#expect(throws: Never.self) {
    try safOperation()
}
```

## Async Testing

```swift
@Test func asyncOperation() async throws {
    let result = try await fetchData()
    #expect(result.success)
}
```

## Custom Messages

```swift
#expect(value > 0, "Value must be positive, got \(value)")
```

## Comparison with XCTest

| XCTest | Swift Testing |
|--------|---------------|
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertNotEqual(a, b)` | `#expect(a != b)` |
| `XCTAssertTrue(x)` | `#expect(x)` |
| `XCTAssertFalse(x)` | `#expect(!x)` |
| `XCTAssertNil(x)` | `#expect(x == nil)` |
| `XCTAssertNotNil(x)` | `#expect(x != nil)` |
| `XCTAssertGreaterThan(a, b)` | `#expect(a > b)` |
| `XCTAssertLessThan(a, b)` | `#expect(a < b)` |
| `XCTAssertThrowsError(expr)` | `#expect(throws: Error.self) { expr }` |
| `XCTUnwrap(x)` | `try #require(x)` |
