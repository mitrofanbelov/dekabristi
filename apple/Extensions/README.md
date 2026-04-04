# Share Extensions

The first runnable repository version prioritizes the main macOS and iOS app targets so the project can be generated and launched on a Mac immediately.

Planned next step:

- add iOS share extension target
- add macOS share extension target
- wire both to an App Group backed outbox store
- let the extension save link/file payloads and trigger the main app to upload them when connectivity is available
