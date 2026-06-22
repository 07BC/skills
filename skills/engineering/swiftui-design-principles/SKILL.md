---
name: swiftui-design-principles
description: 'Visual design system reference for SwiftUI views and WidgetKit widgets — spacing, typography, colour, visual hierarchy, and component conventions. Triggers when developers ask: (1) "what spacing/padding should I use", (2) which font sizes/weights/type scale to apply, (3) how to use colour (semantic vs hardcoded, opacity), (4) "design this screen''s visual style" or fix margins/spacing that "look off", (5) card / list-row / toggle-row styling (corner radius, secondary backgrounds), (6) widget visual design (Gauge, containerBackground, timeline cadence). This is a visual-design reference, distinct from code style and architecture.'
user-invocable: false
---
# SwiftUI Design Principles

## Overview

A **visual design system** reference for polished, native-feeling SwiftUI
apps and widgets. It governs spacing, typography, colour, hierarchy, and
component styling — the difference between an app that feels "right" and one
where margins, sizes, and weights look "off".

This is a *visual* reference, not a code-style or architecture one. It does
not change layer structure: it complements MV (`@Observable` services, no
ViewModel layer), iOS 18+ / tvOS 18+, SwiftUI-only. Nothing here introduces
ViewModels or `ObservableObject`.

## Core Philosophy

**Restraint over decoration.** Every pixel earns its place. A polished app
uses fewer colours, fewer font sizes, fewer spacing values, fewer words — but
uses them consistently. Custom gradients, decorative borders, and bespoke
dividers create visual noise; native components and semantic colours create
harmony.

**Attention is scarce.** Keep UI copy shorter than you think it needs to be.
One clear headline plus one compact supporting block beats rationale scattered
across title, subtitle, body, and footer.

---

## 1. Spacing — one grid, no arbitrary values

Use spacing from a base-4/base-8 grid **only**:

```
4, 8, 12, 16, 20, 24, 32, 40, 48
```

```swift
// WRONG — numbers with no relationship to each other
.padding(.bottom, 26)
HStack(spacing: 18)
.padding(14)

// RIGHT — predictable rhythm the eye can follow
.padding(.horizontal, 20)
.padding(.top, 8)
HStack(spacing: 12)
Spacer().frame(height: 32)
```

Standard assignments:

| Context | Value |
| --- | --- |
| Outer content padding (horizontal) | 16–20 |
| Between major sections (vertical) | 24–32 |
| Within grouped components | 4–12 |
| Card / row internal padding | 12–16 vertical, 16 horizontal |

---

## 2. Typography — hierarchy through weight, not size

Use **≤5 distinct sizes**. Differentiate by weight: lighter weights at larger
sizes, medium/regular at smaller sizes. Respect Dynamic Type — prefer semantic
text styles (`.title`, `.body`, `.caption`) where the design allows, and reach
for fixed `.system(size:)` only for deliberate display type.

Reference scale for a data-focused screen:

| Role | Size | Weight |
| --- | --- | --- |
| Hero number | 36–42 | `.light` |
| Secondary stat | 20–24 | `.light` |
| Body / toggle label | 15 | `.regular` |
| Section header (uppercase) | 11 | `.medium` |
| Caption / subtitle | 11–13 | `.regular` |

```swift
// WRONG — 7 sizes, no clear system, weights all over the place
.font(.system(size: 60, weight: .ultraLight))
.font(.system(size: 44, weight: .regular))
.font(.system(size: 31, weight: .ultraLight))
.font(.system(size: 18, weight: .regular))
.font(.system(size: 13, weight: .regular))
.font(.system(size: 12, weight: .regular))

// RIGHT — 5 sizes, clear purpose for each
.font(.system(size: 42, weight: .light, design: .monospaced))   // hero
.font(.system(size: 24, weight: .light, design: .monospaced))   // stat
.font(.system(size: 15, weight: .regular, design: .monospaced)) // body
.font(.system(size: 14, weight: .regular, design: .monospaced)) // secondary
.font(.system(size: 11, weight: .medium, design: .monospaced))  // label
```

**One font design everywhere** — app, widgets, lock screen all share it.
Never `.monospaced` in the app and `.rounded` in the widget.

**Tracking** — at most 2 values, only on uppercase labels:
```swift
.tracking(1.5)  // section labels: "NOTIFICATIONS", "DAY"
.tracking(3)    // toolbar/navigation titles
```
Never 3+ tracking values — the differences are imperceptible but the
inconsistency registers.

**Identifiers** — don't locale-group years and fixed IDs:
```swift
Text(String(year))                       // "2026"
Text(year, format: .number.grouping(.never))
// WRONG: Text("\(year)") can render "2,026"
```

Fix layout rather than reaching for `minimumScaleFactor` hacks.

---

## 3. Colour — semantic system colours

SwiftUI's semantic colours handle light/dark mode and accessibility
automatically and look native. Hardcoded colours with manual opacity are a
maintenance trap and look artificial.

```swift
// WRONG — hardcoded white with a dozen opacity values, won't adapt
Color.black.ignoresSafeArea()
Color.white.opacity(0.08)   // ring background
Color.white.opacity(0.32)   // stat label
Color.white.opacity(0.72)   // button text
Color.white.opacity(0.94)   // ring fill

// RIGHT — semantic, adapts, native
Color(.systemBackground)            // main background
Color(.secondarySystemBackground)   // card / group backgrounds
Color(.separator)                   // dividers
Color.primary                       // primary text / UI
.foregroundStyle(.secondary)        // secondary text
.foregroundStyle(.tertiary)         // labels, captions
```

When you genuinely need opacity, limit to 2–3 values with clear purpose:
```swift
.opacity(0.15)  // subtle background strokes
.opacity(0.3)   // separator lines
// More than that means you're hand-rolling what semantic colours give you.
```

Tint interactive elements with a single accent colour.

---

## 4. Components — proportional, consistent strokes

**Circular indicators** — keep them proportional, and use the **same
`lineWidth`** for background and foreground strokes:

```swift
// RIGHT
Circle().stroke(background, lineWidth: 3)
Circle().trim(from: 0, to: fraction).stroke(fill, lineWidth: 3)
.frame(width: 200, height: 200)   // app main view
.frame(width: 90, height: 90)     // widget (systemSmall), same stroke

// WRONG — oversized, mismatched strokes
.frame(width: 260, height: 260)
Circle().stroke(background, lineWidth: 9)
Circle().trim(from: 0, to: fraction).stroke(fill, lineWidth: 8)
```

**Toggle / list rows** — use `Toggle`'s built-in label with grid padding;
don't hide the label and rebuild the row by hand:

```swift
// RIGHT
Toggle(isOn: $value) {
    Text(title)
        .font(.system(size: 15, weight: .regular, design: .monospaced))
}
.tint(.green)
.padding(.horizontal, 16)
.padding(.vertical, 12)

// WRONG — fixed oversized height, hidden label, low-contrast tint
HStack {
    Text(label).font(.system(size: 18))
    Spacer()
    Toggle("", isOn: $isOn).labelsHidden().tint(Color.white.opacity(0.44))
}
.frame(height: 70)
```

**Mutually exclusive options** — one selected value, not independent toggles
that allow contradictory state:
```swift
enum Cadence: String, CaseIterable { case daily, weekly, monthly }
@State private var cadence: Cadence = .daily
```

**Changing numbers** — animate transitions:
```swift
Text(String(format: "%.2f", percentage))
    .contentTransition(.numericText())
```

---

## 5. Cards & grouped content — native patterns

```swift
// WRONG — custom gradient, decorative border, 22pt radius
VStack { ... }
    .padding(.vertical, 4)
    .background(RoundedRectangle(cornerRadius: 22).fill(LinearGradient(...)))
    .overlay(RoundedRectangle(cornerRadius: 22)
        .stroke(Color.white.opacity(0.08), lineWidth: 1))

// RIGHT — simple, native, light/dark safe
VStack(spacing: 0) {
    row1
    Divider().padding(.leading, 16)
    row2
}
.background(Color(.secondarySystemBackground))
.clipShape(.rect(cornerRadius: 10))
```

- **Corner radius**: 10 for cards/groups (matches iOS). Never 22+.
- **Dividers**: system `Divider()` with `.padding(.leading, 16)`. Never custom divider structs.
- **Background**: `Color(.secondarySystemBackground)` — never custom gradients for standard cards.
- **Padding**: 12–16 vertical, 16 horizontal. Never 4 vertical.

---

## 6. Navigation — NavigationStack, not bare ZStack

```swift
// RIGHT
NavigationStack {
    ScrollView { content }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Title")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(.tertiary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
}

// WRONG — ZStack with a manually placed "title", no nav structure
ZStack {
    Color.black.ignoresSafeArea()
    ScrollView { VStack { Text("2026").font(...); content } }
}
```

---

## 7. WidgetKit — native components

API names below verified against current SwiftUI docs.

**Lock-screen circular** — use `Gauge`, never manual circle drawing:
```swift
// RIGHT
Gauge(value: entry.fraction) {
    Text("")
} currentValueLabel: {
    Text("\(Int(entry.percentage))%")
        .font(.system(size: 12, weight: .medium, design: .monospaced))
}
.gaugeStyle(.accessoryCircular)
.containerBackground(.fill.tertiary, for: .widget)
```
(For a filled ring with the value centred, `.accessoryCircularCapacity` is the
purpose-built style.)

**Lock-screen rectangular** — `Gauge` with `.linearCapacity`, not a custom
`GeometryReader` bar:
```swift
Gauge(value: fraction) { Text("") }
    .gaugeStyle(.linearCapacity)
    .tint(.primary)
```

**Widget background** — always:
```swift
.containerBackground(.fill.tertiary, for: .widget)   // never .black
```

**Family coverage** — support all relevant families; medium and large should
share the same structural hierarchy (header / progress / footer) unless a hard
size constraint forces otherwise. Add explicit internal padding so content
doesn't clip at rounded edges:
```swift
.padding(.horizontal, 12)
.padding(.vertical, 12)
```

**Memory budget** — widget extensions have a tight budget (~30 MB). Dense
visuals (e.g. a 365-dot grid) drawn as nested subviews can hit `EXC_RESOURCE`.
Draw them in one pass with `Canvas`, not hundreds of nested `ForEach` views.

**Timeline cadence — match data granularity:**
```swift
// RIGHT — midnight refresh for day-level data
let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
Timeline(entries: [entry], policy: .after(tomorrow))

// RIGHT — periodic refresh for time-of-day percentages
let refresh = calendar.date(byAdding: .minute, value: 15, to: now)!
Timeline(entries: [entry], policy: .after(refresh))

// WRONG — minute-level refresh for static daily data
Timeline(entries: [entry], policy: .after(calendar.date(byAdding: .minute, value: 1, to: now)!))
```

**Share one model** between app and widget — don't duplicate date/percentage
maths into a separate widget snapshot struct. If percentage is shown as live
progress, include time-of-day in the shared calculation.

---

## 8. Interactive editors (crops, collages, canvases)

Editors need stricter state/layout discipline than ordinary forms:

- **Present from payload state**, not `Bool` + separate data:
  ```swift
  @State private var activeCropRequest: CropRequest?
  .sheet(item: $activeCropRequest) { CropEditor(request: $0) }   // opens only when data exists
  ```
- **One shared geometry model** for both live preview and export — never two
  sets of pan/zoom/crop maths that can drift.
- **Coordinate gestures explicitly** — tap, drag, pinch compete in SwiftUI.
  Model the active item with one interaction state machine, not scattered booleans.
- **Centralise layout** for no-scroll screens — budget vertical space top-down
  (header / canvas / settings / toolbar) in one place.
- **Custom headers**: don't add `safeAreaInsets.top` reflexively — double-counting
  it creates dead space. Keep headers compact, like chrome.
- **One settings surface at a time** when an editor has several modes
  (Layout / Border / Ratio / Background) — keeps the canvas dominant.

---

## 9. Design checklist

Before shipping a SwiftUI view, verify:

- [ ] Spacing values all come from the grid (4, 8, 12, 16, 20, 24, 32, 40, 48)
- [ ] ≤5 distinct font sizes; hierarchy via weight; Dynamic Type respected
- [ ] One font design used everywhere, including widgets
- [ ] Semantic system colours, not hardcoded values with opacity
- [ ] Opacity limited to 2–3 purposeful values
- [ ] Background and foreground strokes share the same `lineWidth`
- [ ] Cards: `Color(.secondarySystemBackground)`, 10pt corner radius
- [ ] System `Divider()` with leading inset; no custom divider structs
- [ ] Toggle rows use `Toggle`'s built-in label (not `.labelsHidden()`)
- [ ] Tracking limited to ≤2 values, uppercase labels only
- [ ] Identifiers (years) avoid locale grouping
- [ ] `NavigationStack` used, not a bare `ZStack`
- [ ] Exclusive choices use one selected value, not multiple toggles
- [ ] No `minimumScaleFactor` hacks — fix the layout instead
- [ ] Lock-screen widgets use `Gauge`; background `.containerBackground(.fill.tertiary, for: .widget)`
- [ ] Widget timeline cadence matches data granularity (midnight vs periodic)
- [ ] Dense widget visuals use `Canvas`; medium/large families share hierarchy + padding
- [ ] App and widget share one data model
- [ ] Editors present from payload state and share one geometry model
