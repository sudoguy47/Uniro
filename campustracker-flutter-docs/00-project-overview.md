# 00. CampusTracker — Flutter Project Overview

> **Language**: Dart  
> **Framework**: Flutter 3.x  
> **Architecture**: GymMane-এর exact same pattern (FitState → AppState)
> **IDE**: Android Studio + Flutter Plugin

---

## Tech Stack (GymMane থেকে direct)

```yaml
# pubspec.yaml dependencies
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State — GymMane: ChangeNotifier (same)
  provider: ^6.1.2           # ChangeNotifier এর জন্য

  # Persistence — GymMane: SharedPreferences (same)
  shared_preferences: ^2.3.2

  # Date
  intl: ^0.19.0

  # Notifications
  flutter_local_notifications: ^18.0.1
  timezone: ^0.9.4

  # Navigation — GymMane: in-memory route (same)
  # Flutter built-in Navigator ব্যবহার করব

  # Haptics — GymMane: HapticFeedback (Flutter built-in)
  # HapticFeedback.mediumImpact() — no package needed

  # Image picker (Profile avatar)
  image_picker: ^1.1.2

  # UUID
  uuid: ^4.4.0

  # Path provider
  path_provider: ^2.1.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

---

## Folder Structure

```
lib/
├── main.dart                    # GymMane main.dart — boot sequence
├── app/
│   ├── app.dart                 # MaterialApp + ThemeExtension
│   └── app_shell.dart           # Root shell: animated bottom bar + screen switcher
├── models/
│   ├── task.dart                # Task, Reminder, TaskType, TaskPriority
│   └── settings.dart            # UserSettings, ThemeMode
├── state/
│   ├── app_core.dart            # GymMane fit_core.dart — pure logic + debounced save
│   └── app_state.dart           # GymMane fit_state.dart — ChangeNotifier
├── services/
│   ├── local_store.dart         # GymMane local_store.dart — SharedPreferences
│   ├── notification_service.dart# GymMane rest_alarm.dart pattern
│   └── date_utils.dart          # Date helpers
├── theme/
│   ├── app_colors.dart          # GymMane app_colors.dart — ThemeExtension
│   └── app_theme.dart           # GymMane app_theme.dart — ThemeData
├── screens/
│   ├── dashboard_screen.dart
│   ├── calendar_screen.dart
│   ├── done_screen.dart
│   └── profile_screen.dart
├── widgets/
│   ├── task_card.dart
│   ├── hero_task_card.dart
│   ├── hero_carousel.dart
│   ├── weekly_bar_chart.dart
│   ├── monthly_calendar.dart
│   ├── custom_bottom_bar.dart
│   ├── new_task_sheet.dart
│   ├── reminder_picker_sheet.dart
│   └── ui_kit.dart              # GymMane ui_kit.dart — all primitives
└── domain/
    └── task_utils.dart          # getUrgency, getColor helpers
```

---

## Implementation Order

1. Phase 1 — Setup: pubspec, theme, colors, typography
2. Phase 2 — Models + State (ChangeNotifier + debounced save)
3. Phase 3 — main.dart boot sequence (pre-hydration)
4. Phase 4 — AppShell + CustomBottomBar (animated nav pill)
5. Phase 5 — UIKit primitives
6. Phase 6 — Dashboard screen
7. Phase 7 — NewTaskSheet + ReminderPickerSheet
8. Phase 8 — Calendar screen
9. Phase 9 — Done screen
10. Phase 10 — Profile screen
11. Phase 11 — Notifications
12. Phase 12 — Polish (haptics, zero-ripple, animations)
