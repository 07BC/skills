# Reference: Swift 6 Concurrency Patterns

## What to look for first

```bash
# Swift 6 mode enabled?
grep -r "SWIFT_VERSION = 6\|strict-concurrency=complete" . --include="*.pbxproj" --include="Package.swift"

# Actor usage
grep -r "^actor \|^public actor \|@globalActor" . --include="*.swift" -l

# MainActor annotations
grep -r "@MainActor" . --include="*.swift" | wc -l

# Mutex (iOS 18+) vs NSLock (legacy)
grep -r "Mutex\b" . --include="*.swift" -l
grep -r "NSLock\|os_unfair_lock" . --include="*.swift" -l

# Sendable
grep -r "Sendable\|@unchecked Sendable" . --include="*.swift" | wc -l
```

## Mutex (iOS 18+) — preferred synchronisation primitive

```swift
import Synchronization

final class CameraManager: Sendable {
    private let _isRunning = Mutex(false)

    var isRunning: Bool {
        _isRunning.withLock { $0 }
    }

    func start() {
        _isRunning.withLock { $0 = true }
    }
}
```

`Mutex` is `Sendable`, works under strict concurrency, and avoids the
`@unchecked Sendable` escape hatch that `NSLock` required.
Flag any remaining `NSLock` usage as a migration candidate.

## Actor isolation patterns

```swift
// Dedicated actor for hardware-bound work
actor RTMPPublisher {
    private var connection: RTMPConnection?

    func publish(stream: RTMPStream) async throws { ... }
}

// @MainActor for UI-bound services
@MainActor
final class StreamStateModel: ObservableObject { ... }

// Nonisolated where safe
extension RTMPPublisher {
    nonisolated var description: String { "RTMPPublisher" }
}
```

Document every `actor` type, its isolation domain, and how callers cross
into it (`await`, `Task`, `async let`).

## AsyncStream patterns

```swift
// Producer side — continuation held by service
let (stream, continuation) = AsyncStream.makeStream(of: ConnectionEvent.self)

// Consumer side — view or orchestrator
for await event in eventStream {
    handle(event)
}
```

Note any `AsyncThrowingStream` usage (implies error propagation from
the stream source, e.g. RTMP disconnect with error).

## @unchecked Sendable — flag these

```swift
// This is a concurrency bypass — document why it exists
final class LegacyWrapper: @unchecked Sendable {
    private let lock = NSLock()
    ...
}
```

Every `@unchecked Sendable` is a potential data race. List them all and
note whether they are protected by a lock.

## Task management

Look for unstructured `Task { }` calls — these are detached from the caller's
lifetime and can leak. Prefer `task(id:)` modifier in SwiftUI or structured
concurrency inside actors.

```bash
grep -rn "Task {" . --include="*.swift" | grep -v "Test\|test\|spec" | head -30
```

Document the dominant task management strategy and flag any obvious leaks.

## Common gotchas in streaming apps

- `AVCaptureSession` must run on a dedicated serial queue, not an actor —
  actors can suspend, queues cannot. Note how the project handles this.
- `CMSampleBuffer` is `Sendable` but its contents may not be — check how
  video frames cross actor boundaries.
- Timer-based polling inside an actor should use `Task.sleep`, not
  `DispatchQueue.asyncAfter` — flag any mixed patterns.
