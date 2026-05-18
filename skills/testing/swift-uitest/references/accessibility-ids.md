# Accessibility Identifier Registry

This file is the source of truth for all `accessibilityIdentifier` values used
in UI tests. Update it whenever you add, rename, or remove an identifier.

---

## Naming Convention

```
<screen>.<element>[.<variant>]
```

- All lowercase, dot-separated
- Screen prefix matches the SwiftUI View filename without the `View` suffix
  (e.g. `LoginView` → `login.*`)
- Variants used for repeated elements (e.g. quality options)

---

## Template: Adding a New Screen

When a new screen requires UI tests, add a section here:

```markdown
## <ScreenName>

| Identifier | Element type | Description |
|------------|--------------|-------------|
| `<screen>.container` | `View` / `otherElements` | Root container of the screen |
| `<screen>.<element>` | `Button` / `TextField` / etc. | Short description |
```

---

## Registered Identifiers

<!-- Add new screens below this line, alphabetically -->

### Login

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `login.username` | `textFields` | `TextField` for username |
| `login.password` | `secureTextFields` | `SecureField` for password |
| `login.signIn` | `buttons` | Primary sign-in button |
| `login.errorMessage` | `staticTexts` | Validation / auth error label |
| `login.forgotPassword` | `buttons` | Forgot password link |

### Home / Dashboard

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `home.container` | `otherElements` | Root `VStack` / container |
| `home.goLive` | `buttons` | Go Live CTA button |

### Go Live / Preview

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `goLive.preview` | `otherElements` | Camera preview container |
| `goLive.startStream` | `buttons` | Start streaming button |
| `goLive.stopStream` | `buttons` | Stop streaming button |
| `goLive.camera.toggle` | `buttons` | Switch camera button |
| `goLive.mic.toggle` | `buttons` | Mute/unmute mic button |
| `goLive.status` | `staticTexts` | Stream status label (e.g. "Live") |

### Settings

| Identifier | Element type | SwiftUI usage |
|------------|--------------|---------------|
| `settings.container` | `otherElements` | Root container |
| `settings.quality.picker` | `otherElements` | Quality picker/segmented control |
| `settings.quality.option.hd720` | `buttons` | 720p option |
| `settings.quality.option.hd1080` | `buttons` | 1080p option |

---

## Adding Identifiers to SwiftUI Views

```swift
// Button
Button("Go Live") { ... }
    .accessibilityIdentifier("goLive.startStream")

// TextField
TextField("Username", text: $username)
    .accessibilityIdentifier("login.username")

// SecureField
SecureField("Password", text: $password)
    .accessibilityIdentifier("login.password")

// Container view
VStack { ... }
    .accessibilityIdentifier("home.container")

// Picker
Picker("Quality", selection: $quality) { ... }
    .accessibilityIdentifier("settings.quality.picker")

// Dynamic list item
ForEach(options) { option in
    Text(option.label)
        .accessibilityIdentifier("settings.quality.option.\(option.id)")
}
```
