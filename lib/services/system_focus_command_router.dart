import 'dart:collection';

import '../models/system_focus_command.dart';
import '../models/system_focus_snapshot.dart';

typedef SystemFocusCommandTarget = ({
  void Function() start,
  void Function() pause,
  void Function() resumePending,
  void Function() reset,
  void Function() beginNextSession,
  void Function() discardPending,
});

/// Authorizes and routes commands from trusted system surfaces.
///
/// A command is accepted only once, only for the exact published snapshot,
/// and only when that snapshot advertises the requested action. Callback
/// failures are contained and the request remains consumed.
class SystemFocusCommandRouter {
  static const _maximumRememberedRequestIds = 128;

  final Queue<String> _requestOrder = Queue<String>();
  final Set<String> _consumedRequestIds = <String>{};
  DateTime? _lastConsumedSnapshotAt;

  bool execute({
    required SystemFocusCommand command,
    required SystemFocusSnapshot currentSnapshot,
    required SystemFocusCommandTarget target,
  }) {
    if (_consumedRequestIds.contains(command.requestId) ||
        command.snapshotGeneratedAt == _lastConsumedSnapshotAt ||
        command.snapshotGeneratedAt != currentSnapshot.generatedAt ||
        !currentSnapshot.availableActions.contains(command.action)) {
      return false;
    }

    _remember(command.requestId);
    _lastConsumedSnapshotAt = command.snapshotGeneratedAt;
    try {
      switch (command.action) {
        case SystemFocusAction.start:
          target.start();
          break;
        case SystemFocusAction.pause:
          target.pause();
          break;
        case SystemFocusAction.resume:
          if (currentSnapshot.activity == SystemFocusActivity.pendingResume) {
            target.resumePending();
          } else {
            target.start();
          }
          break;
        case SystemFocusAction.reset:
          target.reset();
          break;
        case SystemFocusAction.beginNextSession:
          target.beginNextSession();
          break;
        case SystemFocusAction.discardPending:
          target.discardPending();
          break;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void _remember(String requestId) {
    _consumedRequestIds.add(requestId);
    _requestOrder.addLast(requestId);
    if (_requestOrder.length <= _maximumRememberedRequestIds) return;
    _consumedRequestIds.remove(_requestOrder.removeFirst());
  }
}
