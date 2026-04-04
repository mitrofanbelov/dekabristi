# Apple Client

This folder starts with a shared Swift package so we can build the app core on top of a stable offline-first foundation before generating the final Xcode targets on macOS.

## What exists in this slice

- `Package.swift` for shared client logic
- networking layer for the first backend endpoints
- connectivity monitor based on `NWPathMonitor`
- outbox queue for link and file drafts
- sync coordinator for launch/manual/periodic refresh flows
- lightweight SwiftUI blueprint views to show composition

## Next Apple-specific step on Mac

Generate actual `iOS`, `macOS`, and share extension targets around this package using Xcode project tooling on the Mac mini.
