import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Plan-to-Focus loop keeps ownership local and explicit', () {
    final service = File(
      'lib/services/haven_loop_service.dart',
    ).readAsStringSync();
    final screen = File('lib/screens/timer_screen.dart').readAsStringSync();
    final card = File(
      'lib/widgets/haven_loop_completion_card.dart',
    ).readAsStringSync();
    final catalog = File('lib/l10n/app_en.arb').readAsStringSync();

    expect(service, contains("'havenLoopSelectedQueueItemId'"));
    expect(service, contains('HavenLoopRecoveryTicket'));
    expect(service, contains('beginSmartResetRecovery'));
    expect(service, contains('finishSmartResetRecovery'));
    expect(service, contains('_selectedItemId == ticket._selectedItemId'));
    expect(service, contains('_queue.toggle(item.id)'));
    expect(service, contains("_timer.setFocusTask('')"));
    expect(service, isNot(contains('firebase')));
    expect(service, isNot(contains('http')));
    expect(service, isNot(contains('calendar')));
    expect(screen, contains('!havenLoop.isInitialized'));
    expect(screen, contains('haven-loop-restoring'));
    expect(screen, contains('haven-loop-resolution-required'));
    expect(screen, contains('completedFocusIdentity'));
    expect(screen, contains('reflectOnCompletedFocus'));
    expect(screen, contains('HavenJourneyCompletionConnectionCard'));
    expect(screen, contains('preservesSelectedTask: recoveryTicket != null'));
    expect(screen, contains('havenLoopRecoveryUnlinked'));
    expect(
      screen.indexOf('HavenLoopCompletionCard'),
      lessThan(screen.indexOf('FocusSessionReflectionCard')),
    );
    expect(card, contains('l10n.havenLoopDecisionDescription'));
    expect(card, contains('l10n.havenLoopMarkComplete'));
    expect(card, contains('l10n.havenLoopKeepLater'));
    expect(catalog, contains('FocusHaven never completes it automatically.'));
    expect(catalog, contains('Mark task complete'));
    expect(catalog, contains('Keep for later'));
    expect(catalog, contains('recovery continued without a task link'));
  });
}
