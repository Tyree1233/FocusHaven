import 'package:flutter/material.dart';

import '../l10n/focus_haven_localizations.dart';
import '../models/focus_event.dart';

/// An optional, text-free reflection shown after a completed focus session.
///
/// The card never blocks the break transition. Continuing without a choice is
/// an explicit skip; choosing a chip attaches only a bounded fit signal to the
/// completed private focus event.
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
    final l10n = context.l10n;
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
            Text(
              l10n.focusReflectionTitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              l10n.focusReflectionDescription,
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
                    label: Text(_label(context, fit)),
                    selected: selected == fit,
                    onSelected: (isSelected) {
                      if (isSelected) onSelected(fit);
                    },
                  ),
              ],
            ),
            if (selected != null) ...[
              const SizedBox(height: 9),
              Text(
                l10n.focusReflectionSaved,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _label(BuildContext context, FocusSessionFit fit) =>
      switch (fit) {
        FocusSessionFit.tooMuch => context.l10n.focusSessionFitTooMuch,
        FocusSessionFit.aboutRight => context.l10n.focusSessionFitAboutRight,
        FocusSessionFit.couldDoMore => context.l10n.focusSessionFitCouldDoMore,
      };
}
