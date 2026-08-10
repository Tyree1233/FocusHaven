import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  static const _questions = [
    FocusProfileQuestion(
      prompt: 'When does focused work feel most natural?',
      choices: [
        FocusProfileChoice('Early in the day', 'Clear Starter'),
        FocusProfileChoice('Once I build momentum', 'Momentum Builder'),
        FocusProfileChoice('Later in the evening', 'Night Owl'),
      ],
    ),
    FocusProfileQuestion(
      prompt: 'Which environment helps you settle in?',
      choices: [
        FocusProfileChoice('Quiet and uninterrupted', 'Deep Diver'),
        FocusProfileChoice('Gentle music or ambient sound', 'Gentle Flow'),
        FocusProfileChoice('A clear plan and small steps', 'Momentum Builder'),
      ],
    ),
    FocusProfileQuestion(
      prompt: 'When you feel stuck, what helps most?',
      choices: [
        FocusProfileChoice('Removing every distraction', 'Deep Diver'),
        FocusProfileChoice('Taking a brief reset', 'Gentle Flow'),
        FocusProfileChoice('Starting with one tiny action', 'Momentum Builder'),
      ],
    ),
    FocusProfileQuestion(
      prompt: 'What kind of session sounds best?',
      choices: [
        FocusProfileChoice('A long, uninterrupted block', 'Deep Diver'),
        FocusProfileChoice('A calm, flexible rhythm', 'Gentle Flow'),
        FocusProfileChoice('A quick, energizing sprint', 'Clear Starter'),
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
    _answers = List<FocusProfileChoice?>.filled(_questions.length, null);
  }

  Future<void> _selectChoice(FocusProfileChoice choice) async {
    if (_answerInProgress || !_questions[_page].choices.contains(choice)) {
      return;
    }
    setState(() {
      _answerInProgress = true;
      _saveError = null;
    });

    try {
      _answers[_page] = choice;
      if (_page < _questions.length - 1) {
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
        _page = _questions.length;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saveError = 'Your focus profile could not be saved. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _answerInProgress = false);
    }
  }

  String _profileTip(String focusType) => switch (focusType) {
    'Clear Starter' =>
      'Protect your best early window with one clear intention and a short timer.',
    'Momentum Builder' =>
      'Start with a small five-minute step. Momentum is your best fuel.',
    'Deep Diver' =>
      'Create a quiet, distraction-free block and let yourself stay with one meaningful task.',
    'Gentle Flow' =>
      'Use calm transitions, a comfortable pace, and intentional breaks to stay steady.',
    'Night Owl' =>
      'Plan your most important work for your later high-energy window and protect your wind-down.',
    _ => 'Choose a calm space and one clear next step.',
  };

  @override
  Widget build(BuildContext context) {
    final savedFocusType = ref.watch(focusProfileTypeProvider);
    final activeType = _result ?? savedFocusType;

    if (_page == _questions.length && _result != null) {
      final completedType = activeType!;
      return _ResultView(
        focusType: completedType,
        tip: _profileTip(completedType),
      );
    }

    if (_page == -1) {
      return _IntroductionView(
        activeType: activeType,
        onStart: () => setState(() => _page = 0),
      );
    }

    final question = _questions[_page];
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
              '${_page + 1} of ${_questions.length}',
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
                label: const Text('Back to previous question'),
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
              'Find your focus profile',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              activeType == null
                  ? 'Answer four quick questions for a practical focus style and tip.'
                  : 'Your current profile is $activeType. Retake the quiz anytime as your habits change.',
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
              child: Text(activeType == null ? 'Start quiz' : 'Retake quiz'),
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
            const Text(
              'Your focus profile',
              style: TextStyle(fontSize: 16, color: Colors.white70),
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
              child: const Text('Use this profile'),
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
        tooltip: 'Back to account settings',
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
