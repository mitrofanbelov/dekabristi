# Share Extensions

The repository now includes share extension targets for:

- `DekabristiIOSShareExtension`
- `DekabristiMacShareExtension`

Current behavior:

- the extension appears in the Apple system share sheet for web links
- if the user is already signed in, the extension tries to save the link straight to the backend
- if the network or auth path is not available, the extension queues the link inside the shared App Group container
- the main app imports queued shared links on launch, sign-in, or when it becomes active

Current scope:

- quick saving of links from `Share`
- no file sharing through the extension yet
