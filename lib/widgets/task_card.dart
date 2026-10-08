import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../theme/app_colors.dart';
import '../domain/task_utils.dart';

/// Ultra-high performance TaskCard widget.
///
/// Performance Optimizations:
/// 1. Root RepaintBoundary isolates raster layers, eliminating root-level BUILD,
///    LAYOUT (root), and UPDATING COMPOSITING BITS during fling scrolls.
/// 2. Zero-allocation build: All BoxDecorations, Borders, and TextStyles are
///    statically cached, eliminating Dart VM GC pauses (Scavenge / CollectOldGeneration).
/// 3. Const constructors strictly enforced for all static icons, spacers, paddings, and geometry.
/// 4. Animated check button isolated to a leaf StatefulWidget so completion animations
///    never dirty or rebuild the parent card, list, or root render tree.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onComplete,
    this.onDelete,
    this.showCompleted = false,
  });

  final Task task;
  final VoidCallback onComplete;
  final VoidCallback? onDelete;
  final bool showCompleted;

  // Cached layout dimensions for parent lists (e.g. itemExtent / prototypeItem)
  static const double cardHeight = 72.0;
  static const double cardMarginBottom = 8.0;
  static const double totalItemExtent = cardHeight + cardMarginBottom;

  // ── Static Geometry & Spacing Constants (Zero Runtime Allocation) ──
  static const EdgeInsets _cardMargin =
      EdgeInsets.only(bottom: TaskCard.cardMarginBottom);
  static const EdgeInsets _cardPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  static const EdgeInsets _deletePadding = EdgeInsets.all(4);

  static const SizedBox _gapW12 = SizedBox(width: 12);
  static const SizedBox _gapW8 = SizedBox(width: 8);
  static const SizedBox _gapH2 = SizedBox(height: 2);

  static const BorderRadius _cardBorderRadius =
      BorderRadius.all(Radius.circular(16));
  static const BorderRadius _iconBorderRadius =
      BorderRadius.all(Radius.circular(8));

  // ── Static Icons (Compile-Time Const) ──────────────────────────────
  static const Icon _docIcon = Icon(
    Icons.description_outlined,
    size: 18,
  );

  static const Icon _deleteIcon = Icon(
    Icons.delete_outline,
    size: 18,
  );

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final u = getUrgency(task);

    // Retrieve memoized, zero-allocation styles & decorations
    final cardDecoration = _CardStyleCache.getCardDecoration(c.cardBg, c.border);
    final iconBgDecoration =
        _CardStyleCache.getIconBgDecoration(c.cardBgRaised);
    final titleStyle = _CardStyleCache.getTitleStyle(
      showCompleted: showCompleted,
      primaryColor: c.textPrimary,
      tertiaryColor: c.textTertiary,
    );
    final subtitleStyle =
        _CardStyleCache.getSubtitleStyle(c.textSecondary);

    return RepaintBoundary(
      child: Container(
        height: TaskCard.cardHeight,
        margin: _cardMargin,
        padding: _cardPadding,
        decoration: cardDecoration,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: iconBgDecoration,
              child: Icon(
                iconForTaskType(task.type),
                size: 18,
                color: c.textSecondary,
              ),
            ),
            _gapW12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  _gapH2,
                  Text(
                    subtitleText(task, u),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleStyle,
                  ),
                ],
              ),
            ),
            _gapW12,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showCompleted && onDelete != null) ...[
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onDelete!();
                    },
                    child: Padding(
                      padding: _deletePadding,
                      child: IconTheme(
                        data: IconThemeData(color: c.textSecondary),
                        child: _deleteIcon,
                      ),
                    ),
                  ),
                  _gapW8,
                ],

                // Isolated leaf completion button with its own ticker & state.
                // Prevents animation scale passes from dirtying parent compositing bits.
                _TaskCheckButton(
                  showCompleted: showCompleted,
                  accentColor: c.accent,
                  borderColor: c.border,
                  onComplete: onComplete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Isolated animated checkmark button.
/// Houses the AnimationController at the leaf level so tap animations
/// never trigger parent card or root render tree invalidations.
class _TaskCheckButton extends StatefulWidget {
  const _TaskCheckButton({
    required this.showCompleted,
    required this.accentColor,
    required this.borderColor,
    required this.onComplete,
  });

  final bool showCompleted;
  final Color accentColor;
  final Color borderColor;
  final VoidCallback onComplete;

  @override
  State<_TaskCheckButton> createState() => _TaskCheckButtonState();
}

class _TaskCheckButtonState extends State<_TaskCheckButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkCtrl;

  static const Icon _checkIcon = Icon(
    Icons.check,
    color: Colors.white,
    size: 18,
  );

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 120),
      lowerBound: 0.88,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    HapticFeedback.mediumImpact();
    await _checkCtrl.reverse();
    await _checkCtrl.forward();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final checkDecoration = _CardStyleCache.getCheckDecoration(
      showCompleted: widget.showCompleted,
      accentColor: widget.accentColor,
      borderColor: widget.borderColor,
    );

    return ScaleTransition(
      scale: _checkCtrl,
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: checkDecoration,
          child: widget.showCompleted ? _checkIcon : null,
        ),
      ),
    );
  }
}

/// Static zero-allocation memoization cache for BoxDecorations, Borders, and TextStyles.
/// Reuses pre-created instances across frames to prevent GC allocations during scrolling.
class _CardStyleCache {
  _CardStyleCache._();

  // Decoration Caches
  static final Map<int, BoxDecoration> _cardDecorations = {};
  static final Map<Color, BoxDecoration> _iconBgDecorations = {};
  static final Map<int, BoxDecoration> _checkDecorations = {};

  // TextStyle Caches
  static final Map<Color, TextStyle> _titleStyles = {};
  static final Map<Color, TextStyle> _titleCompletedStyles = {};
  static final Map<Color, TextStyle> _subtitleStyles = {};

  static BoxDecoration getCardDecoration(Color bgColor, Color borderColor) {
    final key = Object.hash(bgColor, borderColor);
    return _cardDecorations.putIfAbsent(
      key,
      () => BoxDecoration(
        color: bgColor,
        borderRadius: TaskCard._cardBorderRadius,
        border: Border.all(color: borderColor),
      ),
    );
  }

  static BoxDecoration getIconBgDecoration(Color color) {
    return _iconBgDecorations.putIfAbsent(
      color,
      () => BoxDecoration(
        color: color,
        borderRadius: TaskCard._iconBorderRadius,
      ),
    );
  }

  static BoxDecoration getCheckDecoration({
    required bool showCompleted,
    required Color accentColor,
    required Color borderColor,
  }) {
    final key = Object.hash(showCompleted, accentColor, borderColor);
    return _checkDecorations.putIfAbsent(
      key,
      () => BoxDecoration(
        shape: BoxShape.circle,
        color: showCompleted ? accentColor : Colors.transparent,
        border: Border.all(
          color: showCompleted ? accentColor : borderColor,
          width: 2,
        ),
      ),
    );
  }

  static TextStyle getTitleStyle({
    required bool showCompleted,
    required Color primaryColor,
    required Color tertiaryColor,
  }) {
    if (showCompleted) {
      return _titleCompletedStyles.putIfAbsent(
        tertiaryColor,
        () => TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: tertiaryColor,
          decoration: TextDecoration.lineThrough,
        ),
      );
    } else {
      return _titleStyles.putIfAbsent(
        primaryColor,
        () => TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
      );
    }
  }

  static TextStyle getSubtitleStyle(Color secondaryColor) {
    return _subtitleStyles.putIfAbsent(
      secondaryColor,
      () => TextStyle(
        fontSize: 13,
        color: secondaryColor,
      ),
    );
  }
}
