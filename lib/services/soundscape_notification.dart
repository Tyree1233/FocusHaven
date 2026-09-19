import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/app_localizations.dart';

const soundscapeNotificationChannelId = 'com.focushaven.app.soundscapes';

/// Rename only this channel; retain its existing behavior and user settings.
/// Initial defaults match audio_service's low-importance, no-badge channel.
AndroidNotificationChannel soundscapeNotificationChannel(
  AppLocalizations localizations, {
  AndroidNotificationChannel? existing,
}) {
  if (existing != null && existing.id != soundscapeNotificationChannelId) {
    throw ArgumentError('Only the soundscape channel may be renamed');
  }
  return AndroidNotificationChannel(
    soundscapeNotificationChannelId,
    localizations.soundscapeNotificationChannelName,
    description: existing?.description,
    groupId: existing?.groupId,
    importance: existing?.importance ?? Importance.low,
    bypassDnd: existing?.bypassDnd ?? false,
    playSound: existing?.playSound ?? true,
    sound: existing?.sound,
    enableVibration: existing?.enableVibration ?? false,
    vibrationPattern: existing?.vibrationPattern,
    showBadge: existing?.showBadge ?? false,
    enableLights: existing?.enableLights ?? false,
    ledColor: existing?.ledColor,
    audioAttributesUsage:
        existing?.audioAttributesUsage ?? AudioAttributesUsage.notification,
  );
}
