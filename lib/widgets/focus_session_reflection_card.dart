import 'package:flutter/material.dart';

import '../models/focus_event.dart';

/// An optional, text-free reflection shown after a completed focus session.
///
/// The card never blocks the break transition. Its only action is to attach a
/// bounded fit signal to the completed private focus event.
class FocusSessionReflectionCard extends StatelessWidget {
  const FocusSessionReflectionCard({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final FocusSessionFit? selected;
  final ValueChanged<FocusSessionFit> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('focus-session-reflection'),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
        child: Column(
          children: [
            const Text(
              'How did that session feel?',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            const Text(
              'Optional and text-free. Your answer privately tunes future Haven Plans.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final fit in FocusSessionFit.values)
                  ChoiceChip(
                    key: ValueKey('focus-session-fit-${fit.name}'),
                    label: Text(_label(fit)),
                    selected: selected == fit,
                    onSelected: (isSelected) {
                      if (isSelected) onSelected(fit);
                    },
                  ),
              ],
            ),
            if (selected != null) ...[
              const SizedBox(height: 9),
              const Text(
                'Saved privately. You can change your answer before continuing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _label(FocusSessionFit fit) => switch (fit) {
    FocusSessionFit.tooMuch => 'Too much',
    FocusSessionFit.aboutRight => 'About right',
    FocusSessionFit.couldDoMore => 'Could do more',
  };
}
