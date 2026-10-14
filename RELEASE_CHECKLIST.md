# Release checklist (run top to bottom, check every box)

## 0. Signing (do once per machine, then verify every release)
- [ ] `android/key.properties` exists locally and is NOT in `git status`
      (it is gitignored — if it ever shows up staged, stop and unstage it).
- [ ] Backups: keystore + both passwords exist in TWO independent places
      (see `android/KEYSTORE.md` — no recovery if lost).
- [ ] Signature matches the previous release (same key or users can't update):
  ```powershell
  & "$env:ANDROID_HOME\build-tools\<version>\apksigner.bat" verify --print-certs `
    build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
  ```
  Compare cert SHA-256 with the last shipped APK.
- [ ] OTA loop proven with this key: install previous release on a device,
      install this build over it (`adb install -r …`, data kept), then
      Profile → Check for updates against the matching GitHub Release.

## 1. Automated gates (the build script enforces these)
- [ ] `flutter analyze` — zero issues.
- [ ] `flutter test` — all green, including `test/responsive_test.dart`
      (320×640 @ 1.0/1.3/2.0, 360×740 @ 1.3; fails on any RenderFlex overflow).
- [ ] Text scale clamp active (`CampusTrackerApp.kMaxTextScale == 1.3).

## 2. Emulator matrix
| API | Size | Font 1.0 | Font 1.3 | Light | Dark |
|-----|------|----------|----------|-------|------|
| 24 (min) | small phone (320×640) | ☐ | ☐ | ☐ | ☐ |
| 29 | large (412×915) | ☐ | ☐ | ☐ | ☐ |
| 31 | small phone | ☐ | ☐ | ☐ | ☐ |
| 33 | large | ☐ | ☐ | ☐ | ☐ |
| 34 | small phone | ☐ | ☐ | ☐ | ☐ |
| 35 | large | ☐ | ☐ | ☐ | ☐ |

Change font size via Settings → Display → Font size on each emulator.

## 3. Real devices
- [ ] At least one physical phone (daily driver): install, launch, rotate.
- [ ] A second device if available (different OEM — notification behavior
      differs on Oppo/Realme vs Pixel/Samsung).

## 4. Scenarios (each: expected result noted)
- [ ] Fresh install (clear data): onboarding → empty states, no preloaded data.
- [ ] Upgrade with old data: install over previous release, tasks/courses/
      focus history intact (legacy JSON tolerated).
- [ ] Permissions granted: greeting + task + class reminders schedule
      (Profile → status shows Pending > 0).
- [ ] Permissions denied: app works, no crashes; re-enabling re-arms all.
- [ ] Reboot: 6 AM greeting + class reminders still pending afterwards.
- [ ] Timezone change: class window recomputed on next launch.
- [ ] Battery saver ON: alarms may defer (OS-controlled) — spot check.
- [ ] Airplane mode: everything except update-check works; update check
      fails silently, never blocks.
- [ ] Rotation mid-run (Focus): timer keeps wall-clock time, no overflow.
- [ ] Kill app mid-focus: relaunch records the finished run once, offers break.
- [ ] Notification tap in all three states: foreground / background / killed.
- [ ] Predictive back: sheets, dialogs, pushed routes, new-task sheet
      (animates closed first), dashboard plus-menu (closes menu first).
- [ ] Focus immersive mode: nav hides on Start, returns on Pause/End.
- [ ] OTA end-to-end: publish GitHub Release with higher tag + APK asset,
      launch app → "Update available" dialog → Update opens download.

## 5. Ship
- [ ] `scripts/build_release.ps1` printed all APKs + sizes.
- [ ] Sideload/final APK is the **release-key-signed** split
      (`app-arm64-v8a-release.apk` for testers), never a debug-signed build.
- [ ] GitHub Release created: higher `vX.Y.Z` tag, notes, APK attached.
