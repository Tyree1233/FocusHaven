import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focushaven/l10n/app_localizations.dart';
import 'package:focushaven/services/soundscape_controller.dart';
import 'package:focushaven/services/soundscape_media.dart';
import 'package:focushaven/services/soundscape_notification.dart';
import 'package:focushaven/widgets/soundscape_card.dart';
import 'package:focushaven/widgets/soundscape_localization_host.dart';

import 'support/fake_soundscape_output.dart';
import 'support/localization_catalog_prefix.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all catalog additions preserve the exact pre-delta bytes', () async {
    final record =
        jsonDecode(
              File(
                'localization/reviews/soundscapes-ai-acceptance.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(record['humanReviewed'], isFalse);
    expect(record['humanReviewWaivedByOwner'], isTrue);
    expect(record['reviewBasis'], 'ai_editorial_with_owner_waiver');
    final source =
        jsonDecode(
              File(
                'localization/proposals/app_en_soundscapes_review.arb',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final keys = source.keys.where((k) => !k.startsWith('@')).toSet();
    expect(keys.length, 16);
    final catalogs = record['catalogs'] as List<dynamic>;
    expect(catalogs.length, 17);
    for (final item in catalogs) {
      final path = item['path'] as String;
      expect(
        await _sha256(catalogBytesBeforeSoundscapes(path)),
        item['baseSha256'],
        reason: path,
      );
      final catalog =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      expect(
        catalog.keys.where((k) => k.startsWith('soundscape')).toSet(),
        keys,
      );
      for (final key in keys) {
        expect(catalog[key], isA<String>());
        expect(catalog['@$key'], source['@$key'], reason: '$path:$key');
        expect(
          RegExp(
            r'\{[^{}]+\}',
          ).allMatches(catalog[key] as String).map((m) => m[0]).toList(),
          RegExp(
            r'\{[^{}]+\}',
          ).allMatches(source[key] as String).map((m) => m[0]).toList(),
        );
      }
      final delta = <String, dynamic>{
        '@@locale': (item['derivedFrom'] ?? catalog['@@locale'])
            .toString()
            .replaceAll('-', '_'),
        for (final entry in catalog.entries)
          if (keys.contains(entry.key) ||
              (entry.key.startsWith('@') &&
                  keys.contains(entry.key.substring(1))))
            entry.key: entry.value,
      };
      expect(
        await _sha256(
          utf8.encode('${const JsonEncoder.withIndent('  ').convert(delta)}\n'),
        ),
        item['deltaSha256'],
        reason: 'Accepted delta: $path',
      );
    }
    final pt = lookupAppLocalizations(const Locale('pt'));
    final br = lookupAppLocalizations(const Locale('pt', 'BR'));
    expect(pt.soundscapeBackgroundNotice, br.soundscapeBackgroundNotice);
    expect(pt.soundscapePlay, br.soundscapePlay);
    expect(lookupAppLocalizations(const Locale('ko')).soundscapeOff, '꺼짐');
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      '${locale.toLanguageTag()} narrow 2x card and localized semantics',
      (tester) async {
        final output = FakeSoundscapeOutput();
        final controller = SoundscapeController(output);
        addTearDown(controller.dispose);
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_app(controller, locale, largeText: true));
          await tester.pumpAndSettle();
          final l10n = lookupAppLocalizations(locale);
          expect(find.text(l10n.soundscapeSoftNoiseTitle), findsOneWidget);
          expect(find.text(l10n.soundscapeBackgroundNotice), findsOneWidget);
          await tester.ensureVisible(find.text(l10n.soundscapePlay));
          expect(find.bySemanticsLabel(l10n.soundscapePlay), findsOneWidget);
          expect(
            tester
                .getSize(
                  find.byWidgetPredicate((widget) => widget is FilledButton),
                )
                .height,
            greaterThanOrEqualTo(48),
          );
          final slider = tester.widget<Slider>(find.byType(Slider));
          expect(
            slider.semanticFormatterCallback!(0.25),
            l10n.soundscapeVolumePercent(25),
          );
          expect(find.text(l10n.soundscapeVolumeValue(25)), findsOneWidget);
          expect(output.prepares, 0);
          expect(output.starts, 0);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'language changes update metadata without playback or volume operations',
    (tester) async {
      final output = FakeSoundscapeOutput();
      final seen = <String>[];
      final controller = SoundscapeController(
        output,
        onLocalizationsChanged: (l10n) =>
            seen.add(softNoiseMediaItem(localizations: l10n).title),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller, const Locale('en')));
      await tester.pumpAndSettle();
      expect(output.starts, 0);
      await controller.play();
      await tester.pumpAndSettle();
      for (final locale in [
        const Locale('es'),
        const Locale('ja'),
        const Locale('ko'),
      ]) {
        await tester.pumpWidget(_app(controller, locale));
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(locale);
        expect(seen.last, l10n.soundscapeSoftNoiseTitle);
        expect(find.text(l10n.soundscapePlaying), findsOneWidget);
        expect(output.starts, 1);
        expect(output.prepares, 1);
        expect(output.pauses, 0);
        expect(output.stops, 0);
        expect(controller.volume, 0.25);
      }
      await controller.pauseForVoice();
      await tester.pumpWidget(_app(controller, const Locale('de')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          lookupAppLocalizations(const Locale('de')).soundscapePausedForVoice,
        ),
        findsOneWidget,
      );
      controller.releaseVoice();
      await tester.pumpAndSettle();
      expect(output.starts, 1);
      expect(output.pauses, 1);
      expect(controller.status, SoundscapeStatus.paused);
      expect(controller.volume, 0.25);
    },
  );

  test('localized media retains stable identity and local artwork', () {
    final artwork = Uri.file('/app/lantern.png');
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final item = softNoiseMediaItem(artwork: artwork, localizations: l10n);
      expect(item.title, l10n.soundscapeSoftNoiseTitle);
      expect(item.id, 'focushaven.soft-noise.v1');
      expect(item.artist, 'FocusHaven');
      expect(item.album, 'FocusHaven');
      expect(item.artUri, artwork);
    }
  });

  test(
    'channel rename preserves existing behavior and rejects other channels',
    () {
      const existing = AndroidNotificationChannel(
        soundscapeNotificationChannelId,
        'Old',
        importance: Importance.min,
        playSound: false,
        enableVibration: false,
        showBadge: true,
        bypassDnd: true,
        description: 'Existing description',
        groupId: 'group',
      );
      final l10n = lookupAppLocalizations(const Locale('fr'));
      final updated = soundscapeNotificationChannel(l10n, existing: existing);
      expect(updated.name, l10n.soundscapeNotificationChannelName);
      expect(updated.id, existing.id);
      expect(updated.importance, existing.importance);
      expect(updated.playSound, existing.playSound);
      expect(updated.enableVibration, existing.enableVibration);
      expect(updated.showBadge, existing.showBadge);
      expect(updated.bypassDnd, existing.bypassDnd);
      expect(updated.description, existing.description);
      expect(updated.groupId, existing.groupId);
      expect(
        () => soundscapeNotificationChannel(
          l10n,
          existing: const AndroidNotificationChannel('timer', 'Timer'),
        ),
        throwsArgumentError,
      );
    },
  );
}

Widget _app(
  SoundscapeController controller,
  Locale locale, {
  bool largeText = false,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) =>
      SoundscapeLocalizationHost(controller: controller, child: child!),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(largeText ? 2 : 1)),
    child: Scaffold(
      body: SingleChildScrollView(
        child: SoundscapeCard(controller: controller),
      ),
    ),
  ),
);

Future<String> _sha256(List<int> bytes) async {
  // Same host utility used by the existing localization acceptance tools.
  final process = await Process.start('shasum', ['-a', '256']);
  process.stdin.add(bytes);
  await process.stdin.close();
  final streams = await Future.wait([
    process.stdout.transform(utf8.decoder).join(),
    process.stderr.transform(utf8.decoder).join(),
  ]);
  expect(await process.exitCode, 0, reason: streams[1]);
  return streams[0].trim().split(RegExp(r'\s+')).first;
}
