import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/soundscape_controller.dart';

/// Opt-in sound controls using the currently resolved application locale.
class SoundscapeCard extends StatelessWidget {
  const SoundscapeCard({super.key, required this.controller});
  final SoundscapeController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l10n = AppLocalizations.of(context);
      final active =
          controller.status == SoundscapeStatus.playing ||
          controller.status == SoundscapeStatus.loading;
      final status = !controller.available
          ? l10n.soundscapeUnavailable
          : controller.voiceActive
          ? l10n.soundscapePausedForVoice
          : switch (controller.status) {
              SoundscapeStatus.off => l10n.soundscapeOff,
              SoundscapeStatus.loading => l10n.soundscapeLoading,
              SoundscapeStatus.playing => l10n.soundscapePlaying,
              SoundscapeStatus.paused => l10n.soundscapePaused,
              SoundscapeStatus.failed => l10n.soundscapePlaybackFailed,
            };
      return Card(
        key: const ValueKey('soundscape-card'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.soundscapeSoftNoiseTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(l10n.soundscapePreviewLabel),
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(status)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: !controller.canPlay
                    ? null
                    : () async {
                        if (active) {
                          await controller.pause();
                        } else {
                          await controller.play();
                        }
                      },
                icon: Icon(active ? Icons.pause : Icons.play_arrow),
                label: Text(
                  active ? l10n.soundscapePause : l10n.soundscapePlay,
                ),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.soundscapeVolumeValue((controller.volume * 100).round()),
              ),
              Semantics(
                label: l10n.soundscapeVolumeLabel,
                child: Slider(
                  value: controller.volume,
                  divisions: 20,
                  semanticFormatterCallback: (value) =>
                      l10n.soundscapeVolumePercent((value * 100).round()),
                  onChanged: controller.available ? controller.setVolume : null,
                ),
              ),
              Text(l10n.soundscapeBackgroundNotice),
            ],
          ),
        ),
      );
    },
  );
}
