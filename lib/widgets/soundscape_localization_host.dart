import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../services/soundscape_controller.dart';

/// Above navigation so media copy follows language changes on every screen.
class SoundscapeLocalizationHost extends StatefulWidget {
  const SoundscapeLocalizationHost({
    super.key,
    required this.controller,
    required this.child,
  });

  final SoundscapeController controller;
  final Widget child;

  @override
  State<SoundscapeLocalizationHost> createState() =>
      _SoundscapeLocalizationHostState();
}

class _SoundscapeLocalizationHostState
    extends State<SoundscapeLocalizationHost> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.updateLocalizations(AppLocalizations.of(context));
  }

  @override
  void didUpdateWidget(SoundscapeLocalizationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      widget.controller.updateLocalizations(AppLocalizations.of(context));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
