import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../l10n/focus_haven_localizations.dart';
import '../models/focus_profile_question.dart';
import '../providers/app_providers.dart';

typedef FocusProfileSaver = Future<void> Function(String focusType);

class FocusProfileSheet extends ConsumerStatefulWidget {
  const FocusProfileSheet({this.saveFocusType, super.key});

  final FocusProfileSaver? saveFocusType;

  @override
  ConsumerState<FocusProfileSheet> createState() => _FocusProfileSheetState();
}

class _FocusProfileSheetState extends ConsumerState<FocusProfileSheet> {
  static const _ink = Color(0xFF211442);

  static const _questionCount = 4;

  List<FocusProfileQuestion> _questions(AppLocalizations l10n) => [
    FocusProfileQuestion(
      prompt: l10n.profileQuestionNaturalTime,
      choices: [
        FocusProfileChoice(l10n.profileChoiceEarlyDay, 'Clear Starter'),
        FocusProfileChoice(l10n.profileChoiceBuildMomentum, 'Momentum Builder'),
        FocusProfileChoice(l10n.profileChoiceEvening, 'Night Owl'),
      ],
    ),
    FocusProfileQuestion(
      prompt: l10n.profileQuestionEnvironment,
      choices: [
        FocusProfileChoice(l10n.profileChoiceQuiet, 'Deep Diver'),
        FocusProfileChoice(l10n.profileChoiceGentleSound, 'Gentle Flow'),
        FocusProfileChoice(l10n.profileChoiceClearPlan, 'Momentum Builder'),
      ],
    ),
    FocusProfileQuestion(
      prompt: l10n.profileQuestionStuck,
      choices: [
        FocusProfileChoice(l10n.profileChoiceRemoveDistractions, 'Deep Diver'),
        FocusProfileChoice(l10n.profileChoiceBriefReset, 'Gentle Flow'),
        FocusProfileChoice(l10n.profileChoiceTinyAction, 'Momentum Builder'),
      ],
    ),
    FocusProfileQuestion(
      prompt: l10n.profileQuestionSession,
      choices: [
        FocusProfileChoice(l10n.profileChoiceLongBlock, 'Deep Diver'),
        FocusProfileChoice(l10n.profileChoiceCalmRhythm, 'Gentle Flow'),
        FocusProfileChoice(l10n.profileChoiceQuickSprint, 'Clear Starter'),
      ],
    ),
  ];

  late final List<FocusProfileChoice?> _answers;
  int _page = -1;
  String? _result;
  String? _saveError;
  bool _answerInProgress = false;

  @override
  void initState() {
    super.initState();
    _answers = List<FocusProfileChoice?>.filled(_questionCount, null);
  }

  Future<void> _selectChoice(FocusProfileChoice choice) async {
    final l10n = context.l10n;
    final questions = _questions(l10n);
    final currentChoices = questions[_page].choices;
    if (_answerInProgress ||
        !currentChoices.any(
          (candidate) =>
              candidate.label == choice.label &&
              candidate.focusType == choice.focusType,
        )) {
      return;
    }
    setState(() {
      _answerInProgress = true;
      _saveError = null;
    });

    try {
      _answers[_page] = choice;
      if (_page < questions.length - 1) {
        setState(() => _page++);
        return;
      }

      final scores = <String, int>{};
      for (final answer in _answers.whereType<FocusProfileChoice>()) {
        scores.update(
          answer.focusType,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      final winner = scores.entries
          .reduce((first, next) => first.value >= next.value ? first : next)
          .key;

      final saveFocusType = widget.saveFocusType;
      if (saveFocusType == null) {
        await ref.read(focusProfileServiceProvider).saveFocusType(winner);
      } else {
        await saveFocusType(winner);
      }
      if (!mounted) return;

      setState(() {
        _result = winner;
        _page = questions.length;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saveError = l10n.profileSaveFailed;
      });
    } finally {
      if (mounted) setState(() => _answerInProgress = false);
    }
  }

  String _profileTypeLabel(AppLocalizations l10n, String focusType) =>
      switch (focusType) {
        'Clear Starter' => l10n.profileTypeClearStarter,
        'Momentum Builder' => l10n.profileTypeMomentumBuilder,
        'Deep Diver' => l10n.profileTypeDeepDiver,
        'Gentle Flow' => l10n.profileTypeGentleFlow,
        'Night Owl' => l10n.profileTypeNightOwl,
        _ => focusType,
      };

  String _profileTip(AppLocalizations l10n, String focusType) =>
      switch (focusType) {
        'Clear Starter' => l10n.profileTipClearStarter,
        'Momentum Builder' => l10n.profileTipMomentumBuilder,
        'Deep Diver' => l10n.profileTipDeepDiver,
        'Gentle Flow' => l10n.profileTipGentleFlow,
        'Night Owl' => l10n.profileTipNightOwl,
        _ => l10n.profileTipDefault,
      };

  @override
  Widget build(BuildContext context) {
    final savedFocusType = ref.watch(focusProfileTypeProvider);
    final activeType = _result ?? savedFocusType;

    final questions = _questions(context.l10n);
    if (_page == questions.length && _result != null) {
      final completedType = activeType!;
      return _ResultView(
        focusType: _profileTypeLabel(context.l10n, completedType),
        tip: _profileTip(context.l10n, completedType),
      );
    }

    if (_page == -1) {
      return _IntroductionView(
        activeType: activeType == null
            ? null
            : _profileTypeLabel(context.l10n, activeType),
        onStart: () => setState(() => _page = 0),
      );
    }

    final question = questions[_page];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _BackToAccountButton(),
            const SizedBox(height: 4),
            Text(
              context.l10n.profileQuestionProgress(_page + 1, questions.length),
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 14),
            Text(
              question.prompt,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 8),
              Text(
                _saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            ...question.choices.map(
              (choice) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton(
                  onPressed: _answerInProgress
                      ? null
                      : () => _selectChoice(choice),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: Text(choice.label),
                ),
              ),
            ),
            if (_page > 0) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _answerInProgress
                    ? null
                    : () => setState(() => _page--),
                icon: const Icon(Icons.arrow_back),
                label: Text(context.l10n.profileBackQuestion),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IntroductionView extends StatelessWidget {
  const _IntroductionView({required this.activeType, required this.onStart});

  final String? activeType;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BackToAccountButton(),
            const SizedBox(height: 4),
            Icon(
              Icons.psychology_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.profileIntroductionTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              activeType == null
                  ? context.l10n.profileIntroductionDescription
                  : context.l10n.profileCurrentDescription(activeType!),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: _FocusProfileSheetState._ink,
              ),
              child: Text(
                activeType == null
                    ? context.l10n.profileStartQuiz
                    : context.l10n.profileRetakeQuiz,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.focusType, required this.tip});

  final String focusType;
  final String tip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BackToAccountButton(),
            const SizedBox(height: 4),
            Icon(
              Icons.auto_awesome,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.profileResultTitle,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(focusType, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              tip,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: _FocusProfileSheetState._ink,
              ),
              child: Text(context.l10n.profileUseThis),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackToAccountButton extends StatelessWidget {
  const _BackToAccountButton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        tooltip: context.l10n.profileBackToAccount,
        onPressed: () {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          }
        },
        icon: const Icon(Icons.arrow_back),
      ),
    );
  }
}
