# Running Dekabristi on iPhone

## Goal

Build the iOS app and the iOS share extension on the Mac mini, install them on a physical iPhone, and verify that links can be saved both from inside the app and from the system `Share` sheet.

## What is different from the Mac mini run

The iPhone cannot reach the backend at `127.0.0.1`.

Before building for the phone, point both the iOS app and the iOS share extension to a backend address that the iPhone can reach:

- best local-network option: `http://<MAC_MINI_LAN_IP>:8000/api/v1`
- best long-term option: your public HTTPS domain or tunnel URL

Example:

```text
http://192.168.1.25:8000/api/v1
```

## One-time preparation on the Mac mini

1. Install Xcode and open it once.
2. Install Homebrew if needed.
3. Clone the repository.
4. Run:

```bash
chmod +x scripts/*.sh
./scripts/bootstrap-mac.sh
```

5. Start the backend:

```bash
./scripts/run-backend.sh
```

6. Find the Mac mini LAN IP:

```bash
ipconfig getifaddr en0
```

If `en0` is not your active adapter, check `en1` or inspect System Settings -> Network.

## Change the iPhone backend address

Open these two files or edit the corresponding target Info values in Xcode:

- `apple/App/Config/iOS-Info.plist`
- `apple/Extensions/Config/iOS-ShareExtension-Info.plist`

Replace:

```text
http://127.0.0.1:8000/api/v1
```

with:

```text
http://<MAC_MINI_LAN_IP>:8000/api/v1
```

Do not change the macOS plist files if the Mac app still runs against the backend on the same Mac mini.

## Generate and open the Xcode project

```bash
./scripts/generate-apple-project.sh
open apple/Dekabristi.xcodeproj
```

## Configure signing in Xcode

Set the same Apple signing team for all four targets:

- `DekabristiIOS`
- `DekabristiIOSShareExtension`
- `DekabristiMac`
- `DekabristiMacShareExtension`

Important:

- the iOS app and the iOS share extension must both sign successfully
- the App Group is `group.com.dekabristi.shared`
- if Xcode reports that your current signing team cannot use App Groups, use a team that supports the capability

## Prepare the iPhone

1. Connect the iPhone to the Mac mini by cable.
2. Unlock the phone.
3. If asked, tap `Trust This Computer`.
4. In Xcode, wait until the phone appears as a run destination.
5. If developer mode is requested on the iPhone, enable it and reboot the device if prompted.

## Build and run on iPhone

1. In Xcode, choose the `DekabristiIOS` scheme.
2. Select your physical iPhone as the destination.
3. Build and run the app.
4. If iOS warns that the developer is untrusted:
   - open `Settings -> General -> VPN & Device Management`
   - trust the developer profile
   - launch the app again

## Verify the app flow on iPhone

1. Register or sign in.
2. Add a link from inside the app.
3. Add a file from inside the app.
4. Open a saved link from the list.
5. Tap a saved file and verify:
   - photos/videos are saved to Photos
   - other files are saved to the Files downloads location or the app fallback Downloads folder
6. Add or edit a comment.
7. Delete a link or file.

## Verify the Share flow on iPhone

1. Open Safari on the iPhone.
2. Open any web page.
3. Tap `Share`.
4. If `Dekabristi Share` is not visible:
   - scroll to the end of the app list in the share sheet
   - tap `More`
   - enable `Dekabristi Share`
5. Tap `Dekabristi Share`.
6. Save the shared link.
7. Return to Dekabristi and confirm the link appears in the library.

## Notes

- If the backend is reachable and the user is signed in, the share extension tries to save the link immediately.
- If the backend is temporarily unavailable, the share extension queues the link in the shared App Group container.
- The main app imports queued links on launch, sign-in, and when it becomes active.
