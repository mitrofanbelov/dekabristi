# Running on Mac mini

## Goal

Bring the repository onto the always-on Mac mini and launch the first runnable macOS version of Dekabristi with the local backend.

## One-time setup on the Mac mini

1. Install Xcode and open it once.
2. Install Homebrew if it is not already installed.
3. Clone the repository.
4. From the repository root, run:

```bash
chmod +x scripts/*.sh
./scripts/bootstrap-mac.sh
```

## Start the backend

```bash
./scripts/run-backend.sh
```

The backend will listen on `http://127.0.0.1:8000`.

## Generate and open the Apple project

If `bootstrap-mac.sh` already completed, the Xcode project should already exist. Otherwise:

```bash
./scripts/generate-apple-project.sh
open apple/Dekabristi.xcodeproj
```

## Run the macOS app

1. Open the `DekabristiMac` scheme in Xcode.
2. Build and run it on `My Mac`.
3. Register a new account in the app.
4. Add a link or import a file.
5. Verify that content appears in the library and that the backend logs the requests.

## Backend verification

Run the backend test suite at any time:

```bash
./scripts/test-backend.sh
```

## Important notes

- The first runnable version prioritizes the main macOS app flow.
- Share extensions are not wired into Xcode yet; they are the next concrete slice.
- The default API base URL is `http://127.0.0.1:8000/api/v1`, which is correct when the macOS app and backend run on the same Mac mini.
