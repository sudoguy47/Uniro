import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/responsive.dart';
import '../../../domain/focus_logic.dart';
import '../../../domain/haptics.dart';
import '../../../screens/focus_summary_screen.dart';
import '../../../state/focus_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_notification.dart';
import '../logic/focus_link_helpers.dart';
import '../widgets/focus_break_offer.dart';
import '../widgets/focus_clock.dart';
import '../widgets/focus_controls.dart';
import '../widgets/focus_course_selector.dart';
import '../widgets/focus_course_sheet.dart';
import '../widgets/focus_customize_sheet.dart';
import '../widgets/focus_presets_row.dart';
import '../widgets/focus_today_stats.dart';

/// Course-based Pomodoro timer.
///
/// Course is required before starting. Timing is wall-clock based, pause
/// freezes both countdown and recorded time, and only focus time is ever
/// recorded — never break or paused time.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  FocusState get _st => context.read<FocusState>();

  void _syncLinkName() {
    final st = _st;
    st.setLiveLinkName(FocusLinkHelpers.linkLabel(context, st.linkKind, st.linkId));
  }

  // ── Actions ──

  void _onStart() {
    final st = _st;
    _syncLinkName();
    PremiumHaptics.tap();
    st.start();
  }

  Future<void> _onRestart() async {
    final st = _st;
    if (st.phase == FocusPhase.idle && !st.pendingBreak) {
      PremiumHaptics.tap();
      st.restart();
      return;
    }
    final c = Theme.of(context).extension<AppColors>()!;
    final focused = st.focusedSoFar();
    final saveLine = focused > 0 && st.phase == FocusPhase.focus
        ? 'Your ${formatDuration(focused)} of focus so far will be saved as an ended-early session. '
        : '';
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        title: const Text('Restart timer?'),
        content: Text(
            '${saveLine}The clock resets to the full ${st.phase == FocusPhase.breakTime ? st.breakMin : st.focusMin}-minute ${st.phase == FocusPhase.breakTime ? 'break' : 'focus'} and keeps running.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Restart', style: TextStyle(color: c.overdue)),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    _syncLinkName();
    PremiumHaptics.confirm();
    final saved = st.restart();
    if (saved > 0 && mounted) {
      AppNotification.info(context, 'Saved ${formatDuration(saved)} as ended early.');
    }
  }

  Future<void> _onEnd() async {
    final st = _st;
    if (st.phase == FocusPhase.idle && !st.pendingBreak) return;
    if (st.phase == FocusPhase.breakTime) {
      PremiumHaptics.tap();
      st.endSession();
      return;
    }
    final c = Theme.of(context).extension<AppColors>()!;
    final focused = st.focusedSoFar();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        title: const Text('End session?'),
        content: Text(focused > 0
            ? 'Your ${formatDuration(focused)} of focus will be saved as an ended-early session and the timer will stop.'
            : 'The timer will stop. Nothing is recorded yet.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep going')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('End session', style: TextStyle(color: c.overdue)),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    _syncLinkName();
    PremiumHaptics.confirm();
    final saved = st.endSession();
    if (saved > 0 && mounted) {
      AppNotification.info(context, 'Saved ${formatDuration(saved)} as ended early.');
    }
  }

  // ── Sheets ──

  void _openCourseSheet() {
    final c = Theme.of(context).extension<AppColors>()!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const FocusCourseSheet(),
    );
  }

  void _openCustomize() {
    final c = Theme.of(context).extension<AppColors>()!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const FocusCustomizeSheet(),
    );
  }

  void _openSummary() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FocusSummaryScreen()),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Theme.of(context).extension<AppColors>()!;
    final st = context.read<FocusState>();
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: c.pageBg,
      appBar: AppBar(
        backgroundColor: c.pageBg,
        elevation: 0,
        title: Text('Focus',
            style: TextStyle(
                color: c.textPrimary, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Study summary',
            icon: Icon(Icons.bar_chart_rounded, color: c.textPrimary),
            onPressed: () {
              PremiumHaptics.select();
              _openSummary();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, cons) {
          final landscape = cons.maxWidth > cons.maxHeight;
          final compact = cons.maxHeight < 640;
          final gap = compact ? 8.0 : 12.0;

          return ValueListenableBuilder<int>(
            valueListenable: st.struct,
            builder: (context, _, __) {
              final locked = st.active;
              final navClearance = (st.running && !st.paused)
                  ? 12.0
                  : AppInsets.bottomNavClearance(context);
              final hasBreakOffer =
                  st.pendingBreak && st.phase == FocusPhase.idle;
              final reserved = (compact ? 190.0 : 220.0) +
                  navClearance +
                  (hasBreakOffer ? 60.0 : 0.0);
              final clockHeight = landscape
                  ? (cons.maxHeight * 0.45).clamp(140.0, 240.0)
                  : (cons.maxHeight - reserved).clamp(240.0, 520.0);

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: cons.maxHeight,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FocusCourseSelector(
                            st: st,
                            locked: locked,
                            onOpenCourseSheet: _openCourseSheet,
                          ),
                          if (hasBreakOffer) ...[
                            SizedBox(height: gap),
                            FocusBreakOffer(st: st),
                          ],
                          SizedBox(height: gap),
                          SizedBox(
                            height: clockHeight,
                            child: FocusClock(
                              st: st,
                              animated: !reduce,
                              landscape: landscape,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: gap),
                          FocusPresetsRow(
                            st: st,
                            locked: locked,
                            onOpenCustomize: _openCustomize,
                          ),
                          SizedBox(height: gap),
                          FocusControls(
                            st: st,
                            onStart: _onStart,
                            onRestart: _onRestart,
                            onEnd: _onEnd,
                          ),
                          const SizedBox(height: 8),
                          FocusTodayStats(st: st),
                          SizedBox(height: navClearance),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
