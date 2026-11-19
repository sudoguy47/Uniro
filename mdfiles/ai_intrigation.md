In my Flutter app Uniro, the push drawer already exists. Add a "smart layer"
to it. Everything is offline, rule-based, no AI, no new packages. Don't
refactor unrelated code.

1. services/suggestion_engine.dart: a pure Dart class with one method
   `Suggestion? pick(DateTime now, AppSnapshot s)` where AppSnapshot is a small
   read-only view of tasks, classes (if they exist), notes and focus
   stats. Return at most ONE suggestion, by priority:
   a. A class ended within the last 15 minutes -> "{course} just ended. Jot
      down notes?" action: open a new note linked to that course.
   b. A task is due within 24 hours and not completed -> "{title} is due
      {when}. Start a {n}-minute focus?" action: open Focus with that task
      linked and n = 25 (or 45 if due in under 6 hours).
   c. An exam within 7 days -> "{exam} in {d} days. Open the checklist?"
   d. Otherwise return null and show nothing.
   Rules are plain code with a unit-testable signature. Skip any suggestion the
   user dismissed today (store dismissed ids and the date in LocalStore).
2. UI: a compact suggestion card at the top of the drawer under the header
   (surface at 14% white over the gradient, 16px radius, icon, one line of text,
   a primary text button, and a small close button). It animates in with a 200ms
   fade plus 8px slide after the drawer opens, and fades out when dismissed.
   Compute the suggestion once each time the drawer opens, not per frame and not
   on a timer.
3. Live subtitles under menu items (muted, 12sp, one line, only if data
   exists): Exams "CT 2 in 3 days", Completed "4 this week", Courses "5
   courses", Attendance "lowest: CSE 2101 78%". Read via context.select
   so only the drawer rebuilds. No subtitle when there is nothing to say.
4. Personalization: long-press the menu to enter an edit mode where items can
   be reordered (ReorderableListView) and hidden; save order and hidden ids in
   LocalStore. "Settings" and "Notifications & permissions" can never be
   hidden. Add a "Reset menu" action.
5. Keep all drawer performance rules: lazy build, RepaintBoundary, no
   per-frame rebuilds, nothing computed when the drawer is closed. Honor
   reduce-motion.

Include unit tests for suggestion_engine (each rule, priority, dismissal,
null case, time zone and midnight boundary). Give me the files changed and a
manual test checklist.