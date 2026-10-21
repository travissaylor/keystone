# Keystone

A personal iOS companion for one job: getting through the gym door four mornings a week, for years, and getting back through it after the weeks when life wins.

It tracks attendance, not workouts. The habit being built is the decision to go, not the training itself.

**Status:** phase 1 ("Loop") is built. The plan, research and reviews are in issue #1. The words the code uses are defined in `CONTEXT.md`.

## Layout

- `HabitCore/`: a Swift package with no UI. It holds the counting contract, the trip budget, the notification queue, and export. Every constant is in `Schedule.swift`.
- `Keystone/`: the SwiftUI app, which has one screen.
- `KeystoneWidget/`: the status widget and the "Log gym visit" control.
- `Shared/`: SwiftData persistence and the one-tap intent, compiled into both targets.

## Build

```sh
swift test --package-path HabitCore
xcodegen generate        # only after changing project.yml
xcodebuild -scheme Keystone -destination 'generic/platform=iOS' build
```

Before the first device run, work through [docs/device-checklist.md](docs/device-checklist.md).
