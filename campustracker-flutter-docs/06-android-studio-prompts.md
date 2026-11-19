# 06. Android Studio — Flutter Prompts

> এই prompts সরারসরি **Android Studio এর Gemini / AI Assistant**-এ paste করবে।
> অথবা project ফোল্ডর সহ **Cursor** বা **Antigravity**-এও দিতে পারাবে।
> Phase অনুযায়ী একটা একটা। সব একসাথে দেবে না।

---

## ✅ PHASE 1 — Flutter Project Setup

```
Create a new Flutter project called "campustracker" in Android Studio with these exact settings:

FLUTTER VERSION: 3.x latest stable
PLATFORM: Android only (minSdkVersion 21)
LANGUAGE: Dart

Add these dependencies to pubspec.yaml:

dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  shared_preferences: ^2.3.2
  flutter_local_notifications: ^18.0.1
  timezone: ^0.9.4
  intl: ^0.19.0
  uuid: ^4.4.0
  image_picker: ^1.1.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

Also in pubspec.yaml, add fonts section:
fonts:
  - family: Inter
    fonts:
      - asset: assets/fonts/Inter-Regular.ttf
        weight: 400
      - asset: assets/fonts/Inter-Medium.ttf
        weight: 500
      - asset: assets/fonts/Inter-SemiBold.ttf
        weight: 600
      - asset: assets/fonts/Inter-Bold.ttf
        weight: 700
      - asset: assets/fonts/Inter-ExtraBold.ttf
        weight: 800

Create folders:
  lib/app/
  lib/models/
  lib/state/
  lib/services/
  lib/theme/
  lib/screens/
  lib/widgets/
  lib/domain/
  assets/fonts/

Download Inter font from fonts.google.com and place the 5 TTF files in assets/fonts/.

In AndroidManifest.xml add:
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
  <uses-permission android:name="android.permission.VIBRATE"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

---

## ✅ PHASE 2 — Theme System

```
In the CampusTracker Flutter project, create the theme system.
This is the MOST important step — all other files depend on it.

Create lib/theme/app_colors.dart:

Create a ThemeExtension<AppColors> class with these EXACT color fields:
  pageBg, cardBg, cardBgRaised, inputBg, border, borderLight,
  textPrimary, textSecondary, textTertiary,
  accent, accentLight, accentDark,
  overdue, overdueLight, dueToday, upcoming,
  navBg, navActiveBg, navActiveText, navInactive,
  chartBarRed, chartBarGold, chartBarEmpty,
  fabBg, fabIcon, toggleActive, toggleInactive

Light mode values (Color(0xFF...)):
  pageBg:         0xFFEDE8DF
  cardBg:         0xFFFFFFFF
  cardBgRaised:   0xFFF5F0E8
  inputBg:        0xFFF5F0E8
  border:         0xFFE0D9CF
  borderLight:    0xFFEDE8E0
  textPrimary:    0xFF1A1713
  textSecondary:  0xFF6B6057
  textTertiary:   0xFF9E9589
  accent:         0xFFE8963C
  accentLight:    0xFFFDF0E0
  accentDark:     0xFFC67C28
  overdue:        0xFFD94F3D
  overdueLight:   0xFFFCE8E5
  dueToday:       0xFFE8963C
  upcoming:       0xFF5A8A5A
  navBg:          0xFFFFFFFF
  navActiveBg:    0xFF1A1713
  navActiveText:  0xFFFFFFFF
  navInactive:    0xFF9E9589
  chartBarRed:    0xFFD94F3D
  chartBarGold:   0xFFC9962A
  chartBarEmpty:  0xFFE8E3DC
  fabBg:          0xFF1A1713
  fabIcon:        0xFFFFFFFF
  toggleActive:   0xFFE8963C
  toggleInactive: 0xFFD0C9C0

Dark mode values:
  pageBg:         0xFF0F0E0C
  cardBg:         0xFF1C1A17
  cardBgRaised:   0xFF252219
  inputBg:        0xFF2A2620
  border:         0xFF3A3630
  borderLight:    0xFF302C26
  textPrimary:    0xFFF5F0E8
  textSecondary:  0xFF9E9589
  textTertiary:   0xFF6B6057
  accent:         0xFFE8963C  (same)
  accentLight:    0xFF2A1F0A
  accentDark:     0xFFC67C28
  overdue:        0xFFD94F3D  (same)
  overdueLight:   0xFF2A0E0A
  dueToday:       0xFFE8963C  (same)
  upcoming:       0xFF5A8A5A  (same)
  navBg:          0xFF1C1A17
  navActiveBg:    0xFFF5F0E8
  navActiveText:  0xFF1A1713
  navInactive:    0xFF6B6057
  chartBarRed:    0xFFD94F3D
  chartBarGold:   0xFFC9962A
  chartBarEmpty:  0xFF2A2620
  fabBg:          0xFFF5F0E8
  fabIcon:        0xFF1A1713
  toggleActive:   0xFFE8963C
  toggleInactive: 0xFF3A3630

Create lib/theme/app_theme.dart:

class AppTheme with these STATIC constants:
  micro    = Duration(milliseconds: 140)
  fast     = Duration(milliseconds: 200)
  screen   = Duration(milliseconds: 260)
  navGlide = Duration(milliseconds: 340)
  modal    = Duration(milliseconds: 320)
  easeOutCubic = Curves.easeOutCubic
  switchIn  = Interval(0.3, 1.0, curve: Curves.easeOutCubic)
  switchOut = Interval(0.6, 1.0, curve: Curves.easeOutCubic)

build(AppColors c, Brightness brightness) returns ThemeData:
  fontFamily: 'Inter'
  scaffoldBackgroundColor: c.pageBg
  CRITICAL: splashColor: Colors.transparent
  CRITICAL: highlightColor: Colors.transparent
  CRITICAL: splashFactory: NoSplash.splashFactory
  extensions: [c]
```

---

## ✅ PHASE 3 — Models & State (GymMane FitState Pattern)

```
Create the data models and state management for CampusTracker.
This follows GymMane's EXACT architecture pattern.

Create lib/models/task.dart:
  enums: TaskType, TaskPriority, TaskStatus, ReminderType
  class Reminder: id(uuid), type, customDays?, notificationId?, toJson(), fromJson()
  class Task: id(uuid), title, description?, type, dueDate(YYYY-MM-DD),
    dueTime?(HH:mm), hasTime, priority, status, reminders, createdAt, completedAt?
  Task must have: copyWith(), toJson(), fromJson()

Create lib/models/settings.dart:
  enum ThemeMode { system, light, dark }
  class UserSettings: name, avatarColor(default '#E8963C'),
    avatarUri?, assignmentReminderDays(default 2),
    examReminderDays(default 3), notificationsEnabled(default true), theme
  Must have: defaults() factory, toJson(), fromJson()

Create lib/services/local_store.dart:
  Singleton pattern (same as GymMane Store.instance)
  init() async: SharedPreferences.getInstance()
  save(key, data): prefs.setString('ct_key', jsonEncode(data)) - SYNCHRONOUS, no await needed after init
  load(key): prefs.getString then jsonDecode

Create lib/state/app_core.dart as a Mixin on ChangeNotifier:
  Private fields: _tasks, _settings, _activeFilter, _isLoaded
  Public getters for all

  CRITICAL — GymMane debounce pattern:
    Timer? _saveDebounce
    void _persist() {
      _saveDebounce?.cancel();
      _saveDebounce = Timer(const Duration(milliseconds: 400), persistNow);
    }
    void persistNow() {
      _saveDebounce?.cancel();
      LocalStore.instance.save('tasks', ...);
      LocalStore.instance.save('settings', ...);
    }

  void loadFromStore(): reads from LocalStore, populates _tasks + _settings, sets _isLoaded=true
  void addTask(Task): _tasks.add -> notifyListeners() -> _persist()
  void updateTask(id, Task): find + replace -> notifyListeners() -> _persist()
  void completeTask(id): set status=completed, completedAt -> notifyListeners() -> _persist()
  void deleteTask(id): remove -> notifyListeners() -> _persist()
  void setFilter(TaskType?): set _activeFilter -> notifyListeners() (NO persist)
  void updateSettings(UserSettings): set _settings -> notifyListeners() -> LocalStore.save (immediate)

  Computed getters:
    pendingTasks: filtered + sorted by dueDate
    completedTasks: status==completed
    heroTasks: pendingTasks.take(6)
    tasksForDate(date): dueDate==date
    weeklyLoad(weekStart): Map<String,int> for 7 days

Create lib/state/app_state.dart:
  final app = AppState();
  class AppState extends ChangeNotifier with AppCore {}

Create lib/domain/task_utils.dart:
  enum TaskUrgency { overdue, dueToday, upcoming, completed }
  TaskUrgency getUrgency(Task task)
  Color urgencyBorderColor(TaskUrgency u, AppColors c)
  Color cardBgColor(TaskUrgency u, AppColors c)
  String urgencyLabel(TaskUrgency u)
  String subtitleText(Task task) -> "Assignment · Overdue"
```

---

## ✅ PHASE 4 — main.dart & AppShell (GymMane Boot Pattern)

```
Create lib/main.dart following GymMane's EXACT boot sequence:

Future<void> main() async {
  // Step 1: binding
  WidgetsFlutterBinding.ensureInitialized();

  // Step 2: CRITICAL - edge to edge BEFORE widget tree (GymMane pattern)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  ));

  // Step 3: portrait only
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Step 4: CRITICAL - init disk storage BEFORE runApp (GymMane: await Store.instance.init())
  await LocalStore.instance.init();

  // Step 5: CRITICAL - load all state into RAM before first frame
  app.loadFromStore();

  // Step 6: notifications
  await NotificationService.instance.init();

  // Step 7: date formatting
  await initializeDateFormatting();

  // Step 8: runApp - first frame is real UI, no skeleton
  runApp(ChangeNotifierProvider.value(value: app, child: const CampusTrackerApp()));

  // Step 9: GymMane addPostFrameCallback - defer secondary work
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationService.instance.rescheduleAll(app.tasks);
  });
}

Create lib/app/app.dart:
  CampusTrackerApp: reads theme from app.settings,
  builds MaterialApp with CampusTrackerTheme,
  home: AppShell()

Create lib/app/app_shell.dart with these EXACT features:

1. StatefulWidget with WidgetsBindingObserver mixin
2. Track _route (AppRoute enum) and _prevRoute
3. didChangeAppLifecycleState: when paused/inactive/detached -> app.persistNow()

4. CRITICAL - GymMane double-buffered screen transition:
   AnimatedSwitcher(
     duration: AppTheme.screen, // 260ms
     switchOutCurve: AppTheme.switchOut, // Interval(0.6, 1.0, easeOutCubic)
     switchInCurve: AppTheme.switchIn,   // Interval(0.3, 1.0, easeOutCubic)
     transitionBuilder: FadeTransition + SlideTransition (8% of screen width)
     layoutBuilder: Stack with Positioned.fill (outgoing screen stays visible during transition)
     child: KeyedSubtree(key: ValueKey(_route))
   )

5. CRITICAL - GymMane algebraic nav pill:
   LayoutBuilder -> calculate slotX(i) = i * (width/4) + (width/4 - pillWidth) / 2
   AnimatedPositioned(duration: 340ms, curve: easeOutCubic, left: slotX(currentIndex))
   Pill: 80x48, navActiveBg color, radius: 999
   TweenAnimationBuilder for icon + label color lerp (200ms)
   GestureDetector with HapticFeedback.lightImpact() on tab tap
```

---

## ✅ PHASE 5 — UIKit Primitives

```
Create lib/widgets/ui_kit.dart with ALL these components in one file:

1. PrimaryButton:
   GestureDetector with onTapDown/Up/Cancel for press tracking
   AnimatedScale: scale 1.0->0.97 when pressed (100ms)
   HapticFeedback.lightImpact() on tap
   Container: h=56, radius=999, color=accent
   Text: white, 15px, bold
   Loading: CircularProgressIndicator white 20x20

2. TinySwitch (GymMane TinySwitch EXACT copy):
   GestureDetector onTap -> HapticFeedback.lightImpact()
   AnimatedContainer duration=140ms curve=easeOutCubic:
     width=44, height=26, padding=3
     alignment: value ? centerRight : centerLeft
     color: toggleActive or toggleInactive
   White circle thumb 20x20

3. AppFilterChip:
   GestureDetector -> HapticFeedback.selectionClick()
   AnimatedContainer duration=200ms:
     color: active ? navActiveBg : cardBg
     border: active=none : border color
   h=36, px=16, radius=999
   Text: active=navActiveText/bold, inactive=textPrimary

4. StepperControl:
   Row: [minus circle] [number] [plus circle]
   AnimationController for number scale bounce on change (140ms, 1.0->1.2->1.0)
   Circles: 32x32, border, cardBg
   HapticFeedback.selectionClick() on each tap

5. PrioritySelector:
   Row of 3 Expanded buttons: High, Medium, Low
   AnimatedContainer duration=200ms:
     active: color=accentLight, border=2px accent
     inactive: color=cardBg, border=1px border
   14px bold, active=accent, inactive=textSecondary
   height=44, radius=12, horizontal margin=4

6. RadioListItem:
   GestureDetector full row tap -> HapticFeedback.selectionClick()
   AnimatedContainer radio circle 20x20 duration=140ms:
     selected: border=2px accent + inner dot 10x10 accent
     unselected: border=2px borderColor
   Label 15px textPrimary
   Separator: Divider height=1 color=borderLight

7. SoftCard (generic card container):
   Container: color=cardBg, radius=16, border=1px border, clip=hardEdge
   Accept child + padding parameter
```

---

## ✅ PHASE 6 — Task Widgets

```
Create task-related widgets for CampusTracker:

1. lib/widgets/task_card.dart:
StatefulWidget with SingleTickerProviderStateMixin
AnimationController _checkCtrl: lowerBound=0.88, upperBound=1.0, duration=80ms, reverseDuration=120ms

On complete button tap:
  HapticFeedback.mediumImpact()
  await _checkCtrl.reverse() then forward()
  widget.onComplete()

Layout (IntrinsicHeight + Row):
  Left border: Container width=3, height=full, color=urgencyBorderColor(urgency, c)
  Content (Padding 14):
    Row:
      Icon box 36x36: cardBgRaised bg, radius=8, Icons.description_outlined 18px
      SizedBox(12)
      Expanded Column:
        Title: 15px w600, lineThrough+textTertiary if showCompleted else textPrimary
        Subtitle: 13px textSecondary, "Assignment · Overdue" format
      SizedBox(12)
      Row:
        if showCompleted: delete icon 18px textSecondary + SizedBox(8)
        ScaleTransition(scale: _checkCtrl):
          GestureDetector -> _onComplete
          AnimatedContainer 36x36 circle 140ms:
            showCompleted: bg=accent, border=accent, white check icon
            pending: transparent bg, border=border

Card container: color=cardBg, radius=16, border=1px, clipBehavior=hardEdge, mb=8

2. lib/widgets/hero_task_card.dart:
StatelessWidget
Props: task, screenWidth
Width = screenWidth - 48, height = 130, radius = 20, padding = 16
Bg color = cardBgColor(urgency, c)

Layout:
  Top Row:
    Text(title, white bold 17px, flex=1)
    Type badge: Container px=8 py=3 radius=full
      bg=white.withOpacity(0.2), text=type.name.toUpperCase() white 11px bold
  Middle: Text(description, white70, 13px, maxLines=2, mt=8)
  Bottom Row (Spacer above):
    Icon(calendar, 14px, white60) + Text(date, white 13px)
    Spacer()
    Urgency badge: Container px=10 py=4 radius=full
      bg=white.withOpacity(0.9)
      text=urgencyLabel, color=urgencyBorderColor, 11px bold

3. lib/widgets/hero_carousel.dart:
StatefulWidget, PageController
PageView.builder: items from heroTasks
  Each item: Padding(h=8) + HeroTaskCard
  PageView padding: EdgeInsets.symmetric(horizontal=16)
  viewportFraction: (screenWidth-48)/screenWidth

Dot indicators below:
  Row(center, mt=12):
  For each task: AnimatedContainer duration=200ms:
    active: w=16, h=6, color=accent
    inactive: w=6, h=6, color=borderColor
  radius=full, gap=6
  Update _currentPage in onPageChanged
```

---

## ✅ PHASE 7 — Chart Widgets

```
Create chart widgets for CampusTracker:

1. lib/widgets/weekly_bar_chart.dart:
Props: weekStart(String), load(Map<String,int>), selectedDay?, onDayPress

Container: cardBg, radius=16, padding=16

Days: ['Mo','Tu','We','Th','Fr','Sa','Su']
For each day index i:
  date = weekStart + i days
  count = load[date] ?? 0
  maxCount = max value in load (min 1)
  barHeight = count > 0 ? max(8.0, (count/maxCount)*80) : 8.0

Row of 7 bars with GestureDetector:
  Each bar column: Expanded
    Column(bottom-aligned):
      GestureDetector(onTap: onDayPress(date))
      Stack: bar + optional border
      Container:
        width: full, height: barHeight
        color:
          count==0: chartBarEmpty
          i < 4: chartBarRed
          else: chartBarGold
        radius: top corners only (BorderRadius.vertical(top: Radius.circular(6)))
        if selectedDay==date: BoxDecoration border=2px accent
      SizedBox(4)
      Text(dayLabel, 11px, textTertiary, center)

Hint text below: "Tap a bar to filter that day" 11px textTertiary center mt=8

2. lib/widgets/monthly_calendar.dart:
Props: month(String YYYY-MM), selectedDate?, tasks, onDatePress

Container: cardBg, radius=16, padding=16

Header row: ['S','M','T','W','T','F','S'] 13px textTertiary center

Generate days for the month view (including prev/next month padding)
7-column grid using Wrap or Table:

For each date cell (44px height):
  GestureDetector(onTap: onDatePress(date))
  Column(center):
    Container 32x32:
      if isToday: border=2px accent, radius=8
      if isSelected: bg=accent, radius=8
      Text(day, 15px):
        isSelected: white bold
        isToday: accent bold
        isOtherMonth: textTertiary
        else: textPrimary
    SizedBox(2)
    Row(center, gap=2): colored dots 4x4 for tasks on that day
      overdue task: red dot
      exam task: gold dot
      other task: green dot
      max 3 dots
```

---

## ✅ PHASE 8 — New Task Sheet

```
Create lib/widgets/new_task_sheet.dart:
StatefulWidget
Props: onClose

State: title, description, type(=assignment), dueDate(=today), dueTime, hasTime, priority(=medium), reminders list

DISPLAY: Stack with backdrop + sheet
  Backdrop: GestureDetector(onTap: _close) full screen rgba(0,0,0,0.5)
  Sheet: DraggableScrollableSheet OR AnimatedSlide

SHEET ANIMATION (GymMane modal pattern):
  AnimationController duration=320ms
  On init: controller.forward() (slide up from bottom)
  _close(): controller.reverse() THEN widget.onClose()
  SlideTransition: Offset(0, 1->0) with easeOutCubic

SHEET CONTENT (rounded top 24, cardBg):
  Drag handle: 32x4 borderLight, center, mt=12
  KeyboardAvoidingView behavior
  SingleChildScrollView with padding:

  Header Row: Text('New task', 20px bold) + GestureDetector X icon

  TITLE field:
    Text('TITLE', 11px textTertiary letterSpacing=1)
    TextField: inputBg, radius=10, h=48, placeholder 'e.g. Algorithms assignment'

  DESCRIPTION field:
    Text('DESCRIPTION', same label style)
    TextField: inputBg, radius=10, minLines=3, maxLines=5
    placeholder 'Optional notes'

  TYPE field:
    Text('TYPE', label style)
    GestureDetector -> show type bottom picker
    Container inputBg radius=10 h=48 px=14:
      Row: Icon(description) + Text(type.name) + Spacer + Icon(chevron_down)

  DATE + TIME row (Row, gap=8):
    Expanded: date field (inputBg, radius=10, h=48)
      GestureDetector -> showDatePicker, show 'MM/DD/YYYY' format
    SizedBox(w): time field (inputBg, radius=10, h=48)
      GestureDetector -> showTimePicker if hasTime
      placeholder 'No time'

  SET A TIME row:
    Row: Column(Text+subtitle) + Spacer + TinySwitch
    When toggled: setState hasTime=true

  PRIORITY:
    Text('PRIORITY', label)
    PrioritySelector(value: priority, onChange: setState)

  REMINDERS:
    Text('REMINDERS', label)
    List of added reminders as chips:
      Container accentLight border accent radius=12 h=36 px=12:
        Row: Icon(notifications, accent 16) + Text('X days before') + GestureDetector X
    Dashed border button: '+ Add another reminder'
      GestureDetector -> show ReminderPickerSheet on top

  PrimaryButton('Save task'):
    validate: title not empty, dueDate set
    app.addTask(Task(...))
    HapticFeedback.notificationSuccess equivalent
    _close()
```

---

## ✅ PHASE 9 — Calendar, Done, Profile Screens

```
Create the remaining 3 screens:

=== lib/screens/calendar_screen.dart ===
State: viewMode('monthly'/'weekly'), currentMonth, currentWeekStart, selectedDate

Header: same as Dashboard (greeting + avatar)

Segment Control (Monthly/Weekly):
  Row in cardBg pill, p=4, radius=full
  AnimatedPositioned pill 340ms easeOutCubic (GymMane nav pill pattern applied here too)
  Tap Monthly/Weekly: update viewMode

Monthly view:
  Navigation row: < [Month YYYY] >
  MonthlyCalendar widget

Weekly view:
  Navigation row: < [Sep 14-20, 2026] >
  WeeklyBarChart widget (weekStart=currentWeekStart)

Task preview card (cardBg radius=16 mx=16):
  selectedDate==null: Text('Tap a day to see its tasks', textTertiary center p=24)
  else: TaskCard list for tasksForDate(selectedDate)

FAB: same as Dashboard

=== lib/screens/done_screen.dart ===
Header same
Text('${completedTasks.length} completed', 13px textSecondary px=16 mt=4)
Scrollable list:
  TaskCard for each completedTask:
    showCompleted: true
    onComplete: (toggle back to pending? or no-op)
    onDelete: app.deleteTask(id)
Empty state: 'No completed tasks yet'

=== lib/screens/profile_screen.dart ===
Scrollable content:

Profile Card (cardBg radius=20 p=20 center):
  Avatar Stack:
    Container 80x80 circle accent bg, letter white 28px bold
    Positioned bottom-right: Container 24x24 dark circle
      Icon(camera_alt, white, 14px)
    GestureDetector -> image_picker
  Row: Text(name, 20px bold) + SizedBox(6) + Icon(edit, textSecondary)
  GestureDetector on edit: show name edit dialog
  Text('Stored on this device', 13px textTertiary mt=4)

Reminders Card (cardBg radius=16 p=20 mt=12):
  Text('Reminders', 17px bold)
  Text(description, 13px textSecondary mt=4 mb=16)
  Row: Text('Assignment & CT', 15px flex=1) + StepperControl
    value=settings.assignmentReminderDays
    onChange: app.updateSettings(settings.copyWith(assignmentReminderDays: v))
  Divider 1px borderLight my=16
  Row: Text('Exam, Viva & Presentation', 15px flex=1) + StepperControl
    value=settings.examReminderDays
  Divider
  Row: Column(Text+subtitle, flex=1) + TinySwitch
    value=settings.notificationsEnabled
    onChanged: app.updateSettings(settings.copyWith(notificationsEnabled: v))
      if false: NotificationService.instance.cancelAll()

Theme Card (cardBg radius=16 p=20 mt=12):
  Text('Theme', 17px bold mb=12)
  Row: 3 options [System] [Light] [Dark]
    Container with full border radius=full, each option Expanded h=40
    Active: navActiveBg bg, navActiveText text bold
    Inactive: transparent, textSecondary
    AnimatedContainer 200ms on change
    onTap: app.updateSettings(settings.copyWith(theme: selected))
```

---

## ✅ PHASE 10 — Notifications

```
Create lib/services/notification_service.dart:

Singleton pattern
init(): flutterLocalNotificationsPlugin.initialize + timezone setup

scheduleForTask(Task task):
  for each reminder in task.reminders:
    calculate triggerDateTime based on ReminderType:
      atTime: DateTime.parse(task.dueDate) [+ dueTime if hasTime]
      oneHour: dueDateTime.subtract(1 hour)
      oneDay: dueDateTime.subtract(1 day)
      threeDays: dueDateTime.subtract(3 days)
      oneWeek: dueDateTime.subtract(7 days)
      custom: dueDateTime.subtract(customDays days)
    if triggerDateTime is in the future:
      schedule with zonedSchedule
      store notificationId in reminder

cancelForTask(Task task):
  for each reminder: cancel by notificationId

rescheduleAll(List<Task> tasks):
  for each pending task: scheduleForTask(task)

cancelAll(): cancelAll()

Notification content:
  title: '[Assignment] Networks Lab Report'
  body: 'Due Sep 16 — Overdue'
  importance: Importance.high
```

---

## ✅ PHASE 11 — Final Polish

```
Apply final GymMane-level polish to CampusTracker Flutter:

1. ZERO RIPPLE (already set in AppTheme.build):
   Verify splashFactory: NoSplash.splashFactory is set
   Verify splashColor: Colors.transparent
   Verify highlightColor: Colors.transparent
   Replace any InkWell with GestureDetector everywhere

2. HAPTICS - add to all interactive elements:
   Tab switches: HapticFeedback.lightImpact()
   Task complete: HapticFeedback.mediumImpact()
   Task delete: HapticFeedback.lightImpact()
   Save task: HapticFeedback.notificationVibrate() or mediumImpact
   Stepper +/-: HapticFeedback.selectionClick()
   Toggle switch: HapticFeedback.lightImpact()
   Filter chip: HapticFeedback.selectionClick()

3. PERFORMANCE:
   Wrap TaskCard in a const constructor where possible
   Use ListView.builder instead of Column+map for task lists
   Set itemExtent on ListView.builder (each card ~72px + 8px margin = 80px)
   RepaintBoundary around WeeklyBarChart and MonthlyCalendar
   RepaintBoundary around HeroCarousel

4. EDGE TO EDGE - verify in main.dart:
   SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge) is called
   All screens use SafeArea appropriately
   Bottom nav adds SafeArea(top: false)

5. LIFECYCLE FLUSH - verify in AppShell:
   didChangeAppLifecycleState calls app.persistNow() on pause/inactive

6. CONST WIDGETS:
   Add const to all StatelessWidget constructors and const instances
   This prevents unnecessary rebuilds

7. STATE ACCESS PATTERN:
   Use context.read<AppState>() for actions (not rebuilding)
   Use context.watch<AppState>() only at screen level
   Use context.select<AppState, T>() for granular rebuilds
   Example: context.select((AppState s) => s.pendingTasks)
```
