import '../l10n/app_localizations.dart';
import '../models/haven_action.dart';
import 'haven_action_engine.dart';
import 'haven_action_interpreter.dart';

class HavenPlannerItemApplyResult {
  const HavenPlannerItemApplyResult({
    required this.title,
    required this.added,
    required this.message,
  });

  final String title;
  final bool added;
  final String message;
}

/// Applies reviewed planner queue items through the existing action boundary.
///
/// A fresh state-bound proposal is created after every accepted item so the
/// queue revision produced by the prior item cannot make later proposals stale.
class HavenPlannerActionService {
  const HavenPlannerActionService({
    required this.interpreter,
    required this.engine,
    required this.executor,
    this.clock,
  });

  final HavenActionInterpreter interpreter;
  final HavenActionEngine engine;
  final HavenActionExecutor executor;
  final DateTime Function()? clock;

  Future<List<HavenPlannerItemApplyResult>> addReviewedQueueItems(
    List<String> titles, {
    AppLocalizations? localizations,
  }) async {
    final results = <HavenPlannerItemApplyResult>[];
    for (final title in titles) {
      final interpretation = interpreter.interpret(
        'add task: $title',
        executor.snapshot(),
        source: HavenActionSource.typed,
        localizations: localizations,
      );
      final proposal = interpretation.proposal;
      if (proposal == null) {
        results.add(
          HavenPlannerItemApplyResult(
            title: title,
            added: false,
            message: interpretation.message,
          ),
        );
        continue;
      }
      final decision = engine.evaluate(proposal, localizations: localizations);
      if (!decision.allowed) {
        results.add(
          HavenPlannerItemApplyResult(
            title: title,
            added: false,
            message: decision.message,
          ),
        );
        continue;
      }
      final result = await engine.execute(
        proposal,
        confirmation: HavenActionConfirmation.forProposal(
          proposal,
          confirmedAtUtc: (clock ?? DateTime.now)().toUtc(),
        ),
        localizations: localizations,
      );
      results.add(
        HavenPlannerItemApplyResult(
          title: title,
          added: result.executed,
          message: result.message,
        ),
      );
    }
    return List.unmodifiable(results);
  }
}
