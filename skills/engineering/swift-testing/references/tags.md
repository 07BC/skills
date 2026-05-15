# Swift Testing Tags

Tags organise tests for selective execution and filtering.

## Defining Tags

Create a `Tag` extension in your test target:

```swift
extension Tag {
    @Tag static var auth: Self
    @Tag static var networking: Self
    @Tag static var persistence: Self
    @Tag static var ui: Self
    @Tag static var integration: Self
    @Tag static var slow: Self
}
```

## Using Tags

### On a Suite
```swift
@Suite(.tags(.auth))
struct AuthServiceTests {
    // All tests in suite inherit the tag
}
```

### On individual tests
```swift
@Test(.tags(.slow, .integration))
func fullSyncWorkflow() async { }
```

### Multiple tags
```swift
@Suite(.tags(.auth, .networking))
struct AuthAPITests { }
```

## Running Tagged Tests

### Command line
```bash
# Run only auth tests
swift test --filter .tags(.auth)

# Exclude slow tests
swift test --skip .tags(.slow)
```

### Xcode
Use the Test Navigator filter or scheme settings.

## Tag Organisation Patterns

### By feature/domain
```swift
@Tag static var auth: Self
@Tag static var broadcast: Self
@Tag static var chat: Self
@Tag static var settings: Self
```

### By test type
```swift
@Tag static var unit: Self
@Tag static var integration: Self
@Tag static var e2e: Self
@Tag static var snapshot: Self
```

### By execution characteristics
```swift
@Tag static var slow: Self
@Tag static var flaky: Self
@Tag static var requiresNetwork: Self
@Tag static var requiresDevice: Self
```

## Best Practices

1. **Always tag suites** - Every `@Suite` should have at least one tag
2. **Use feature tags** - Align tags with app features/modules
3. **Tag slow tests** - Mark tests that take >1s for selective exclusion
4. **Reuse existing tags** - Check for existing tags before creating new ones
5. **Keep tags coarse** - Prefer fewer, broader tags over many specific ones
