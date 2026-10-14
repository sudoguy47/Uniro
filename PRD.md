# Uniro (CampusTracker) — Product Requirements Document
**For: native Android rebuild (Kotlin + Jetpack Compose)**
**Source version:** `1.0.0+1`, package `com.example.uniro1` (⚠️ change to your own applicationId, e.g. `com.uniro.app`)
**Generated from:** full Flutter codebase audit (all screens, state, services, native widget code).

---

## 1. Product overview

Uniro is an **offline-first campus task + notes app for students**. No login, no backend, no account. All data lives on-device. Core loop: create tasks with due dates → get reminded → complete → track in calendar → take study notes.

### 1.1 Design principles (must preserve)
- Offline-first, instant launch, zero network calls in normal use.
- One-handed use: primary actions (save, new note, complete) within thumb reach.
- Warm paper-like aesthetic, heavy rounded corners (12–24dp), soft haptics on taps.
- Light / Dark / System theme.

---

## 2. App map & navigation

Bottom tab bar with **5 tabs** (icons + labels, selection-click haptic on tap, selected icon scale-pops 1.0→1.15→1.0 in 200ms, label fades in; center Focus tab always accent and slightly larger at 30dp):

| # | Tab | Label | Icon (active / inactive) |
|---|-----|-------|--------------------------|
| 0 | Dashboard | Dashboard | grid_view rounded / outlined |
| 1 | Routine | Routine | calendar_month rounded / outlined |
| 2 | Focus | Focus | timer rounded / outlined (placeholder screen until the timer is built) |
| 3 | Notes | Notes | description filled / outlined |
| 4 | Profile | Profile | person rounded / outlined |

- Tabs are named `AppTab` enum values (no magic indexes); `AppShell.openTab()` allows notification taps/deep links to switch. No tab index is persisted anywhere, so no migration exists.
- The old Calendar tab is removed (`calendar_screen.dart` + `monthly_calendar.dart` deleted — verified unused elsewhere). The Done tab is removed; its content lives in the Dashboard Active|Completed toggle (DoneScreen widget reused, built lazily, kept alive).

- Tab switching = instant page jump (no swipe gesture between tabs, no animation).
- When the New-Task sheet is open, the bottom bar slides away (200ms).
- Dashboard header "+" popover (Create task / Add class routine) replaces the old FABs — there are no duplicate create buttons. "+" rotates 45° while open; tap-outside/Back closes.
- Bar: top hairline border + soft upward shadow; height 58dp + system inset.
- All 5 pages are kept alive (no reload when switching tabs).
- App state (tasks+settings) persists on background/close; notes flush on background.

---

## 3. Focus (tab 2) — flip-clock Pomodoro

- Premium flip-clock UI (no scrolling): phase chip + sliding 3-segment durations (long-press edits), 2×2 split-flap digit cards (150ms + 190ms halves, perspective, shade overlay; 40ms stagger on bulk changes; 120ms crossfade on reduce-motion), pulsing colon dots, session mini-cards, START pill, reset ring-button, 4-icon mode pill above the nav. Small screens (<640dp) shrink the card aspect; landscape lays the four cards in one row.
- Modes: Pomodoro (focus + auto breaks), One block (single countdown), Stopwatch (count-up, HH:MM past 99:59). Breaks auto-start per settings (default: breaks on, next-focus off).
- Engine (`FocusState`): wall-clock endTime persisted in `ct_focus_engine`; restore on launch advances phases ended away (records elapsed focus blocks, max 30 steps); 1s ticker drives ONLY per-digit ValueNotifiers (nothing else rebuilds); phase-end notification id `800001` (silent fallback without permission); sessions recorded on completion or finish-early ≥5 min / stopwatch-stop ≥5 min.
- Task/Course linking sheet with search (chip shows "FOCUS #n · CODE"); summary sheet after recorded sessions (tree visual, today totals, Take-a-break / Mark-task-complete? / Done); duration editor + settings sheets (long-break cadence 2–8, auto toggles, haptics → Profile, strict disabled, study-log link → Study Log step); mini "Focus MM:SS" bar above nav on other tabs.
- Haptics via existing `PremiumHaptics` (tick=select, click=tap, confirm/warning/heavy=confirm). No Strict mode / lock / DND layer (explicitly removed from scope).
- Completed focus blocks recorded as `FocusSession` (id, date, startedAt ISO, minutes, optional courseId/taskId, isManual) in `ct_focus_sessions`, trimmed to the last 500 — the source the Study Log aggregates.

## 3. Onboarding (first launch only)

Shown when `onboarding_done != true`. 4 swipeable slides, full-screen background color per slide with 300ms animated color transition, white text.

| Slide | BG | Mascot (animated: gentle bob + blink ~3.4s) | Headline | Sub |
|-------|----|----------------------------------------------|----------|-----|
| 1 | Orange `#D97E36` | Graduate face: white round face, black eyes with shine, smile, blush, black grad-cap board + swinging orange tassel | GET YOUR CAMPUS TASKS DONE. | Stay on top of every deadline, stress-free. |
| 2 | Blue `#3E6FA8` | Calendar: white rounded calendar, blue header band, black binder-tab eyes, smile, 5×3 date dots (one orange, one green), slight tilt wobble | NEVER MISS A DEADLINE AGAIN. | Visual calendar keeps every due date in one place. |
| 3 | Green `#4C7A5B` | No mascot — floating doodles (pencil top-left, mini grad-cap mid-left, stacked books bottom-right, slow drift) | WHAT'S YOUR NAME? | We'll personalise your experience. + name TextField (rounded 16dp, translucent white, person icon, hint "Enter your name…") |
| 4 | Purple `#8B5E9E` | Reminder bell: white bell, purple skirt band, orange clapper, swinging rotation | GET REMINDERS BEFORE IT'S TOO LATE. | Smart alerts keep you ahead. + "Enable Reminders" pill button (turns to "Reminders On" w/ check when granted) |

Chrome (all slides): "Uniro" wordmark top-left (27sp, 900 weight); dot indicators (active = 22dp white pill, inactive = 7dp 40% white); bottom row = **Skip** (left, finishes with defaults: name "Student") and **Next / Let's Start** (right, white bold + 54dp circled arrow button, translucent white + white border).
- Slides 1–3 button = Next; slide 4 = Let's Start → saves name/avatar-choice/notifications flag → marks onboarding done → fade (300ms) to main app.
- **Native note:** draw mascots as Compose `Canvas` with `rememberInfiniteTransition` (bob) + timed blink state. No Lottie/Rive needed.

---

## 4. Dashboard (tab 0)

Scrollable Active feed / lazily-built Completed view (DoneScreen reused) behind an Active|Completed segmented toggle that sits after the Weekly load chart in the scroll flow (top of the Completed view). Choice persisted in settings. Header adds a "+" quick-create popover.

### 4.0 Next-class card (top of Active feed, hidden when nothing left today)
- Dark card: "NEXT CLASS" caps, course code·name, 12h time range + room, live pill ("in 45 min" / "Now · ends in 20 min", refreshed by a 1-minute Timer owned by the card). Tap → Routine tab.

### 4.1 Header (fixed 66dp text zone — height NEVER changes)
- Row: text block (left, vertically centered) + avatar circle 48dp (right, taps → Profile tab).
- **Greeting view (default): ONE line only**, 24sp/800, single-line ellipsis, left-aligned. Format = first name only:
  - 05–08 → `Rise and shine, {First}! ☀️`
  - 08–12 → `Good morning, {First}!`
  - 12–15 → `Hey, {First}! 🌤️`
  - 15–18 → `Keep it up, {First}!`
  - 18–21 → `Good evening, {First}! 🌆`
  - 21–24 → `Still studying, {First}? 🌙`
  - 00–05 → `Midnight grind, {First}? 🌙`
- **Quote view:** 3s after dashboard appears, header auto-swaps (fade+slide 250ms) to `DAILY FUEL` label (11sp, accent, letterspaced) + quote of the day (16sp/800, max 2 lines, ellipsis, in quotes).
- Tap or vertical swipe (>48dp) toggles greeting ⇄ quote manually; manual toggle cancels the 3s timer.
- Quote of the day = the user's 20 quotes cycled strictly one per day in order (`dailyQuotes[dayOfYear % 20]` — no repeats within a cycle, no randomness):
  1. Good morning! Today is another chance to become who you want to be. 2. Wake up with gratitude, move forward with purpose. 3. A new day, a fresh start, endless possibilities. 4. Start small, stay consistent, and trust your growth. 5. Let today be guided by kindness and curiosity. 6. You don't need to have it all figured out. Just take the first step. 7. Every sunrise is a gentle reminder that you can begin again. 8. Make today count, not by doing everything, but by doing what matters. 9. Fill your mind with knowledge and your heart with kindness. 10. Good things take time. Be patient with yourself today. 11. Before chasing your dreams, take a moment to be grateful for this day. 12. Let your actions reflect your dreams, and your kindness reflect your character. 13. A peaceful mind and a willing heart are a beautiful way to begin the day. 14. Learn something new, help someone out, and grow a little today. 15. Don't let yesterday's mistakes steal today's opportunities. 16. May your day be productive, your heart be light, and your intentions be good. 17. Do your best today, and leave the rest to God. 18. You are here to learn, to grow, and to make a difference. 19. Take a deep breath. You're allowed to grow at your own pace. 20. Good morning! Become a little wiser, kinder, and stronger today.

### 4.2 Hero carousel
- Horizontally swipeable cards (88% viewport width), height 130dp, auto-advances every **4s** (450ms ease-in-out), pauses while user drags, pauses when app backgrounded, resumes 3s after manual swipe.
- Shows first **6 pending tasks** (sorted by due date). Card = colored bg by urgency (see §10.3) + title (white bold 17sp, 1 line) + type pill (translucent white) + optional description (2 lines, 70% white) + bottom row (calendar icon + due date; urgency pill, white bg).
- Dots below (active 16dp accent pill / 6dp border dots). Empty → section hidden.

### 4.3 Weekly load (single chart)
- Card with 7 bars ordered from the week-start setting (default Saturday). Bar height ∝ count (min 12dp, empty = 8dp stub). Colors: empty = `chartBarEmpty`, normal = red, selected-day = accent with 2dp accent border.
- Tapping a bar selects that day: floating count chip appears (`"N task(s)"` on dark pill), label turns accent. Header row: "Weekly load" left + "{N} due this week" right. Footer hint: "Tap a bar to filter that day".

### 4.4 Filter chips
- Horizontal scroll list: **All + 9 types** (Assignment, Exam, CT, Viva, Presentation, Lab, Project, Other, Custom). Active chip = dark pill w/ light text; inactive = card bg + border. Tapping sets pending-list filter.

### 4.5 Pending task list
- Cards 72dp + 8dp gap, fixed extents. Card = 36dp type-icon tile + title (15sp/600, 1 line) + subtitle `"{Type} · {Overdue|Due today|Upcoming}"` (13sp) + circular check button (36dp, 2dp border; completed state = accent fill + white check).
- Tap check = 80ms press animation, haptic, completes **immediately** (no waiting for animation). Completed tasks leave the list.
- Empty state: centered "No pending tasks".

---

### 4.0 Next-class card (top of Active feed, hidden when nothing left today)
- Dark card: "NEXT CLASS" caps, course code·name, 12h time range + room, live pill ("in 45 min" / "Now · ends in 20 min", refreshed by a 1-minute Timer owned by the card). Tap → Routine tab.

---

## 5. Routine (tab 1)

- Header: "Routine" + accent "+ Add class" pill.
- 7-day selector ordered from the week-start setting (default Saturday): chips with short name + date, today gets an accent ring, selected day = 200ms animated dark pill.
- Day cards: 12h time range, course code·name with course color bar, room + teacher line. Running class → accent "Now" badge; finished/past → dimmed (+ attendance check via hook, wired in the attendance step).
- Tap → sheet: class info + Edit / Delete (confirm dialog, shrink+fade-out, 4s undo SnackBar) / disabled "Attendance — coming next" row.
- Entrance: fade + 12px slide-up, 30ms stagger on day change (skipped on reduce-motion). Empty day: icon + "No classes this day" + Add button.
- Add/edit form (bottom sheet): course picker with inline New-course form (name*, code, teacher, room, credits, 8-color palette); weekday multi-select chips (Mo–Su, one slot per day; edit = single); start/end pickers (default 09:00–10:30); room (falls back to course room); reminder dropdown None/5/10/15/30 (default 15). Validates course set, day set, end-after-start. Overlap with another class → warning dialog with the conflicting class, Save-anyway/Cancel.
- Courses managed in Profile > Courses (add/edit/delete with counts). Deleting a course deletes its classes + reminders and unlinks its tasks/notes (explicit confirm).
- Data: `Course` (id, name, code?, colorTag?, teacher?, room?, credits?) and `ClassSlot` (id, courseId, weekday 1–7, start/end minutes, room?, reminderMinutesBefore? default 15) in `ct_courses`/`ct_slots` (400ms debounce, loaded pre-first-frame). One-time migration converts the old dashboard mini-routine entries (then deletes the old key). Tasks/notes carry optional `courseId` (old JSON valid); New-Task sheet has an optional Course row; deleting a course nulls the links.

---

## 6. Notes (tab 3)

### 6.1 Notes list
- Header "Notes" + search icon → expanding search field (autofocus, 200ms debounce, matches title + block text, clears on close).
- Folder chips row: **All, Pinned, {user folders}** with per-folder counts; "+" chip → "New Folder" dialog; long-press folder → bottom sheet (Rename / Delete; deleting moves its notes to Personal).
- Default folders: **Personal, Study, Work**. Creating a note while in All/Pinned → goes to Personal.
- Sections: **PINNED** grid then **ALL NOTES** grid (2-column staggered rows).
- Note card: title + first-3-non-empty-blocks preview + updated date (`MMM d` / `MMM d, yyyy`), color-tag accent, lock icon if locked, pin indicator; entrance = 280ms fade+slide staggered 40ms/index (max 300ms); tap → editor (slide-up 280ms); delete → 4s Snackbar with **UNDO**.
- Empty state illustration + text. Floating pill above nav bar: **New Note** (+ icon) and **New Checklist** shortcuts.

### 6.2 Note editor
- Top bar: back | folder name w/ dropdown (move-to-folder sheet) | pin toggle | more (⋯) → sheet with **Folder / Lock-Unlock / Color Tag / Delete**.
- Title field (22sp bold, hint "Untitled") + date line `Weekday, Month D, YYYY · {Folder}`.
- **Block model** (ordered list): Enter at end of a block inserts a new paragraph block below and focuses it; Backspace on empty block deletes it (or converts checklist/quote → paragraph); focus tracking drives the formatting bar.
- Block types: **paragraph** (15sp, 1.5 line-height), **checklist** (14sp, animated 20dp checkbox, checked = 50% faded + strikethrough, ✕ button converts/removes), **quote** (15sp italic, accent left bar 3.5dp + quote icon + tinted bubble).
- Inline style per block: **bold, italic, text color** (Default/Red/Orange/Green/Blue/Purple/Gray), **highlight** (None/Yellow/Green/Blue/Pink/Orange/Lavender), **font size**, **alignment** (left/center/right). (Span-range model exists for future per-word styling.)
- Bottom formatting bar: format-list icon (opens full sheet: colors, highlights, sizes, alignment, insert paragraph/checklist/quote) + B + I + checklist + quote quick toggles (active = tinted) + **"Autosaved"** label.
- Persistence: 500ms-debounce autosave on every keystroke; forced save on exit; empty notes (no title + all blocks blank) are never stored.
- Color tags: none + Orange/Green/Blue/Purple/Red circle swatches.
- Lock = flag only (no encryption/passcode in v1 — keep same in native, or upgrade to biometric).

---

## 7. Completed (Dashboard toggle — ex Done tab)

- Same content as the old Done tab: "Completed" + "{N} tasks completed".
- Completed cards (accent-filled check). Tap check = **uncomplete** (returns to pending); trash icon = **permanent delete** (no undo).
- Empty state: check-circle outline + "No completed tasks yet".

---

## 8. Profile (tab 4)

Cards on 16dp page padding:
1. **Profile card:** 80dp avatar (tap → gallery pick, downscaled to 512px max, 80% JPEG; initial-letter fallback on accent circle) + camera badge; name row (tap → "Edit Name" dialog, non-empty enforced); caption "Stored on this device".
2. **Reminders card:** "Assignment & CT" day-stepper (default 2) and "Exam, Viva & Project" stepper (default 3), range 0–30, bounce animation; divider rows; **Notifications Enabled** switch (off = cancel ALL notifications incl. daily; on = prompt permission + reschedule everything).
3. **Courses card:** count + chevron → Courses screen.
4. **App Theme card:** Light / System / Dark segmented buttons (140ms animated).

---

## 9. New-Task sheet (Dashboard "+" popover → Create task)

- Overlay sheet, 88% max height, 220ms slide-up + fade, drag handle, "New Task" title + ✕; backdrop tap / system back closes (reverse animation). Floating **Save Task** pill button (52dp, accent glow shadow) always visible above keyboard.
- Fields:
  - **TITLE** (required — Save disabled/no-op if blank): hint "e.g. Algorithms Class Test".
  - **DESCRIPTION** (optional, 2–3 lines): hint "Optional notes, syllabus, room number…".
  - **CATEGORY / TYPE** (48dp field → bottom sheet, max 72% height, **scrollable** list, drag handle, check on current): Assignment, Exam / Final, Class Test (CT), Viva Voce, Presentation, Lab / Class, Project, Other / Lecture, **Custom** (tune icon).
  - **COURSE (OPTIONAL)** (48dp field → bottom sheet, None default): links the task to a course (per-course stats, study log).
  - **DUE DATE** + **DUE TIME** side by side (system date/time pickers; date range past-1y → +2y; time defaults 09:00). "Set specific reminder time" switch enables time.
  - **PRIORITY**: High / Medium (default) / Low segmented (44dp, accent border when active).
  - **NOTIFICATIONS & REMINDERS**: chips of added reminders (accent, ✕ to remove) + "Add Reminder" dashed button → sheet with radio list: **At time of event / 1 hour / 1 day / 3 days / 1 week / Custom (N days before, stepper 1–30)** + "Add Reminder" button. Multiple reminders per task allowed.
- Save: haptic → task added → filter resets to All → notifications scheduled → sheet closes.

---

## 10. Task domain rules

### 10.1 Task fields
`id` (uuid-ish hex), `title*`, `description?`, `type` (9 enums), `dueDate` (`yyyy-MM-dd`), `dueTime?` (`HH:mm`), `hasTime` (bool), `priority` (high/medium/low), `status` (pending/completed), `reminders[]` (`id`, `type`, `customDays?`, `notificationId?`), `createdAt` (ISO), `completedAt?` (ISO), `courseId?` (nullable link).

### 10.2 Reminder fire times (relative to due datetime, default 09:00 if no time)
atTime = due datetime; oneHour = −1h; oneDay = −1d; threeDays = −3d; oneWeek = −7d; custom = −N days. Past times are skipped. Completing a task cancels its notifications; uncompleting reschedules; deleting cancels.

### 10.3 Urgency (drives colors + labels + calendar dots)
- `dueDate < today` → **Overdue** (red `#D94F3D`, label "Overdue")
- `dueDate == today` → **Due today** (accent orange, "Due today")
- else → **Upcoming** (green `#5A8A5A`, "Upcoming"); completed → gray.
- Hero card bg = urgency color; calendar dots: overdue red / due-today orange / exam-type gold `#C9962A` / else green.

### 10.4 Lists & sorting
Pending = status pending (+ active type filter), sorted by dueDate asc. Hero = first 6 pending. Completed = status completed (insertion order). Counts cached; weekly load = per-day pending counts for Mon–Sun.

### 10.5 First-launch seed (only when no stored tasks)
14 realistic CSE tasks: 11 pending spread today → +12d (OS Assignment, DBMS Quiz, CN Lab, SE Project Demo, Compiler Midterm, AI Presentation, Microprocessor Viva, Discrete Math PS, Next.js Workshop, BLoC Lab, Ray Tracing Mini-Project — each with sensible times/priorities/reminders) + 3 completed (past dates with completedAt).

---

## 11. Notifications (exact spec for native)

- Channel: id `campus_tracker_reminders`, name "Task Reminders", desc "Notifications and scheduled reminders for campus tasks, classes, and exams", importance MAX, sound+vibration+badge, icon = launcher icon.
- Permissions: `POST_NOTIFICATIONS` (33+), `SCHEDULE_EXACT_ALARM` + `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`.
- Task notifications: exact alarms (`setExactAndAllowWhileIdle` / `SCHEDULE_EXACT_ALARM`), title `[TYPE] {title}`, body `Due on {date}[ at {time}] ({reminder})`. Stable int id = hash(taskId [+ reminderId]) — same id overwrites on reschedule. Tap payload = taskId (open app; deep-link to task optional).
- **Daily greeting:** id `900001`, fires **06:00 local daily** (repeating; if 6 AM passed, next day), title `Rise and shine, {FullName}! ☀️`, body = that day's entry from the same 20-quote rotation as the header (§4.1) — the quote you wake up to is the quote on your dashboard all day.
- **Class reminders:** ids `500000–599999` (persisted counter, wraps; map `slotId|yyyy-MM-dd → id` in `ct_class_notif_map`). One notification per slot occurrence for the next 14 days (no infinite repeats): title `{code} in {N} min`, body `{course} · {12h range} · {room}`, payload `class|<slotId>|<date>`. Full rebuild on class/course change + every launch (covers reboot/timezone); per-slot cancel on edit/delete. Skipped when master toggle off or reminder = None. Exact-alarm failures degrade silently per slot. Re-scheduled on every app start (covers reboot), on name change, on settings change; cancelled when master toggle off.
- Native mapping: `AlarmManager.setExactAndAllowWhileIdle` + `BroadcastReceiver` (re-schedule all on `BOOT_COMPLETED`), or WorkManager periodic + exact one-shots. Notification tap → `MainActivity` with task id extra.

---

## 12. Home-screen widgets (native — rebuild in Glance)

Two widgets, dark cards, tap anywhere → open app. Data read from the **same store** the app writes (Flutter used `SharedPreferences` file `FlutterSharedPreferences`, key `flutter.ct_tasks` = JSON array of tasks; **native should use its own DataStore/Room + Glance `updateAppWidgetState`**, or keep a SharedPreferences JSON bridge for simplicity).
Refresh triggers: every task mutation, settings save, app resume.

- **Weekly Load widget:** "{N} due this week" + custom-drawn 7-bar chart (560×160 canvas: red bars scaled to max, dark stubs for empty, Mo–Su labels + day numbers, today highlighted orange) + next-upcoming task (title + `Type · Due Today|Due Tomorrow|Overdue|Due {date}`) or empty text.
- **Monthly Heatmap widget:** month grid with per-day task dots (same color rules as §10.3).

---

## 13. Theming tokens (exact hex)

| Token | Light | Dark |
|---|---|---|
| pageBg | `#EDE8DF` | `#0F0E0C` |
| cardBg | `#FFFFFF` | `#1C1A17` |
| cardBgRaised / inputBg | `#F5F0E8` | `#252219` / `#2A2620` |
| border / borderLight | `#E0D9CF` / `#EDE8E0` | `#3A3630` / `#302C26` |
| textPrimary / Secondary / Tertiary | `#1A1713` / `#6B6057` / `#9E9589` | `#F5F0E8` / `#9E9589` / `#6B6057` |
| accent / accentLight / accentDark | `#E8963C` / `#FDF0E0` / `#C67C28` | `#E8963C` / `#2A1F0A` / `#C67C28` |
| overdue / dueToday / upcoming | `#D94F3D` / `#E8963C` / `#5A8A5A` | same hues |
| navBg / navActiveBg / navActiveText / navInactive | `#FFF` / `#1A1713` / `#FFF` / `#9E9589` | `#1C1A17` / `#F5F0E8` / `#1A1713` / `#6B6057` |
| chartBarRed / Gold / Empty | `#D94F3D` / `#C9962A` / `#E8E3DC` | same / same / `#2A2620` |
| fabBg / fabIcon | `#1A1713` / `#FFF` | `#F5F0E8` / `#1A1713` |
| toggleActive / Inactive | `#E8963C` / `#D0C9C0` | `#E8963C` / `#3A3630` |

Motion: micro 140ms, fast 200ms, sheet 220–280ms, header swap 250ms, carousel 450ms. Curves: easeOutCubic everywhere. Typography: system/Inter-style sans; headline 28sp/800, greeting 24sp/800, card title 15sp/600, body 13–15sp. Haptics: tap = lightImpact (buttons/cards), select = selectionClick (tabs/chips/switches — navbar whisper-light), confirm = mediumImpact (save/complete/delete), scroll-boundary edge thock = mediumImpact once per gesture via global BoundaryHaptics layer (re-armed per scroll gesture, 500ms floor).

---

## 14. Data & storage (native mapping)

| Flutter | Native equivalent |
|---|---|
| `SharedPreferences` `ct_tasks` (JSON array of Task) | Room table `tasks` (columns = §10.1; `reminders` = embedded JSON string) |
| `ct_settings` (JSON UserSettings) | DataStore Preferences: `name` (default "Student"), `avatarUri?`, `assignmentReminderDays` (2), `examReminderDays` (3), `notificationsEnabled` (true), `theme` (LIGHT), `weekStartDay` (6 = Saturday), `dashboardView` ("active"), `minAttendancePercent` (75), `dailyStudyGoalMinutes` (0 = off) |
| `ct_routine` | MIGRATED on first launch into courses+slots, then deleted |
| `ct_courses` (JSON array of Course) | Room table `courses` |
| `ct_slots` (JSON array of ClassSlot) | Room table `class_slots` |
| `ct_onboarding_done` (bool) | DataStore `onboarding_done` |
| `uniro_notes_v1` (JSON array of Note) | Room tables `notes` + `blocks` (or JSON-in-DataStore; Room preferred) |
| `uniro_note_folders_v1` (string list) | DataStore string-set, default [Personal, Study, Work] |
| Avatar image file path | app-private files dir + Coil/AsyncImage, fallback = initial letter |
| JSON date format `yyyy-MM-dd`, times `HH:mm`, ISO-8601 timestamps | same (keeps data importable) |

State layer: single `AppViewModel` (tasks+settings, StateFlow, 400ms save debounce) + `NotesViewModel` (350ms debounce) — mirrors AppState/NotesState, including memoized derived lists (pending/hero/completed/weeklyLoad).

---

## 15. Startup & lifecycle
1. Load prefs + notes + tasks off main thread before first frame (splash).
2. Empty task store → seed §10.5 and persist.
3. Render immediately with hydrated data (no empty flash).
4. Post-first-frame (idle): warm fonts, init notification channel, reschedule all task alarms + daily 6 AM greeting.
5. Background/close → persist tasks+settings, flush notes. Re-arm alarms on boot.

---

## 16. Acceptance checklist (test these on device)
- [ ] Fresh install → onboarding 4 slides → name saved → dashboard seeded with 14 tasks.
- [ ] New task with 2 reminders → 2 exact notifications at right times; complete → both cancelled.
- [ ] Reboot → alarms still fire (re-armed on BOOT_COMPLETED + app start).
- [ ] 6 AM daily greeting with rotating life quote; rename → next notification uses new name; toggle off → silent.
- [ ] Header: correct greeting per time table; quote auto-appears at 3s; height never jumps; swipe/tap toggles.
- [ ] Category sheet scrolls to Custom on small screens; Custom tasks filter + notify normally.
- [ ] Calendar dots match urgency colors; Monday-first weeks; FAB pre-fills selected date.
- [ ] Notes: create paragraph + checklist, bold/italic/color/highlight, pin, lock, color tag, folder move/rename/delete, search finds block text, delete → UNDO restores, airplane-mode editing never loses text (autosave).
- [ ] Both widgets update within seconds of any task change; tap opens app.
- [ ] Theme: Light/Dark/System all readable; no white-on-white or black-on-black text.
- [ ] No crashes with 500+ tasks, 100+ notes, DND mode, or revoked notification permission (degrade silently).

## 17. Explicitly out of scope for the native port
OTA self-update system (was removed — dead code pointing at a placeholder repo), WebView onboarding (replaced by native), cloud sync / accounts (does not exist — do not add), note encryption (lock is a flag only).
