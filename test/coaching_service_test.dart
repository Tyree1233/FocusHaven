import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/models/coaching_message.dart';
import 'package:focushaven/services/coaching_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<CoachingService> createCoach({
    CoachingResponder? responder,
    CoachingResponder? enhancedResponder,
    CoachingConversationSave? saveConversation,
    CoachingEnhancedPreferenceSave? saveEnhancedPreference,
    CoachingPreferenceRemove? removePreference,
  }) async {
    final coach = CoachingService(
      responder: responder,
      enhancedResponder: enhancedResponder,
      saveConversation: saveConversation,
      saveEnhancedPreference: saveEnhancedPreference,
      removePreference: removePreference,
    );
    await coach.initialized;
    return coach;
  }

  test('shares only normalized coaching context', () {
    const context = CoachingContext(
      focusTask: '  Write launch plan  ',
      focusProfile: '  Deep worker ',
      todayFocusMinutes: 35,
      dailyGoalMinutes: 60,
      queueRemaining: 2,
      nextQueueTask: '  Review metrics ',
      recentMood: '  hopeful ',
      parkedThoughtCount: 3,
      isTimerRunning: true,
    );

    expect(context.toPromptData(), {
      'focusTask': 'Write launch plan',
      'focusProfile': 'Deep worker',
      'todayFocusMinutes': 35,
      'dailyGoalMinutes': 60,
      'queueRemaining': 2,
      'nextQueueTask': 'Review metrics',
      'recentMood': 'hopeful',
      'parkedThoughtCount': 3,
      'isTimerRunning': true,
    });
    expect(
      const CoachingContext().toPromptData(),
      isNot(contains('focusTask')),
    );
  });

  test('responds to overwhelm with empathy and a concrete next step', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'I feel overwhelmed and cannot start.',
      context: const CoachingContext(focusTask: 'Write launch plan'),
      conversation: const [],
    );

    expect(response, contains('a lot to hold'));
    expect(response, contains('Write launch plan'));
    expect(response, contains('two minutes'));
    expect(response, contains('three tiny steps'));
  });

  test('puts immediate safety ahead of productivity coaching', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'I want to kill myself.',
      context: const CoachingContext(focusTask: 'Finish the report'),
      conversation: const [],
    );

    expect(response, contains('Your safety matters'));
    expect(response, contains('emergency services'));
    expect(response, contains('someone you trust'));
    expect(response, contains('not a substitute for crisis care'));
    expect(response, isNot(contains('Finish the report')));
  });

  test('recognizes broader immediate safety language locally', () async {
    const responder = LocalCoachingResponder();

    for (final message in const [
      'I wish I were dead.',
      'There is no reason to live.',
      'I am thinking about taking my life.',
    ]) {
      final response = await responder.respond(
        message: message,
        context: const CoachingContext(focusTask: 'Keep working'),
        conversation: const [],
      );

      expect(response, contains('Your safety matters'));
      expect(response, contains('someone you trust'));
      expect(response, isNot(contains('Keep working')));
    }
  });

  test('recognizes immediate safety and boundaries in Spanish', () async {
    const responder = LocalCoachingResponder();
    final l10n = lookupAppLocalizations(const Locale('es'));

    for (final message in const [
      'Quiero matarme.',
      'No quiero vivir.',
      'Estoy pensando en suicidarme.',
    ]) {
      final response = await responder.respond(
        message: message,
        context: CoachingContext(
          focusTask: 'Terminar el informe',
          localizations: l10n,
        ),
        conversation: const [],
      );

      expect(response, contains('Tu seguridad importa'));
      expect(response, isNot(contains('Terminar el informe')));
    }

    final boundaryResponse = await responder.respond(
      message: 'Ahora no. Necesito espacio.',
      context: CoachingContext(localizations: l10n),
      conversation: const [],
    );
    expect(boundaryResponse, contains('espacio'));
  });

  test('responds to setbacks without turning them into identity', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'I tried, but I am still stuck.',
      context: const CoachingContext(focusTask: 'Outline the proposal'),
      conversation: const [],
    );

    expect(response, contains('already made an effort'));
    expect(response, contains('information, not proof that you failed'));
    expect(response, contains('Outline the proposal'));
    expect(response, contains('one reset'));
  });

  test(
    'meets self-criticism and perfectionism with specific reframes',
    () async {
      const responder = LocalCoachingResponder();

      final selfCriticism = await responder.respond(
        message: 'I am lazy. What is wrong with me?',
        context: const CoachingContext(focusTask: 'Write the introduction'),
        conversation: const [],
      );
      final perfectionism = await responder.respond(
        message: 'I am afraid it will be bad and not good enough.',
        context: const CoachingContext(focusTask: 'Design the first screen'),
        conversation: const [],
      );

      expect(selfCriticism, contains('not your identity'));
      expect(selfCriticism, contains('clarity, energy, or fear'));
      expect(perfectionism, contains('rough version'));
      expect(perfectionism, contains('Design the first screen'));
      expect(perfectionism, contains('good enough for this session'));
    },
  );

  test('turns indecision and deadline pressure into bounded choices', () async {
    const responder = LocalCoachingResponder();

    final decision = await responder.respond(
      message: 'I cannot decide. There are too many options.',
      context: const CoachingContext(
        focusTask: 'Prepare the launch email',
        queueRemaining: 4,
      ),
      conversation: const [],
    );
    final deadline = await responder.respond(
      message: 'I am running out of time before the deadline.',
      context: const CoachingContext(focusTask: 'Submit the application'),
      conversation: const [],
    );

    expect(decision, contains('4 items waiting'));
    expect(decision, contains('one short trial round'));
    expect(deadline, contains('smallest acceptable outcome'));
    expect(deadline, contains('Submit the application'));
    expect(deadline, contains('What can safely be left out?'));
  });

  test('continues a coaching thread with concrete smaller steps', () async {
    const responder = LocalCoachingResponder();
    final conversation = [
      CoachingMessage(
        id: 'coach-1',
        role: CoachingMessageRole.coach,
        text: 'Want to break it into smaller steps?',
        createdAt: DateTime.utc(2026, 8, 15),
      ),
    ];

    final response = await responder.respond(
      message: 'Yes please, break it down.',
      context: const CoachingContext(focusTask: 'Plan the workshop'),
      conversation: conversation,
    );

    expect(response, contains('step we were discussing'));
    expect(response, contains('Plan the workshop'));
    expect(response, contains('rough pass for five minutes'));
    expect(response, contains('Do only the first step right now'));
  });

  test('recalls a recent obstacle without repeating private wording', () async {
    const responder = LocalCoachingResponder();
    final conversation = [
      CoachingMessage(
        id: 'user-private',
        role: CoachingMessageRole.user,
        text: 'I cannot start because the private client details feel huge.',
        createdAt: DateTime.utc(2026, 8, 15, 9),
      ),
      CoachingMessage(
        id: 'coach-private',
        role: CoachingMessageRole.coach,
        text: 'Let’s lower the stakes and begin gently.',
        createdAt: DateTime.utc(2026, 8, 15, 9, 1),
      ),
    ];

    final response = await responder.respond(
      message: 'Can you help me keep going?',
      context: const CoachingContext(focusTask: 'Prepare the client brief'),
      conversation: conversation,
    );

    expect(
      response,
      contains('Earlier, you were dealing with getting started'),
    );
    expect(response, contains('Prepare the client brief'));
    expect(response, isNot(contains('private client details')));
  });

  test('changes tactics instead of repeating a starting prompt', () async {
    const responder = LocalCoachingResponder();
    final conversation = [
      CoachingMessage(
        id: 'user-start',
        role: CoachingMessageRole.user,
        text: 'I cannot start.',
        createdAt: DateTime.utc(2026, 8, 15, 10),
      ),
      CoachingMessage(
        id: 'coach-start',
        role: CoachingMessageRole.coach,
        text: 'For the next five minutes, begin. Starting is the win.',
        createdAt: DateTime.utc(2026, 8, 15, 10, 1),
      ),
    ];

    final response = await responder.respond(
      message: 'I still cannot start.',
      context: const CoachingContext(focusTask: 'Draft the first paragraph'),
      conversation: conversation,
    );

    expect(response, contains('change the experiment'));
    expect(response, contains('Draft the first paragraph'));
    expect(response, contains('sixty seconds'));
    expect(response, contains('continue for two minutes'));
    expect(response, isNot(contains('next five minutes')));
  });

  test('uses the remembered obstacle in a requested breakdown', () async {
    const responder = LocalCoachingResponder();
    final conversation = [
      CoachingMessage(
        id: 'user-overwhelm',
        role: CoachingMessageRole.user,
        text: 'I feel overwhelmed by everything involved.',
        createdAt: DateTime.utc(2026, 8, 15, 11),
      ),
      CoachingMessage(
        id: 'coach-overwhelm',
        role: CoachingMessageRole.coach,
        text: 'Want to break it into three tiny steps together?',
        createdAt: DateTime.utc(2026, 8, 15, 11, 1),
      ),
    ];

    final response = await responder.respond(
      message: 'Yes please, break it down.',
      context: const CoachingContext(focusTask: 'Organize the workshop'),
      conversation: conversation,
    );

    expect(response, contains('Since overwhelm was the sticking point'));
    expect(response, contains('keep each step deliberately small'));
    expect(response, contains('Organize the workshop'));
  });

  test('uses recent context to reframe an unsuccessful attempt', () async {
    const responder = LocalCoachingResponder();
    final conversation = [
      CoachingMessage(
        id: 'user-choice',
        role: CoachingMessageRole.user,
        text: 'I cannot decide because there are too many options.',
        createdAt: DateTime.utc(2026, 8, 15, 12),
      ),
      CoachingMessage(
        id: 'coach-choice',
        role: CoachingMessageRole.coach,
        text: 'Try one reversible choice for a short round.',
        createdAt: DateTime.utc(2026, 8, 15, 12, 1),
      ),
    ];

    final response = await responder.respond(
      message: "I tried, but that didn't work.",
      context: const CoachingContext(focusTask: 'Choose the launch concept'),
      conversation: conversation,
    );

    expect(response, contains('already working with too many choices'));
    expect(response, contains('different experiment'));
    expect(response, contains('Choose the launch concept'));
  });

  test(
    'does not turn a safety disclosure into ordinary coaching memory',
    () async {
      const responder = LocalCoachingResponder();
      final conversation = [
        CoachingMessage(
          id: 'user-safety',
          role: CoachingMessageRole.user,
          text: 'I wish I were dead.',
          createdAt: DateTime.utc(2026, 8, 15, 13),
        ),
        CoachingMessage(
          id: 'coach-safety',
          role: CoachingMessageRole.coach,
          text: 'Your safety matters. Please reach out to someone you trust.',
          createdAt: DateTime.utc(2026, 8, 15, 13, 1),
        ),
      ];

      final response = await responder.respond(
        message: 'Can we talk about tomorrow?',
        context: const CoachingContext(focusTask: 'Make a gentle plan'),
        conversation: conversation,
      );

      expect(response, isNot(contains('Earlier, you were dealing with')));
      expect(response, isNot(contains('wish I were dead')));
      expect(response, contains('what feels hardest right now'));
    },
  );

  test(
    'recognizes partial progress without treating the task as done',
    () async {
      const responder = LocalCoachingResponder();
      final conversation = [
        CoachingMessage(
          id: 'user-could-not-start',
          role: CoachingMessageRole.user,
          text: 'I cannot start this.',
          createdAt: DateTime.utc(2026, 8, 15, 14),
        ),
        CoachingMessage(
          id: 'coach-start-small',
          role: CoachingMessageRole.coach,
          text: 'Try one small physical action.',
          createdAt: DateTime.utc(2026, 8, 15, 14, 1),
        ),
      ];

      final response = await responder.respond(
        message: 'I finished the first step.',
        context: const CoachingContext(
          focusTask: 'Build the project outline',
          isTimerRunning: true,
        ),
        conversation: conversation,
      );

      expect(response, contains('That is real progress'));
      expect(
        response,
        contains('after getting started was getting in the way'),
      );
      expect(response, contains('Stay with the current session'));
      expect(response, contains('Build the project outline'));
      expect(response, contains('next action no larger'));
      expect(response, isNot(contains('What helped this time')));
    },
  );

  test('welcomes a return from a break with a gentle re-entry', () async {
    const responder = LocalCoachingResponder();
    final conversation = [
      CoachingMessage(
        id: 'user-low-energy',
        role: CoachingMessageRole.user,
        text: 'I am exhausted and have no energy.',
        createdAt: DateTime.utc(2026, 8, 15, 15),
      ),
      CoachingMessage(
        id: 'coach-break',
        role: CoachingMessageRole.coach,
        text: 'Take a short break first.',
        createdAt: DateTime.utc(2026, 8, 15, 15, 1),
      ),
    ];

    final response = await responder.respond(
      message: "I'm back after a break.",
      context: const CoachingContext(focusTask: 'Review the research notes'),
      conversation: conversation,
    );

    expect(response, startsWith('Welcome back'));
    expect(
      response,
      contains('Since low energy was part of the earlier struggle'),
    );
    expect(response, contains('Review the research notes'));
    expect(response, contains('last visible action'));
    expect(response, contains('two minutes'));
  });

  test('offers a real break with a clear path back', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'I need a break.',
      context: const CoachingContext(
        focusTask: 'Draft the project brief',
        isTimerRunning: true,
      ),
      conversation: const [],
    );

    expect(response, contains('real five-minute break'));
    expect(response, contains('Pause the timer'));
    expect(response, contains('Draft the project brief'));
    expect(response, contains('say “I’m back'));
  });

  test('protects recovery when a break follows the daily goal', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'I need to take a break.',
      context: const CoachingContext(
        focusTask: 'Keep polishing the report',
        todayFocusMinutes: 60,
        dailyGoalMinutes: 60,
      ),
      conversation: const [],
    );

    expect(response, startsWith('Yes—take the break'));
    expect(response, contains('met today’s focus goal'));
    expect(response, contains('let recovery count'));
    expect(response, isNot(contains('Keep polishing the report')));
  });

  test('celebrates full completion with remembered effort', () async {
    const responder = LocalCoachingResponder();
    final conversation = [
      CoachingMessage(
        id: 'user-perfectionism',
        role: CoachingMessageRole.user,
        text: 'I am afraid it will be bad and not good enough.',
        createdAt: DateTime.utc(2026, 8, 15, 16),
      ),
      CoachingMessage(
        id: 'coach-rough-version',
        role: CoachingMessageRole.coach,
        text: 'Make one useful rough version.',
        createdAt: DateTime.utc(2026, 8, 15, 16, 1),
      ),
    ];

    final response = await responder.respond(
      message: 'I finished it.',
      context: const CoachingContext(todayFocusMinutes: 42),
      conversation: conversation,
    );

    expect(response, startsWith('That counts'));
    expect(response, contains('42 minutes of focus'));
    expect(response, contains('working through perfectionism'));
    expect(response, contains('What helped this time'));
  });

  test('keeps safety ahead of returning and progress language', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: "I'm back and I made progress, but I want to die.",
      context: const CoachingContext(focusTask: 'Keep working'),
      conversation: const [],
    );

    expect(response, contains('Your safety matters'));
    expect(response, contains('emergency services'));
    expect(response, isNot(contains('Welcome back')));
    expect(response, isNot(contains('That is real progress')));
    expect(response, isNot(contains('Keep working')));
  });

  test('listens without fixing when the user asks to vent', () async {
    const responder = LocalCoachingResponder();
    final conversation = [
      CoachingMessage(
        id: 'user-overwhelmed-listening',
        role: CoachingMessageRole.user,
        text: 'I feel overwhelmed by all of this.',
        createdAt: DateTime.utc(2026, 8, 15, 17),
      ),
    ];

    final response = await responder.respond(
      message: 'I am overwhelmed, but I need to vent. Please just listen.',
      context: const CoachingContext(focusTask: 'Finish the presentation'),
      conversation: conversation,
    );

    expect(response, contains('do not have to turn this into a plan'));
    expect(response, contains('overwhelm has been wearing on you'));
    expect(response, contains('listen without trying to fix it'));
    expect(response, isNot(contains('Finish the presentation')));
    expect(response, isNot(contains('two minutes')));
  });

  test('offers direct accountability without shame', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'Be direct and hold me accountable.',
      context: const CoachingContext(
        focusTask: 'Write the release notes',
        queueRemaining: 3,
        isTimerRunning: true,
      ),
      conversation: const [],
    );

    expect(response, startsWith('Direct version, without shame'));
    expect(response, contains('Write the release notes'));
    expect(response, contains('Ignore the other 2 queued items'));
    expect(response, contains('Your timer is running'));
    expect(response, contains('next visible action'));
  });

  test('direct accountability protects recovery after the goal', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'Push me and give it to me straight.',
      context: const CoachingContext(
        focusTask: 'Do even more work',
        todayFocusMinutes: 75,
        dailyGoalMinutes: 60,
      ),
      conversation: const [],
    );

    expect(response, startsWith('Direct answer'));
    expect(response, contains('already met today’s focus goal'));
    expect(response, contains('stop intentionally'));
    expect(response, contains('protect tomorrow’s attention'));
    expect(response, isNot(contains('ten minutes')));
    expect(response, isNot(contains('Do even more work')));
  });

  test(
    'uses recent context when the user does not know what they need',
    () async {
      const responder = LocalCoachingResponder();
      final conversation = [
        CoachingMessage(
          id: 'user-distraction-unsure',
          role: CoachingMessageRole.user,
          text: 'I keep getting distracted and my mind keeps wandering.',
          createdAt: DateTime.utc(2026, 8, 15, 18),
        ),
        CoachingMessage(
          id: 'coach-distraction-unsure',
          role: CoachingMessageRole.coach,
          text: 'Let the thought stay parked while you return.',
          createdAt: DateTime.utc(2026, 8, 15, 18, 1),
        ),
      ];

      final response = await responder.respond(
        message: "I don't know.",
        context: const CoachingContext(focusTask: 'Read the next section'),
        conversation: conversation,
      );

      expect(response, contains('Not knowing is allowed'));
      expect(response, contains('Since distraction has been the obstacle'));
      expect(response, contains('real five-minute reset'));
      expect(response, contains('two-minute action'));
      expect(response, contains('Read the next section'));
    },
  );

  test(
    'makes uncertainty smaller without inventing conversation memory',
    () async {
      const responder = LocalCoachingResponder();

      final response = await responder.respond(
        message: 'I am not sure.',
        context: const CoachingContext(focusTask: 'Prepare tomorrow’s plan'),
        conversation: const [],
      );

      expect(response, contains('make the question smaller'));
      expect(response, contains('Prepare tomorrow’s plan'));
      expect(response, contains('I need clarity'));
      expect(response, contains('I need energy'));
      expect(response, contains('afraid to begin'));
      expect(response, contains('not the perfect one'));
    },
  );

  test('offers an explicitly gentle coaching response', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'Please be gentle with me.',
      context: const CoachingContext(focusTask: 'Write the difficult email'),
      conversation: const [],
    );

    expect(response, contains('I’ll keep this gentle'));
    expect(response, contains('Write the difficult email'));
    expect(response, contains('encouragement'));
    expect(response, contains('a very small next step'));
  });

  test('remembers a request for listening on an ambiguous follow-up', () async {
    const responder = LocalCoachingResponder();
    final conversation = [
      CoachingMessage(
        id: 'user-listening-preference',
        role: CoachingMessageRole.user,
        text: 'Please just listen. I do not want advice right now.',
        createdAt: DateTime.utc(2026, 8, 15, 19),
      ),
      CoachingMessage(
        id: 'coach-listening-preference',
        role: CoachingMessageRole.coach,
        text: 'I’ll stay with you and listen without trying to fix it.',
        createdAt: DateTime.utc(2026, 8, 15, 19, 1),
      ),
    ];

    final response = await responder.respond(
      message: 'There is more I need to say.',
      context: const CoachingContext(focusTask: 'Finish the proposal'),
      conversation: conversation,
    );

    expect(response, contains('do not have to turn this into a plan'));
    expect(response, contains('listen without trying to fix it'));
    expect(response, isNot(contains('Finish the proposal')));
  });

  test('remembers direct support when uncertainty follows', () async {
    const responder = LocalCoachingResponder();
    final conversation = [
      CoachingMessage(
        id: 'user-direct-preference',
        role: CoachingMessageRole.user,
        text: 'Be direct and hold me accountable.',
        createdAt: DateTime.utc(2026, 8, 15, 20),
      ),
      CoachingMessage(
        id: 'coach-direct-preference',
        role: CoachingMessageRole.coach,
        text: 'Direct version, without shame: start one focus round.',
        createdAt: DateTime.utc(2026, 8, 15, 20, 1),
      ),
    ];

    final response = await responder.respond(
      message: 'I am not sure.',
      context: const CoachingContext(focusTask: 'Outline the presentation'),
      conversation: conversation,
    );

    expect(response, startsWith('You asked me to stay direct'));
    expect(response, contains('two-minute action'));
    expect(response, contains('Outline the presentation'));
    expect(response, isNot(contains('Pick the nearest answer')));
  });

  test('the latest support preference replaces the earlier one', () async {
    const responder = LocalCoachingResponder();
    final conversation = [
      CoachingMessage(
        id: 'user-old-direct-preference',
        role: CoachingMessageRole.user,
        text: 'Push me and be direct.',
        createdAt: DateTime.utc(2026, 8, 15, 21),
      ),
      CoachingMessage(
        id: 'coach-old-direct-preference',
        role: CoachingMessageRole.coach,
        text: 'Direct version, without shame.',
        createdAt: DateTime.utc(2026, 8, 15, 21, 1),
      ),
      CoachingMessage(
        id: 'user-new-gentle-preference',
        role: CoachingMessageRole.user,
        text: 'Please go easy on me and be gentle.',
        createdAt: DateTime.utc(2026, 8, 15, 21, 2),
      ),
      CoachingMessage(
        id: 'coach-new-gentle-preference',
        role: CoachingMessageRole.coach,
        text: 'Absolutely. I’ll keep this gentle.',
        createdAt: DateTime.utc(2026, 8, 15, 21, 3),
      ),
    ];

    final response = await responder.respond(
      message: 'Can you help me with this?',
      context: const CoachingContext(focusTask: 'Review the budget'),
      conversation: conversation,
    );

    expect(
      response,
      startsWith('I remember that you wanted a gentler approach'),
    );
    expect(response, contains('Review the budget'));
    expect(response, isNot(contains('You asked me to stay direct')));
  });

  test(
    'does not infer a support preference from a safety disclosure',
    () async {
      const responder = LocalCoachingResponder();
      final conversation = [
        CoachingMessage(
          id: 'user-safety-not-preference',
          role: CoachingMessageRole.user,
          text: 'I want to die.',
          createdAt: DateTime.utc(2026, 8, 15, 22),
        ),
        CoachingMessage(
          id: 'coach-safety-not-preference',
          role: CoachingMessageRole.coach,
          text: 'Your safety matters. Reach out to someone you trust.',
          createdAt: DateTime.utc(2026, 8, 15, 22, 1),
        ),
      ];

      final response = await responder.respond(
        message: 'Can you stay with me for a moment?',
        context: const CoachingContext(focusTask: 'Make a gentle plan'),
        conversation: conversation,
      );

      expect(response, contains('We can keep this gentle and practical'));
      expect(response, contains('Make a gentle plan'));
      expect(response, isNot(contains('Your safety matters')));
      expect(response, isNot(contains('I remember that you wanted')));
    },
  );

  test('respects requests for space without productivity pressure', () async {
    const responder = LocalCoachingResponder();

    for (final message in const [
      'Stop coaching me.',
      'Not right now.',
      'Please leave me alone.',
      'I need some space.',
      'No more advice.',
    ]) {
      final response = await responder.respond(
        message: message,
        context: const CoachingContext(focusTask: 'Finish the launch plan'),
        conversation: const [],
      );

      expect(response, startsWith('Okay. I’ll stop here'));
      expect(response, contains('No next step'));
      expect(response, contains('nothing to prove'));
      expect(response, contains('come back whenever you choose'));
      expect(response, isNot(contains('Finish the launch plan')));
      expect(response, isNot(contains('focus round')));
    }
  });

  test('keeps safety ahead of a request to stop coaching', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'Stop coaching me. I want to die.',
      context: const CoachingContext(focusTask: 'Keep working'),
      conversation: const [],
    );

    expect(response, contains('Your safety matters'));
    expect(response, contains('someone you trust'));
    expect(response, isNot(contains('I’ll stop here')));
    expect(response, isNot(contains('Keep working')));
  });

  test('keeps safety ahead of a request for listening', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'Please just listen. I want to die.',
      context: const CoachingContext(focusTask: 'Keep working'),
      conversation: const [],
    );

    expect(response, contains('Your safety matters'));
    expect(response, contains('someone you trust'));
    expect(response, isNot(contains('listen without trying to fix it')));
    expect(response, isNot(contains('Keep working')));
  });

  test('repairs coaching misunderstandings without defensiveness', () async {
    const responder = LocalCoachingResponder();

    for (final message in const [
      'That’s not what I meant.',
      'You misunderstood me.',
      'That is not what I need.',
      'That doesn’t help.',
      'That does not help.',
      'You are not listening.',
    ]) {
      final response = await responder.respond(
        message: message,
        context: const CoachingContext(focusTask: 'Finish the launch plan'),
        conversation: const [],
      );

      expect(response, startsWith('Thank you for correcting me'));
      expect(response, contains('I misunderstood'));
      expect(response, contains('I’m sorry'));
      expect(response, contains('without making you repeat everything'));
      expect(response, contains('listening without advice'));
      expect(response, contains('gentle support'));
      expect(response, contains('a direct next step'));
      expect(response, isNot(contains('Finish the launch plan')));
    }
  });

  test('keeps safety and boundaries ahead of conversation repair', () async {
    const responder = LocalCoachingResponder();

    final safetyResponse = await responder.respond(
      message: 'You misunderstood me. I want to die.',
      context: const CoachingContext(focusTask: 'Keep working'),
      conversation: const [],
    );
    final boundaryResponse = await responder.respond(
      message: 'You misunderstood me. Please leave me alone.',
      context: const CoachingContext(focusTask: 'Keep working'),
      conversation: const [],
    );

    expect(safetyResponse, contains('Your safety matters'));
    expect(safetyResponse, isNot(contains('I misunderstood')));
    expect(boundaryResponse, startsWith('Okay. I’ll stop here'));
    expect(boundaryResponse, isNot(contains('I misunderstood')));
  });

  test('keeps conversation repair on the local responder', () async {
    final enhancedResponder = _RecordingResponder(
      'This remote response must not be used.',
    );
    final coach = await createCoach(enhancedResponder: enhancedResponder);
    addTearDown(coach.dispose);
    await coach.setEnhancedCoachingEnabled(true);

    expect(
      await coach.send(
        'That’s not what I need.',
        const CoachingContext(focusTask: 'Finish the report'),
      ),
      isTrue,
    );

    expect(enhancedResponder.calls, 0);
    expect(coach.messages.last.text, contains('I misunderstood'));
    expect(coach.messages.last.text, contains('What would fit better'));
    expect(coach.messages.last.text, isNot(contains('Finish the report')));
  });

  test('slows down for reflective coaching requests', () async {
    const responder = LocalCoachingResponder();

    for (final message in const [
      'Help me think this through.',
      'Can we think this through?',
      'I need to process this.',
      'Talk this through with me.',
      'Help me sort this out.',
    ]) {
      final response = await responder.respond(
        message: message,
        context: const CoachingContext(focusTask: 'Finish the launch plan'),
        conversation: const [],
      );

      expect(response, startsWith('Let’s slow this down'));
      expect(response, contains('do not need to turn it into a decision'));
      expect(response, contains('most important to understand'));
      expect('?'.allMatches(response), hasLength(1));
      expect(response, isNot(contains('Finish the launch plan')));
      expect(response, isNot(contains('next step')));
    }
  });

  test('reflects emotional conflict with one thoughtful question', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'I feel torn. Part of me wants to go and part wants to stay.',
      context: const CoachingContext(focusTask: 'Make the decision'),
      conversation: const [],
    );

    expect(response, contains('two honest needs'));
    expect(response, contains('pulling in different directions'));
    expect(response, contains('Neither one has to be argued away'));
    expect(response, contains('harder to disappoint'));
    expect('?'.allMatches(response), hasLength(1));
    expect(response, isNot(contains('Make the decision')));
  });

  test('continues reflection without rushing into task advice', () async {
    const responder = LocalCoachingResponder();
    final conversation = [
      CoachingMessage(
        id: 'reflection-user',
        role: CoachingMessageRole.user,
        text: 'Help me think this through.',
        createdAt: DateTime.utc(2026, 8, 15),
      ),
      CoachingMessage(
        id: 'reflection-coach',
        role: CoachingMessageRole.coach,
        text: 'What part feels most important to understand first?',
        createdAt: DateTime.utc(2026, 8, 15, 0, 1),
      ),
      CoachingMessage(
        id: 'reflection-follow-up',
        role: CoachingMessageRole.user,
        text: 'I am afraid I will disappoint everyone.',
        createdAt: DateTime.utc(2026, 8, 15, 0, 2),
      ),
    ];

    final response = await responder.respond(
      message: conversation.last.text,
      context: const CoachingContext(focusTask: 'Choose a direction'),
      conversation: conversation,
    );

    expect(response, contains('fear sounds like it is carrying'));
    expect(response, contains('trying to protect you from'));
    expect('?'.allMatches(response), hasLength(1));
    expect(response, isNot(contains('Choose a direction')));
    expect(response, isNot(contains('focus round')));
  });

  test(
    'keeps reflective threads local with safety and boundaries first',
    () async {
      final enhancedResponder = _RecordingResponder(
        'This remote response must not be used.',
      );
      final coach = await createCoach(enhancedResponder: enhancedResponder);
      addTearDown(coach.dispose);
      await coach.setEnhancedCoachingEnabled(true);
      const context = CoachingContext(focusTask: 'Choose a direction');

      expect(await coach.send('Help me think this through.', context), isTrue);
      expect(enhancedResponder.calls, 0);
      expect(coach.messages.last.text, startsWith('Let’s slow this down'));

      expect(
        await coach.send('I am afraid I will disappoint everyone.', context),
        isTrue,
      );
      expect(enhancedResponder.calls, 0);
      expect(coach.messages.last.text, contains('trying to protect you from'));

      expect(
        await coach.send('I want to die. Help me think this through.', context),
        isTrue,
      );
      expect(enhancedResponder.calls, 0);
      expect(coach.messages.last.text, contains('Your safety matters'));
      expect(coach.messages.last.text, isNot(contains('Let’s slow this down')));

      expect(
        await coach.send('I need space. Help me think this through.', context),
        isTrue,
      );
      expect(enhancedResponder.calls, 0);
      expect(coach.messages.last.text, startsWith('Okay. I’ll stop here'));
      expect(coach.messages.last.text, isNot(contains('Let’s slow this down')));
    },
  );

  test('encourages recovery after the daily focus goal is met', () async {
    const responder = LocalCoachingResponder();

    final response = await responder.respond(
      message: 'I am exhausted and have no energy.',
      context: const CoachingContext(
        todayFocusMinutes: 75,
        dailyGoalMinutes: 60,
      ),
      conversation: const [],
    );

    expect(response, contains('already met today’s focus goal'));
    expect(response, contains('Rest is not falling behind'));
  });

  test('falls back locally when a primary coach fails or is empty', () async {
    const context = CoachingContext(focusTask: 'Draft release notes');
    final failureFallback = ResilientCoachingResponder(
      primary: _CallbackResponder((_) => throw StateError('offline')),
      fallback: const LocalCoachingResponder(),
    );
    final emptyFallback = ResilientCoachingResponder(
      primary: _CallbackResponder((_) async => '   '),
      fallback: const LocalCoachingResponder(),
    );

    final failedResponse = await failureFallback.respond(
      message: 'I am stuck.',
      context: context,
      conversation: const [],
    );
    final emptyResponse = await emptyFallback.respond(
      message: 'What should I do next?',
      context: context,
      conversation: const [],
    );

    expect(failedResponse, contains('Draft release notes'));
    expect(failedResponse, contains('five minutes'));
    expect(emptyResponse, contains('Start with'));
    expect(emptyResponse, contains('Draft release notes'));
  });

  test(
    'reports a successful private fallback without losing messages',
    () async {
      final localResponder = _RecordingResponder('Private local guidance.');
      final enhancedResponder = ResilientCoachingResponder(
        primary: _CallbackResponder(
          (_) => throw const CoachingFallbackException(
            CoachingFallbackReason.allowanceReached,
          ),
        ),
        fallback: localResponder,
      );
      final coach = await createCoach(
        responder: localResponder,
        enhancedResponder: enhancedResponder,
      );
      addTearDown(coach.dispose);

      expect(await coach.setEnhancedCoachingEnabled(true), isTrue);
      expect(
        await coach.send('Help me begin.', const CoachingContext()),
        isTrue,
      );

      expect(coach.messages.map((message) => message.text), [
        'Help me begin.',
        'Private local guidance.',
      ]);
      expect(coach.errorMessage, isNull);
      expect(
        coach.noticeMessage,
        'Your enhanced AI allowance has been reached for this month. '
        'Your private local coach answered instead.',
      );

      expect(await coach.setEnhancedCoachingEnabled(false), isTrue);
      expect(coach.noticeMessage, isNull);
      expect(
        await coach.send('Help me continue.', const CoachingContext()),
        isTrue,
      );
      expect(coach.noticeMessage, isNull);
      expect(coach.messages, hasLength(4));
    },
  );

  test('enhanced coaching requires opt-in and persists the choice', () async {
    final localResponder = _RecordingResponder('Local guidance.');
    final enhancedResponder = _RecordingResponder('Enhanced guidance.');
    final coach = await createCoach(
      responder: localResponder,
      enhancedResponder: enhancedResponder,
    );

    expect(coach.enhancedCoachingAvailable, isTrue);
    expect(coach.enhancedCoachingEnabled, isFalse);
    expect(await coach.send('Help me begin.', const CoachingContext()), isTrue);
    expect(localResponder.calls, 1);
    expect(enhancedResponder.calls, 0);

    expect(await coach.setEnhancedCoachingEnabled(true), isTrue);
    expect(coach.enhancedCoachingEnabled, isTrue);
    expect(
      await coach.send('Help me continue.', const CoachingContext()),
      isTrue,
    );
    expect(localResponder.calls, 1);
    expect(enhancedResponder.calls, 1);
    coach.dispose();

    final restoredEnhancedResponder = _RecordingResponder(
      'Restored enhanced guidance.',
    );
    final restoredCoach = await createCoach(
      enhancedResponder: restoredEnhancedResponder,
    );
    addTearDown(restoredCoach.dispose);

    expect(restoredCoach.enhancedCoachingEnabled, isTrue);
    expect(
      await restoredCoach.send('Help me finish.', const CoachingContext()),
      isTrue,
    );
    expect(restoredEnhancedResponder.calls, 1);
  });

  test('a rejected opt-in never enables the enhanced responder', () async {
    final localResponder = _RecordingResponder('Local guidance.');
    final enhancedResponder = _RecordingResponder('Enhanced guidance.');
    final coach = await createCoach(
      responder: localResponder,
      enhancedResponder: enhancedResponder,
      saveEnhancedPreference: (_, _) async => false,
    );
    addTearDown(coach.dispose);

    expect(await coach.setEnhancedCoachingEnabled(true), isFalse);
    expect(coach.enhancedCoachingEnabled, isFalse);
    expect(
      coach.errorMessage,
      'Your enhanced coaching preference could not be saved. Please retry.',
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('enhancedCoachingEnabled'), isFalse);

    expect(await coach.send('Help me begin.', const CoachingContext()), isTrue);
    expect(localResponder.calls, 1);
    expect(enhancedResponder.calls, 0);
  });

  test('a thrown opt-in stays disabled and exposes a safe retry', () async {
    final localResponder = _RecordingResponder('Local guidance.');
    final enhancedResponder = _RecordingResponder('Enhanced guidance.');
    final coach = await createCoach(
      responder: localResponder,
      enhancedResponder: enhancedResponder,
      saveEnhancedPreference: (_, _) async {
        throw StateError('consent storage unavailable');
      },
    );
    addTearDown(coach.dispose);

    await expectLater(
      coach.setEnhancedCoachingEnabled(true),
      completion(false),
    );

    expect(coach.enhancedCoachingEnabled, isFalse);
    expect(
      coach.errorMessage,
      'Your enhanced coaching preference could not be saved. Please retry.',
    );
    expect(coach.noticeMessage, isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('enhancedCoachingEnabled'), isFalse);

    expect(await coach.send('Help me begin.', const CoachingContext()), isTrue);
    expect(localResponder.calls, 1);
    expect(enhancedResponder.calls, 0);
  });

  test('a rejected opt-out keeps the prior consent state visible', () async {
    var saveCalls = 0;
    final coach = await createCoach(
      enhancedResponder: _RecordingResponder('Enhanced guidance.'),
      saveEnhancedPreference: (preferences, enabled) async {
        saveCalls += 1;
        if (saveCalls > 1) return false;
        return preferences.setBool('enhancedCoachingEnabled', enabled);
      },
    );
    addTearDown(coach.dispose);

    expect(await coach.setEnhancedCoachingEnabled(true), isTrue);
    expect(await coach.setEnhancedCoachingEnabled(false), isFalse);

    expect(saveCalls, 2);
    expect(coach.enhancedCoachingEnabled, isTrue);
    expect(
      coach.errorMessage,
      'Your enhanced coaching preference could not be saved. Please retry.',
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('enhancedCoachingEnabled'), isTrue);
  });

  test('a thrown opt-out keeps the last verified consent visible', () async {
    var saveCalls = 0;
    final coach = await createCoach(
      enhancedResponder: _RecordingResponder('Enhanced guidance.'),
      saveEnhancedPreference: (preferences, enabled) async {
        saveCalls += 1;
        if (saveCalls > 1) {
          throw StateError('consent storage unavailable');
        }
        return preferences.setBool('enhancedCoachingEnabled', enabled);
      },
    );
    addTearDown(coach.dispose);

    expect(await coach.setEnhancedCoachingEnabled(true), isTrue);
    await expectLater(
      coach.setEnhancedCoachingEnabled(false),
      completion(false),
    );

    expect(saveCalls, 2);
    expect(coach.enhancedCoachingEnabled, isTrue);
    expect(
      coach.errorMessage,
      'Your enhanced coaching preference could not be saved. Please retry.',
    );
    expect(coach.noticeMessage, isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('enhancedCoachingEnabled'), isTrue);
  });

  test('an in-flight consent write blocks other private actions', () async {
    final saveStarted = Completer<void>();
    final allowSave = Completer<void>();
    final localResponder = _RecordingResponder('Local guidance.');
    final coach = await createCoach(
      responder: localResponder,
      enhancedResponder: _RecordingResponder('Enhanced guidance.'),
      saveEnhancedPreference: (preferences, enabled) async {
        saveStarted.complete();
        await allowSave.future;
        return preferences.setBool('enhancedCoachingEnabled', enabled);
      },
    );
    addTearDown(coach.dispose);

    final optIn = coach.setEnhancedCoachingEnabled(true);
    await saveStarted.future;

    expect(coach.isManagingPrivateData, isTrue);
    expect(
      await coach.send('Do not race this.', const CoachingContext()),
      isFalse,
    );
    expect(await coach.clearLocalData(), isFalse);
    expect(await coach.setEnhancedCoachingEnabled(true), isFalse);
    expect(localResponder.calls, 0);

    allowSave.complete();
    expect(await optIn, isTrue);
    expect(coach.isManagingPrivateData, isFalse);
    expect(coach.enhancedCoachingEnabled, isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('enhancedCoachingEnabled'), isTrue);
  });

  test('keeps immediate safety concerns on the local responder', () async {
    final enhancedResponder = _RecordingResponder(
      'This remote response must not be used.',
    );
    final coach = await createCoach(enhancedResponder: enhancedResponder);
    addTearDown(coach.dispose);
    await coach.setEnhancedCoachingEnabled(true);

    expect(
      await coach.send(
        'I want to kill myself.',
        const CoachingContext(focusTask: 'Finish the report'),
      ),
      isTrue,
    );

    expect(enhancedResponder.calls, 0);
    expect(coach.messages.last.text, contains('Your safety matters'));
    expect(coach.messages.last.text, contains('emergency services'));
    expect(coach.messages.last.text, isNot(contains('Finish the report')));
  });

  test('keeps coaching boundary requests on the local responder', () async {
    final enhancedResponder = _RecordingResponder(
      'This remote response must not be used.',
    );
    final coach = await createCoach(enhancedResponder: enhancedResponder);
    addTearDown(coach.dispose);
    await coach.setEnhancedCoachingEnabled(true);

    expect(
      await coach.send(
        'Please stop coaching and give me space.',
        const CoachingContext(focusTask: 'Finish the report'),
      ),
      isTrue,
    );

    expect(enhancedResponder.calls, 0);
    expect(coach.messages.last.text, contains('I’ll stop here'));
    expect(coach.messages.last.text, contains('nothing to prove'));
    expect(coach.messages.last.text, isNot(contains('Finish the report')));
  });

  test(
    'conversation clearing preserves consent until all local data clears',
    () async {
      final coach = await createCoach(
        enhancedResponder: _RecordingResponder('Enhanced guidance.'),
      );
      addTearDown(coach.dispose);
      await coach.setEnhancedCoachingEnabled(true);
      await coach.send('Help me start.', const CoachingContext());

      await coach.clearConversation();

      expect(coach.messages, isEmpty);
      expect(coach.enhancedCoachingEnabled, isTrue);
      var preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('enhancedCoachingEnabled'), isTrue);

      await coach.clearLocalData();

      expect(coach.enhancedCoachingEnabled, isFalse);
      preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('enhancedCoachingEnabled'), isFalse);
    },
  );

  test('clearing the conversation forgets its support preference', () async {
    final coach = await createCoach();
    addTearDown(coach.dispose);
    const context = CoachingContext(focusTask: 'Prepare the demo');

    expect(
      await coach.send('Be direct and hold me accountable.', context),
      isTrue,
    );
    expect(await coach.send('Can you help me with this?', context), isTrue);
    expect(coach.messages.last.text, startsWith('You asked me to stay direct'));

    await coach.clearConversation();

    expect(coach.messages, isEmpty);
    expect(await coach.send('Can you help me with this?', context), isTrue);
    expect(
      coach.messages.last.text,
      contains('We can keep this gentle and practical'),
    );
    expect(
      coach.messages.last.text,
      isNot(contains('You asked me to stay direct')),
    );
  });

  test('serializes overlapping coaching requests', () async {
    final responder = _PendingResponder();
    final coach = await createCoach(responder: responder);
    addTearDown(coach.dispose);
    var notifications = 0;
    coach.addListener(() => notifications += 1);

    final firstSend = coach.send(
      '  Help   me start  ',
      const CoachingContext(focusTask: 'Plan the week'),
    );
    await responder.invoked.future;

    expect(coach.isResponding, isTrue);
    expect(coach.messages, hasLength(1));
    expect(coach.messages.single.text, 'Help me start');
    expect(
      await coach.send('Send this twice', const CoachingContext()),
      isFalse,
    );
    expect(responder.calls, 1);

    responder.response.complete('Start with one small step.');

    expect(await firstSend, isTrue);
    expect(coach.isResponding, isFalse);
    expect(coach.messages, hasLength(2));
    expect(coach.messages.last.role, CoachingMessageRole.coach);
    expect(coach.messages.last.text, 'Start with one small step.');
    expect(notifications, 2);
  });

  test('persists and clears a private local conversation', () async {
    final firstCoach = await createCoach(
      responder: _CallbackResponder((_) async => 'Try the first paragraph.'),
    );
    expect(
      await firstCoach.send(
        'I am stuck on the introduction.',
        const CoachingContext(),
      ),
      isTrue,
    );
    firstCoach.dispose();

    final restoredCoach = await createCoach();
    addTearDown(restoredCoach.dispose);

    expect(restoredCoach.messages, hasLength(2));
    expect(restoredCoach.messages.first.role, CoachingMessageRole.user);
    expect(restoredCoach.messages.last.role, CoachingMessageRole.coach);

    expect(await restoredCoach.clearLocalData(), isTrue);

    expect(restoredCoach.messages, isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('coachingConversation'), isFalse);
  });

  test('restores and retries one unanswered saved message', () async {
    final firstCoach = await createCoach(
      responder: _CallbackResponder(
        (_) => Future.error(StateError('coach unavailable')),
      ),
    );
    expect(
      await firstCoach.send(
        'Help me recover this response.',
        const CoachingContext(),
      ),
      isFalse,
    );
    expect(firstCoach.messages, hasLength(1));
    expect(firstCoach.canRetryResponse, isTrue);
    firstCoach.dispose();

    var retryCalls = 0;
    final restoredCoach = await createCoach(
      responder: _CallbackResponder((message) async {
        retryCalls += 1;
        expect(message, 'Help me recover this response.');
        return 'Use one calm next step.';
      }),
    );
    addTearDown(restoredCoach.dispose);

    expect(restoredCoach.messages, hasLength(1));
    expect(restoredCoach.canRetryResponse, isTrue);
    expect(
      await restoredCoach.send(
        'Do not replace the pending message.',
        const CoachingContext(),
      ),
      isFalse,
    );
    expect(retryCalls, 0);
    expect(restoredCoach.messages.map((entry) => entry.text), [
      'Help me recover this response.',
    ]);
    expect(
      await restoredCoach.retryLastResponse(const CoachingContext()),
      isTrue,
    );

    expect(retryCalls, 1);
    expect(restoredCoach.messages.map((entry) => entry.text), [
      'Help me recover this response.',
      'Use one calm next step.',
    ]);
    expect(restoredCoach.canRetryResponse, isFalse);
    expect(
      await restoredCoach.retryLastResponse(const CoachingContext()),
      isFalse,
    );
    expect(retryCalls, 1);
    final preferences = await SharedPreferences.getInstance();
    final savedConversation =
        jsonDecode(preferences.getString('coachingConversation')!)
            as List<dynamic>;
    expect(savedConversation, hasLength(2));
  });

  test('a rejected history deletion keeps private messages visible', () async {
    final firstCoach = await createCoach(
      responder: _RecordingResponder('Stored guidance.'),
    );
    expect(
      await firstCoach.send('Keep this private.', const CoachingContext()),
      isTrue,
    );
    firstCoach.dispose();

    final coach = await createCoach(removePreference: (_, _) async => false);
    addTearDown(coach.dispose);
    expect(coach.messages, hasLength(2));

    expect(await coach.clearConversation(), isFalse);

    expect(coach.messages, hasLength(2));
    expect(
      coach.errorMessage,
      'Your private coaching data could not be completely cleared. '
      'Please retry.',
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('coachingConversation'), isTrue);
  });

  test(
    'partial local-data deletion exposes only the uncleared consent',
    () async {
      final firstCoach = await createCoach(
        enhancedResponder: _RecordingResponder('Enhanced guidance.'),
      );
      await firstCoach.setEnhancedCoachingEnabled(true);
      expect(
        await firstCoach.send('Remove this later.', const CoachingContext()),
        isTrue,
      );
      firstCoach.dispose();

      final coach = await createCoach(
        enhancedResponder: _RecordingResponder('Enhanced guidance.'),
        removePreference: (preferences, key) async {
          if (key == 'enhancedCoachingEnabled') return false;
          await preferences.remove(key);
          return !preferences.containsKey(key);
        },
      );
      addTearDown(coach.dispose);

      expect(await coach.clearLocalData(), isFalse);

      expect(coach.messages, isEmpty);
      expect(coach.enhancedCoachingEnabled, isTrue);
      expect(
        coach.errorMessage,
        'Your private coaching data could not be completely cleared. '
        'Please retry.',
      );
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('coachingConversation'), isFalse);
      expect(preferences.getBool('enhancedCoachingEnabled'), isTrue);
    },
  );

  test('a thrown deletion still clears the remaining private value', () async {
    final firstCoach = await createCoach(
      enhancedResponder: _RecordingResponder('Enhanced guidance.'),
    );
    await firstCoach.setEnhancedCoachingEnabled(true);
    expect(
      await firstCoach.send(
        'Keep this until cleanup works.',
        const CoachingContext(),
      ),
      isTrue,
    );
    firstCoach.dispose();

    final coach = await createCoach(
      enhancedResponder: _RecordingResponder('Enhanced guidance.'),
      removePreference: (preferences, key) async {
        if (key == 'coachingConversation') {
          throw StateError('history storage unavailable');
        }
        await preferences.remove(key);
        return !preferences.containsKey(key);
      },
    );
    addTearDown(coach.dispose);

    expect(await coach.clearLocalData(), isFalse);

    expect(coach.messages, hasLength(2));
    expect(coach.enhancedCoachingEnabled, isFalse);
    expect(
      coach.errorMessage,
      'Your private coaching data could not be completely cleared. '
      'Please retry.',
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('coachingConversation'), isTrue);
    expect(preferences.containsKey('enhancedCoachingEnabled'), isFalse);
  });

  test('an in-flight deletion blocks other private actions', () async {
    final firstCoach = await createCoach(
      enhancedResponder: _RecordingResponder('Enhanced guidance.'),
    );
    await firstCoach.setEnhancedCoachingEnabled(true);
    expect(
      await firstCoach.send('Delete this once.', const CoachingContext()),
      isTrue,
    );
    firstCoach.dispose();

    final removalStarted = Completer<void>();
    final allowRemoval = Completer<void>();
    var removalCalls = 0;
    final localResponder = _RecordingResponder('Local guidance.');
    final coach = await createCoach(
      responder: localResponder,
      enhancedResponder: _RecordingResponder('Enhanced guidance.'),
      removePreference: (preferences, key) async {
        removalCalls += 1;
        if (removalCalls == 1) {
          removalStarted.complete();
          await allowRemoval.future;
        }
        await preferences.remove(key);
        return !preferences.containsKey(key);
      },
    );
    addTearDown(coach.dispose);

    final clearing = coach.clearLocalData();
    await removalStarted.future;

    expect(coach.isManagingPrivateData, isTrue);
    expect(
      await coach.send('Do not save this.', const CoachingContext()),
      isFalse,
    );
    expect(await coach.setEnhancedCoachingEnabled(false), isFalse);
    expect(await coach.clearLocalData(), isFalse);
    expect(removalCalls, 1);
    expect(localResponder.calls, 0);

    allowRemoval.complete();
    expect(await clearing, isTrue);
    expect(coach.isManagingPrivateData, isFalse);
    expect(removalCalls, 2);
    expect(coach.messages, isEmpty);
    expect(coach.enhancedCoachingEnabled, isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('coachingConversation'), isFalse);
    expect(preferences.containsKey('enhancedCoachingEnabled'), isFalse);
  });

  test('a rejected user-message commit never invokes either coach', () async {
    final localResponder = _RecordingResponder('Local guidance.');
    final enhancedResponder = _RecordingResponder('Enhanced guidance.');
    final coach = await createCoach(
      responder: localResponder,
      enhancedResponder: enhancedResponder,
      saveConversation: (_, _) async => false,
    );
    addTearDown(coach.dispose);
    await coach.setEnhancedCoachingEnabled(true);

    expect(
      await coach.send('Do not lose this.', const CoachingContext()),
      isFalse,
    );

    expect(localResponder.calls, 0);
    expect(enhancedResponder.calls, 0);
    expect(coach.messages, isEmpty);
    expect(
      coach.errorMessage,
      'Your coach could not respond right now. Please retry.',
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('coachingConversation'), isFalse);
  });

  test('a rejected coach-message commit never surfaces the reply', () async {
    var saveCalls = 0;
    final responder = _RecordingResponder('Unsaved guidance.');
    final coach = await createCoach(
      responder: responder,
      saveConversation: (preferences, messages) async {
        saveCalls += 1;
        if (saveCalls > 1) return false;
        return preferences.setString(
          'coachingConversation',
          jsonEncode(messages.map((message) => message.toJson()).toList()),
        );
      },
    );
    addTearDown(coach.dispose);

    expect(
      await coach.send('Keep only this.', const CoachingContext()),
      isFalse,
    );

    expect(saveCalls, 2);
    expect(responder.calls, 1);
    expect(coach.messages, hasLength(1));
    expect(coach.messages.single.role, CoachingMessageRole.user);
    expect(coach.messages.single.text, 'Keep only this.');
    expect(
      coach.messages.map((message) => message.text),
      isNot(contains('Unsaved guidance.')),
    );
    final preferences = await SharedPreferences.getInstance();
    final saved =
        jsonDecode(preferences.getString('coachingConversation')!)
            as List<dynamic>;
    expect(saved, hasLength(1));
    expect((saved.single as Map<String, dynamic>)['text'], 'Keep only this.');
  });

  test('a rejected malformed-history cleanup remains visible', () async {
    SharedPreferences.setMockInitialValues({
      'coachingConversation': '{not valid json',
    });

    final coach = await createCoach(removePreference: (_, _) async => false);
    addTearDown(coach.dispose);

    expect(coach.messages, isEmpty);
    expect(
      coach.errorMessage,
      'Your private coaching data could not be completely repaired. '
      'Please clear it and retry.',
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('coachingConversation'), '{not valid json');
  });

  test('a rejected consent cleanup remains disabled and visible', () async {
    SharedPreferences.setMockInitialValues({
      'enhancedCoachingEnabled': 'not a consent value',
    });

    final coach = await createCoach(
      enhancedResponder: _RecordingResponder('Enhanced guidance.'),
      removePreference: (_, _) async => false,
    );
    addTearDown(coach.dispose);

    expect(coach.enhancedCoachingEnabled, isFalse);
    expect(
      coach.errorMessage,
      'Your private coaching data could not be completely repaired. '
      'Please clear it and retry.',
    );
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('enhancedCoachingEnabled'),
      'not a consent value',
    );
  });

  test('a rejected normalized-history repair stays visible', () async {
    final validMessage = CoachingMessage(
      id: 'valid-1',
      role: CoachingMessageRole.user,
      text: 'Keep this message.',
      createdAt: DateTime.utc(2026, 8, 10),
    ).toJson();
    SharedPreferences.setMockInitialValues({
      'coachingConversation': jsonEncode([validMessage, validMessage]),
    });

    final coach = await createCoach(saveConversation: (_, _) async => false);
    addTearDown(coach.dispose);

    expect(coach.messages, hasLength(1));
    expect(coach.messages.single.id, 'valid-1');
    expect(
      coach.errorMessage,
      'Your private coaching data could not be completely repaired. '
      'Please clear it and retry.',
    );
    final preferences = await SharedPreferences.getInstance();
    final unrepaired =
        jsonDecode(preferences.getString('coachingConversation')!)
            as List<dynamic>;
    expect(unrepaired, hasLength(2));
  });

  test('repairs damaged saved messages without losing valid history', () async {
    final validMessage = CoachingMessage(
      id: 'valid-1',
      role: CoachingMessageRole.user,
      text: '  Keep this message.  ',
      createdAt: DateTime.utc(2026, 8, 10),
    ).toJson();
    SharedPreferences.setMockInitialValues({
      'coachingConversation': jsonEncode([
        validMessage,
        validMessage,
        {'id': 'bad-role', 'role': 'system', 'text': 'No', 'createdAt': 'now'},
        'wrong shape',
      ]),
    });

    final coach = await createCoach();
    addTearDown(coach.dispose);

    expect(coach.messages, hasLength(1));
    expect(coach.messages.single.id, 'valid-1');
    expect(coach.messages.single.text, 'Keep this message.');

    final preferences = await SharedPreferences.getInstance();
    final repaired =
        jsonDecode(preferences.getString('coachingConversation')!)
            as List<dynamic>;
    expect(repaired, hasLength(1));
  });

  test('keeps only the newest forty saved messages', () async {
    final savedMessages = List.generate(
      45,
      (index) => CoachingMessage(
        id: '$index',
        role: index.isEven
            ? CoachingMessageRole.user
            : CoachingMessageRole.coach,
        text: 'Message $index',
        createdAt: DateTime.utc(2026, 8, 10).add(Duration(minutes: index)),
      ).toJson(),
    );
    SharedPreferences.setMockInitialValues({
      'coachingConversation': jsonEncode(savedMessages),
    });

    final coach = await createCoach();
    addTearDown(coach.dispose);

    expect(coach.messages, hasLength(40));
    expect(coach.messages.first.id, '5');
    expect(coach.messages.last.id, '44');
  });

  test('disposal after the user save never invokes either coach', () async {
    final saveStarted = Completer<void>();
    final allowSave = Completer<void>();
    var saveCalls = 0;
    final localResponder = _RecordingResponder('Local guidance.');
    final enhancedResponder = _RecordingResponder('Enhanced guidance.');
    final coach = await createCoach(
      responder: localResponder,
      enhancedResponder: enhancedResponder,
      saveConversation: (_, _) async {
        saveCalls += 1;
        if (saveCalls == 1) {
          saveStarted.complete();
          await allowSave.future;
        }
        return true;
      },
    );
    expect(await coach.setEnhancedCoachingEnabled(true), isTrue);

    final sending = coach.send(
      'Keep this private after shutdown.',
      const CoachingContext(),
    );
    await saveStarted.future;
    coach.dispose();
    allowSave.complete();

    expect(await sending, isFalse);
    expect(saveCalls, 1);
    expect(localResponder.calls, 0);
    expect(enhancedResponder.calls, 0);
  });

  test('a reply arriving after disposal is never persisted', () async {
    final responder = _PendingResponder();
    final coach = await createCoach(responder: responder);

    final sending = coach.send(
      'Save my message, but not a late reply.',
      const CoachingContext(),
    );
    await responder.invoked.future;
    coach.dispose();
    responder.response.complete('This reply arrived too late.');

    expect(await sending, isFalse);
    expect(responder.calls, 1);
    final preferences = await SharedPreferences.getInstance();
    final savedConversation =
        jsonDecode(preferences.getString('coachingConversation')!)
            as List<dynamic>;
    expect(savedConversation, hasLength(1));
    final savedMessage = Map<String, dynamic>.from(
      savedConversation.single as Map,
    );
    expect(savedMessage['id'], isA<String>());
    expect(savedMessage['role'], 'user');
    expect(savedMessage['text'], 'Save my message, but not a late reply.');
    expect(savedMessage['createdAt'], isA<String>());
  });

  test('initialization and sends are safe after disposal', () async {
    final coach = CoachingService();

    coach.dispose();

    await expectLater(coach.initialized, completes);
    expect(
      await coach.send('Do not send this.', const CoachingContext()),
      isFalse,
    );
  });
}

class _CallbackResponder implements CoachingResponder {
  const _CallbackResponder(this.callback);

  final Future<String> Function(String message) callback;

  @override
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  }) => callback(message);
}

class _RecordingResponder implements CoachingResponder {
  _RecordingResponder(this.response);

  final String response;
  int calls = 0;

  @override
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  }) async {
    calls += 1;
    return response;
  }
}

class _PendingResponder implements CoachingResponder {
  final invoked = Completer<void>();
  final response = Completer<String>();
  int calls = 0;

  @override
  Future<String> respond({
    required String message,
    required CoachingContext context,
    required List<CoachingMessage> conversation,
  }) async {
    calls += 1;
    if (!invoked.isCompleted) invoked.complete();
    return response.future;
  }
}
