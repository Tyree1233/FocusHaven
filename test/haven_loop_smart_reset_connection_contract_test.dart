import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'linked Smart Reset continuity remains local, opaque, and fail closed',
    () {
      final service = File(
        'lib/services/haven_loop_service.dart',
      ).readAsStringSync();
      final screen = File('lib/screens/timer_screen.dart').readAsStringSync();
      final sheet = File(
        'lib/widgets/smart_reset_sheet.dart',
      ).readAsStringSync();

      expect(service, contains('final class HavenLoopRecoveryTicket'));
      expect(service, contains('final String _selectedItemId'));
      expect(service, isNot(contains('recoveryTaskTitle')));
      expect(service, contains('_activeRecoveryGeneration'));
      expect(service, contains('_selectionMatchesOwners()'));
      expect(service, contains('_selectedItemId == ticket._selectedItemId'));
      expect(service, isNot(contains("setString('havenLoopRecovery")));
      expect(service, isNot(contains('_queue.toggle(ticket')));
      expect(service, isNot(contains('firebase')));
      expect(service, isNot(contains('http')));
      expect(service, isNot(contains('calendar')));

      expect(screen, contains('beginSmartResetRecovery'));
      expect(screen, contains('finishSmartResetRecovery'));
      expect(screen, contains('preservesSelectedTask: recoveryTicket != null'));
      expect(sheet, contains('No task text is copied into Smart Reset.'));
      expect(sheet, isNot(contains('FocusQueueItem')));
      expect(sheet, isNot(contains('focusTask')));
    },
  );
}
