# 26 — app_shell.dart + main.dart Changes

**Purpose:** Minimal edits to wire in the 5th Notes tab.

## app_shell.dart — Changes

### 1. Add import
```dart
import '../screens/notes/notes_screen.dart';
```

### 2. Update _screens list (insert at index 2)
```dart
// BEFORE
final List<Widget> _screens = const [
  DashboardScreen(),   // 0
  CalendarScreen(),    // 1
  DoneScreen(),        // 2
  ProfileScreen(),     // 3
];

// AFTER
final List<Widget> _screens = const [
  DashboardScreen(),   // 0
  CalendarScreen(),    // 1
  NotesScreen(),       // 2  ← NEW
  DoneScreen(),        // 3
  ProfileScreen(),     // 4
];
```

### 3. Update nav items list (insert at index 2)
```dart
// BEFORE (4 items)
const _navItems = [
  _NavItem(label: 'Dashboard', icon: Icons.grid_view_outlined,     activeIcon: Icons.grid_view),
  _NavItem(label: 'Calendar',  icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today),
  _NavItem(label: 'Done',      icon: Icons.check_circle_outline,   activeIcon: Icons.check_circle),
  _NavItem(label: 'Profile',   icon: Icons.person_outline,         activeIcon: Icons.person),
];

// AFTER (5 items)
const _navItems = [
  _NavItem(label: 'Dashboard', icon: Icons.grid_view_outlined,     activeIcon: Icons.grid_view),
  _NavItem(label: 'Calendar',  icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today),
  _NavItem(label: 'Notes',     icon: Icons.description_outlined,   activeIcon: Icons.description), // NEW
  _NavItem(label: 'Done',      icon: Icons.check_circle_outline,   activeIcon: Icons.check_circle),
  _NavItem(label: 'Profile',   icon: Icons.person_outline,         activeIcon: Icons.person),
];
```

### 4. Hide nav bar on editor (ValueNotifier approach)
```dart
// In _AppShellState:
final _hideNav = ValueNotifier<bool>(false);

// Wrap your nav bar:
ValueListenableBuilder<bool>(
  valueListenable: _hideNav,
  builder: (_, hide, child) => AnimatedSlide(
    offset: hide ? const Offset(0, 1) : Offset.zero,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
    child: child!,
  ),
  child: _buildNavBar(),
),
// Set _hideNav.value = true before Navigator.push to editor
// Set _hideNav.value = false in editor's onPop callback
```

### 5. Lazy build for NotesScreen (optional, cold-start optimisation)
```dart
class _LazyIndexedChild extends StatefulWidget {
  const _LazyIndexedChild({required this.child, required this.active});
  final Widget child;
  final bool active;
  @override State<_LazyIndexedChild> createState() => _LazyIndexedChildState();
}
class _LazyIndexedChildState extends State<_LazyIndexedChild> {
  bool _built = false;
  @override void didUpdateWidget(_LazyIndexedChild old) {
    super.didUpdateWidget(old);
    if (widget.active) _built = true;
  }
  @override Widget build(BuildContext context) =>
      _built ? widget.child : const SizedBox.shrink();
}

// Usage:
IndexedStack(
  index: _selectedIndex,
  children: [
    const DashboardScreen(),
    const CalendarScreen(),
    _LazyIndexedChild(child: const NotesScreen(), active: _selectedIndex == 2),
    const DoneScreen(),
    const ProfileScreen(),
  ],
)
```

---

## main.dart — Changes

### 1. Add imports
```dart
import 'services/notes_store.dart';
import 'state/notes_state.dart';
```

### 2. Load notes in bootstrap
```dart
Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ... existing init ...

  // NEW: load notes
  final notesStore = NotesStore();
  await notesStore.load();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppState(...)),   // existing
      ChangeNotifierProvider(create: (_) => NotesState(store: notesStore)), // NEW
    ],
    child: const UniroApp(),
  ));
}
```

---

## Summary

| File | Lines changed | What |
|------|--------------|------|
| `app/app_shell.dart` | ~12 | Add NotesScreen + nav item + nav hide |
| `main.dart` | ~6 | NotesStore.load() + NotesState provider |
| **Everything else** | 0 | No changes to existing files |
