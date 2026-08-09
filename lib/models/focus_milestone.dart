import 'package:flutter/foundation.dart';

@immutable
class FocusMilestone {
  const FocusMilestone({
    required this.title,
    required this.detail,
    required this.unlocked,
  });

  final String title;
  final String detail;
  final bool unlocked;
}
