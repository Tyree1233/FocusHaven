import 'package:flutter/material.dart';

import '../services/soundscape_controller.dart';

/// English preview copy only; not a replacement for approved runtime catalogs.
class SoundscapeCard extends StatelessWidget {
  const SoundscapeCard({super.key, required this.controller});
  final SoundscapeController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final active =
          controller.status == SoundscapeStatus.playing ||
          controller.status == SoundscapeStatus.loading;
      final status = !controller.available
          ? 'Sound is unavailable on this platform. The timer still works.'
          : controller.voiceActive
          ? 'Sound paused for voice input. Tap Play when you are finished.'
          : switch (controller.status) {
              SoundscapeStatus.off => 'Off',
              SoundscapeStatus.loading => 'Loading sound…',
              SoundscapeStatus.playing => 'Playing',
              SoundscapeStatus.paused => 'Paused',
              SoundscapeStatus.failed =>
                'Sound could not play. Reopen the app to try again. The timer is unchanged.',
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
                'Soft noise',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text('Offline sound · Preview'),
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
                label: Text(active ? 'Pause sound' : 'Play sound'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
              const SizedBox(height: 8),
              Text('Sound volume: ${(controller.volume * 100).round()}%'),
              Semantics(
                label: 'Sound volume',
                child: Slider(
                  value: controller.volume,
                  divisions: 20,
                  semanticFormatterCallback: (value) =>
                      '${(value * 100).round()} percent',
                  onChanged: controller.available ? controller.setVolume : null,
                ),
              ),
              const Text(
                'Keeps playing when your phone locks or you switch apps. '
                'Sound never starts or changes your timer.',
              ),
            ],
          ),
        ),
      );
    },
  );
}
