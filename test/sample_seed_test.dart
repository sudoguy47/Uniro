import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniro1/domain/haptics.dart';
import 'package:uniro1/domain/sample_data.dart';
import 'package:uniro1/services/notes_store.dart';
import 'package:uniro1/state/app_state.dart';
import 'package:uniro1/state/notes_state.dart';
import 'package:uniro1/state/routine_state.dart';

/// Full seed -> hide round-trip through the real state objects.
/// Notification/plugin channels are unmocked, proving the seed path
/// never throws when platform pieces are missing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HapticsCapabilities.debugReset();
  });

  test('seed fills everything, hide removes exactly the samples',
      () async {
    final app = AppState();
    final routine = RoutineState();
    final store = NotesStore();
    await store.load();
    final notes = NotesState(store: store);

    expect(hasExampleData(app, routine, notes), isFalse);

    await seedExampleData(app: app, routine: routine, notes: notes);
    // Allow unawaited persistence/notification futures to settle; any
    // unhandled async error here fails the test.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(app.tasks.length, 10);
    expect(routine.courses.length, 4);
    expect(routine.slots.length, 5);
    expect(notes.allNotes.length, 2);
    expect(hasExampleData(app, routine, notes), isTrue);

    await hideExampleData(app: app, routine: routine, notes: notes);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(app.tasks, isEmpty);
    expect(routine.courses, isEmpty);
    expect(routine.slots, isEmpty);
    expect(notes.allNotes, isEmpty);
    expect(hasExampleData(app, routine, notes), isFalse);
  });

  test('seeding twice does not duplicate', () async {
    final app = AppState();
    final routine = RoutineState();
    final store = NotesStore();
    await store.load();
    final notes = NotesState(store: store);

    await seedExampleData(app: app, routine: routine, notes: notes);
    await seedExampleData(app: app, routine: routine, notes: notes);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(app.tasks.length, 10);
    expect(routine.courses.length, 4);
  });
}
