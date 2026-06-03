---
description: Split and clean up a large SwiftUI view without changing its behaviour.
argument-hint: [view file or type to refactor]
---
Use the `swiftui-view-refactor` skill to clean up and split this SwiftUI view without changing its behaviour: $ARGUMENTS

Default to MV (not MVVM), enforce the property ordering from the skill, and split into focused subviews before introducing any view model. Show the diff and call out any behavioural risk. If no target is given, ask which view file to refactor.
