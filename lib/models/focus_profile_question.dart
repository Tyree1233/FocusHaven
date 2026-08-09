import 'package:flutter/foundation.dart';

@immutable
class FocusProfileQuestion {
  const FocusProfileQuestion({required this.prompt, required this.choices});

  final String prompt;
  final List<FocusProfileChoice> choices;
}

@immutable
class FocusProfileChoice {
  const FocusProfileChoice(this.label, this.focusType);

  final String label;
  final String focusType;
}
