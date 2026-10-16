# Uniro 🎓

Campus companion for students — tasks with smart reminders, weekly class routine, Pomodoro focus timer, and rich notes. Fully offline; your data stays on your device.

## Features

- **Dashboard** — time-aware greeting, rotating motivational quote, hero task carousel, weekly workload chart, next-class card, quick-add.
- **Tasks** — assignments, exams, CTs, vivas, presentations, labs and projects with due dates/times, priorities, course links, and flexible reminders (at time, 1 hour, 1–7 days, custom).
- **Routine** — courses with weekly class slots (time, room, overlap detection) and per-class reminders.
- **Focus** — Pomodoro timer with flip-clock display, configurable focus/break lengths, links to courses/tasks/classes, pause/resume, and session history.
- **Notes** — block editor (paragraph, checklist, quote), text styling, folders, pin/lock, search, course links.
- **Notifications** — task reminders, a daily 6 AM briefing, class reminders, and a 1-minute self-test reminder. Exact alarms gracefully fall back to inexact ones when the system denies them; everything is rebuilt after reboot, app update, or timezone change.
- **Home-screen widgets** — weekly load and monthly heatmap.
- **Profile** — avatar, reminder defaults, light/dark/system theme, battery-optimization guidance for strict OEMs (Xiaomi, Oppo, Realme, Vivo, Samsung, Huawei), in-app updates, and one-tap diagnostics export.
- **Reliability** — corrupt-data backup with recovery notice, on-device error log (last 20, never uploaded), capability-aware haptics with per-device fallbacks.

## Requirements

- Android 7.0 (API 24) or newer. Built with Flutter (3.47+, Dart 3.13+); targets the latest Android SDK.

## Install

1. Download `Uniro-<version>.apk` from the latest [GitHub Release](../../releases/latest).
2. Open it on your phone and allow “install unknown apps” when asked.
3. Updates arrive automatically: the app checks GitHub Releases and offers one-tap download.

> The package ID is `dev.sudoguy.uniro`. Builds must keep the same signing key or Android will refuse updates.

## Build from source

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Release signing reads `android/key.properties` (see `android/KEYSTORE.md`). That file and `*.jks` are git-ignored and must never be committed — without them, release builds fall back to the debug key for local testing only.

## Permissions (Android) and why

| Permission | Reason |
|---|---|
| `INTERNET` | Check GitHub Releases for updates |
| `RECEIVE_BOOT_COMPLETED` | Re-arm reminders after reboot / app update |
| `VIBRATE` | Notification vibration |
| `POST_NOTIFICATIONS` (Android 13+) | Task, class, and greeting notifications (asked only when you enable reminders) |
| `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` (Android 12+) | On-time reminders; falls back to inexact timing if denied |
| `READ_MEDIA_IMAGES` (Android 13+) / `READ_EXTERNAL_STORAGE` (≤ Android 12 only) | Profile photo picker |

## Privacy

- All tasks, classes, notes, and settings are stored locally via SharedPreferences. No account, no cloud sync, no analytics.
- The error log keeps the last 20 entries on-device for diagnostics export. Nothing is uploaded.
- The only network use is the GitHub Releases update check and APK download.

## Tests

Automated coverage (`flutter test`) includes quotes/scheduling helpers, haptic capability fallbacks, notification ID logic, routine helpers, focus logic, and note models. Release builds are additionally verified with `apksigner` (release certificate) and `aapt` (package ID + version).

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 sudoguy47.
