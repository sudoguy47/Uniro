import 'package:flutter/material.dart';
import '../../../domain/focus_logic.dart';
import '../../../state/focus_state.dart';
import '../../../theme/app_colors.dart';
import '../logic/focus_link_helpers.dart';

class FocusTodayStats extends StatelessWidget {
  const FocusTodayStats({super.key, required this.st});

  final FocusState st;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final total = st.totalFocusedSec(
        forLinkKind: st.linkKind,
        forLinkId: st.linkId,
        date: FocusState.todayStr());
    final label = st.linkKind == 'none'
        ? 'free focus'
        : FocusLinkHelpers.linkLabel(context, st.linkKind, st.linkId);
    return Text(
      'Today in $label: ${formatDuration(total)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, color: c.textSecondary),
    );
  }
}
