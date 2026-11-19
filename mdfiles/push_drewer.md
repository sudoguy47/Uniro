In my Flutter app Uniro (layered: app/app_shell.dart owns the bottom nav and
page switching, theme/AppColors, widgets/ui_kit.dart), add a "push" side menu
like the attached screenshots (a hamburger opens a menu from the left while the
whole page, including the bottom nav, slides right and shrinks). Build it with
built-in widgets only, no new packages. Don't refactor unrelated code.

STRUCTURE
- A reusable widget widgets/push_drawer.dart that wraps the app shell content.
  Layer 1 (back): a full-screen gradient background (deep indigo to a darker
  tone from AppColors, works in light and dark) holding the menu. Layer 2
  (front): the existing app content including the nav bar.
- A DrawerController-like object (ChangeNotifier or ValueNotifier<double>
  progress 0..1) exposed through an InheritedWidget, with open(), close(),
  toggle(), so any screen can open it. Add a 3-line hamburger button (44px
  circle, surface color, 1px outline) at the top left of Home, Planner, Notes
  and Me headers, calling toggle().

MOTION (single AnimationController, progress 0 to 1, value-driven)
- Front content: translateX up to 72% of screen width, scale 1.0 to 0.88,
  top-left and bottom-left corner radius 0 to 28, with a soft shadow that fades
  in with progress. Anchor the scale at the left-center.
- Open 380ms with easeOutCubic, close 300ms with easeInCubic. Support
  interrupting mid-animation (tap or drag again) without a jump.
- While open, the front content is dimmed with a 12% black overlay and ignores
  touches except a tap that closes the menu. Dragging the front content left
  closes it; the drag follows the finger and settles by velocity (fling) or
  past 50%.
- Menu items fade in and slide 16px from the left with a 30ms stagger, tied to
  progress (use Interval curves), so they animate on open and reverse on close.
- Honor MediaQuery.disableAnimationsOf: use a plain 150ms fade and no
  scale or slide.
- Do NOT open the menu by a swipe from the left screen edge (it conflicts with
  Android's system back gesture). Only the hamburger opens it.
- Back button: if the menu is open, close it first. Selecting an item closes
  the menu first (about 250ms) and then navigates, so the transition looks
  clean. Add haptic selectionClick on item tap.
- The nav bar stays part of the front content and moves with it. The nav's
  existing "slide out when editors open" behavior must keep working.

MENU CONTENT (a data list so items are easy to add/remove; only show items
whose destination exists, never a dead item)
- Header: app logo (existing asset), "Uniro", and a live summary line such as
  "3 tasks due today · 2 classes" computed from existing state with
  context.select (hide the class part if classes do not exist yet).
- Section ADD: New task, Add class, Add exam, New note.
- Section STUDY: Completed tasks, Courses, Attendance, Exams.
- Section ROUTINE: Share routine, Import routine, Missed classes,
  New semester.
- Section APP: Backup & restore, Notifications & permissions, Settings.
- Footer card: "Uniro v{version}" and a "Check for updates" row (reuse the
  existing UpdateService).
- Items: 40px rounded-square icon holder (12px radius, white at 14% opacity on
  the gradient), 16sp label, 56px row height, section labels in 12sp caps with
  letter spacing, white at 60% opacity. Scrollable on small screens
  (SingleChildScrollView), safe-area aware, no overflow.
- Add a badge dot on "Missed classes" and "Completed tasks" only when there
  is something to see.

PERFORMANCE
- RepaintBoundary around the front layer. Use Transform and AnimatedBuilder
  scoped to the animated layer only; do not rebuild the page subtree each
  frame (pass the page as AnimatedBuilder's child).
- Build the menu content lazily on first open and keep it afterwards.
- When progress is 0, apply no transform, clip, or overlay at all (return the
  child directly) so the closed state costs nothing.
- No BackdropFilter and no saveLayer-heavy effects.

ACCESSIBILITY
Semantics labels for the hamburger ("Open menu") and each item, 48px minimum
touch targets, readable contrast on the gradient in both themes.

Give me the files changed, what the controller API looks like, and a manual
test checklist (open/close by button, drag to close, tap outside, back button,
rapid taps, rotate, dark mode, nav bar moving with the page, small screen).