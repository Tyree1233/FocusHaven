import 'package:flutter/foundation.dart';

import '../models/haven_system_intent.dart';

/// Ephemeral, text-free handoff into the app-level review host.
///
/// A later native adapter may submit one allowlisted request here after it has
/// independently passed its platform release gates. The inbox stores no
/// transcript or arbitrary text, accepts no second pending request, and never
/// prepares, confirms, or executes an action itself.
final class HavenSystemIntentInbox extends ChangeNotifier {
  HavenSystemIntentRequest? _pendingRequest;

  bool get hasPendingRequest => _pendingRequest != null;

  bool submit(HavenSystemIntentRequest request) {
    if (_pendingRequest != null) return false;
    _pendingRequest = request;
    notifyListeners();
    return true;
  }

  /// Consumed only by the single app-level production host.
  HavenSystemIntentRequest? takePendingRequest() {
    final request = _pendingRequest;
    _pendingRequest = null;
    return request;
  }
}
