In my Flutter app Uniro (layered: app/app_shell.dart owns the bottom nav,
screens/, widgets/, state/AppState + NotesState, theme/AppColors,
widgets/ui_kit.dart), restructure navigation. Don't refactor unrelated code.

NEW BOTTOM NAV (5 items)
Dashboard, Routine, Focus (center, accent-colored icon), Notes, Profile.
- Routine replaces the Calendar tab. Remove the Calendar tab from the nav.
  Find every reference to CalendarScreen and MonthlyCalendar first and list
  them; delete the screen and widget only if nothing else uses them,
  otherwise tell me what still uses them.
- Routine tab: if screens/routine_screen.dart does not exist yet, show a simple
  placeholder ("Class routine is coming next") that does not crash.
- Focus tab: placeholder screen until the Focus feature is built.
- Remove the Done tab. Its content moves into the Dashboard (below).
- Use named tab identifiers (enum AppTab) instead of magic indexes everywhere
  (e.g. opening Profile from the avatar, tapping a notification). Migrate an
  old saved tab index: old Calendar -> Routine, old Done -> Dashboard, others by
  name.

DASHBOARD CHANGES
- Under the greeting add a compact segmented toggle "Active | Completed".
  Active = the current feed. Completed = the current Done screen's content
  (list, uncomplete, delete, completed counter). Build the Completed view
  lazily on first selection and keep it alive. Remember the last choice.
- A "+" button in the Dashboard header (44px circle, accent color). Tapping it
  opens a small popover (anchored under the button, scale 0.92 to 1 plus fade,
  180ms easeOutCubic, 25ms stagger on items) with exactly two options:
  1. "Create task": opens the existing NewTaskSheet.
  2. "Add class routine": opens the Add Class form if it exists, otherwise a
     SnackBar "Coming next". Never a dead item or a crash.
  The "+" icon rotates 45 degrees while the popover is open. Tapping outside
  or Back closes it. Honor MediaQuery.disableAnimationsOf (plain 120ms fade).
- Keep the Dashboard's existing FAB only if it is not the same action; do not
  have two create buttons.

NAV BAR VISUALS
Selected item: icon swaps outlined to filled with a small scale pop (1.0 to
1.15 to 1.0, 200ms) and the label fades in. The center Focus item is slightly
larger. Keep the existing "slide out when full-screen editors open" behavior.

RULES
No new packages. RepaintBoundary around the nav bar. Works in light and dark,
small screens, 48px touch targets, accessibility labels.
Give me the files changed, files deleted, and a test checklist (each tab, old
saved tab index, Completed toggle, "+" popover both options, back button).