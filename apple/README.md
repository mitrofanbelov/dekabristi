# Apple Client

This folder starts with a shared Swift package so we can build the app core on top of a stable offline-first foundation before generating the final Xcode targets on macOS.

## What exists in this slice

- `Package.swift` for shared client logic
- networking layer for the first backend endpoints
- connectivity monitor based on `NWPathMonitor`
- outbox queue for link and file drafts
- sync coordinator for launch/manual/periodic refresh flows
- persistent auth session and App Group backed shared-link queue
- iOS and macOS share extension sources for quick link saving from the system share sheet

## Next Apple-specific step on Mac

Generate the Xcode project on the Mac mini, assign a signing team, and test:

- `DekabristiMac`
- `DekabristiIOS`
- `DekabristiMacShareExtension`
- `DekabristiIOSShareExtension`
