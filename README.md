# Hand Track

A Mac app that watches your hand through the camera and turns gestures into actions. It uses the
hand tracking built into macOS (Vision); the video never leaves the Mac.

| Gesture | Action |
| --- | --- |
| Touch thumb and index finger, then move your hand up or down | Volume up / down (half the picture's height = the full range) |
| Make a fist and hold it for 1 second | Screenshot of the main screen, saved to the Desktop |

The window shows your hand: white while tracking, green while pinching (with a volume bar),
orange while holding a fist (a ring fills up until the screenshot).

## Build and run

```bash
./build.sh
open "Hand Track.app"
```

Needs the Xcode Command Line Tools (`xcode-select --install`), nothing else.

## Permissions

- **Camera**: asked on first launch.
- **Screen Recording**: asked on the first screenshot. Without it, screenshots show only the
  wallpaper. After you allow it, quit and reopen the app.

The app is signed ad hoc, so after a rebuild macOS may treat it as a new app: if screenshots go
blank again, remove Hand Track from System Settings › Privacy & Security › Screen Recording and
allow it again.

## Tuning

The thresholds are at the top of `Sources/HandTrack/GestureRecognizer.swift`. Run the gesture
tests with `swift test`.
