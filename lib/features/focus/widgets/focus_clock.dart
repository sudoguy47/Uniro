import 'package:flutter/material.dart';
import '../../../state/focus_state.dart';
import '../../../widgets/flip_card.dart';

class FocusClock extends StatelessWidget {
  const FocusClock({
    super.key,
    required this.st,
    required this.animated,
    required this.landscape,
  });

  final FocusState st;
  final bool animated;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    Widget minutes = FlipCard(
      value: st.minPair,
      animated: animated,
    );
    Widget seconds = FlipCard(
      value: st.secPair,
      animated: animated,
    );
    minutes = ExcludeSemantics(child: minutes);
    seconds = ExcludeSemantics(child: seconds);

    final Widget stack = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: landscape
          ? Row(
              children: [
                Expanded(child: minutes),
                const SizedBox(width: 16),
                Expanded(child: seconds),
              ],
            )
          : Column(
              children: [
                Expanded(child: minutes),
                const SizedBox(height: 16),
                Expanded(child: seconds),
              ],
            ),
    );

    Widget clock = stack;
    if (st.paused) {
      clock = AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: 0.6,
        child: stack,
      );
    }
    return ValueListenableBuilder<String>(
      valueListenable: st.semanticsN,
      builder: (context, label, _) => Semantics(
        label: label,
        excludeSemantics: true,
        child: clock,
      ),
    );
  }
}
